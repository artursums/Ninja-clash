extends Node
## HTTPS room admission and per-guest signaling; gameplay travels through WebRTC.

const PROTOCOL := 3
const CONNECT_TIMEOUT := 45.0
const POLL_INTERVAL := 0.75

signal prepared(peer: WebRTCMultiplayerPeer)
signal room_created(code: String)
signal status_changed(message: String)
signal failed(message: String)
signal lock_completed(error: String, generation: int)

var room_code := ""
var local_peer := 1
var links: Dictionary = {}
var _peer: WebRTCMultiplayerPeer
var _http: HTTPRequest
var _configuration: Dictionary = {}
var _endpoint := ""
var _token := ""
var _host := false
var _active := false
var _locked := false
var _action := ""
var _request_body: Dictionary = {}
var _commands: Array = []
var _next_poll := 0.0
var _retry_after := 0.0
var _deadline := 0.0
var _last_response := 0.0
var _signaling_done := false


static func parse_room(value: String) -> String:
	var code := value.strip_edges()
	# Invitations keep the capability out of HTTP access logs and referrer headers.
	if "#room=" in code:
		code = code.get_slice("#room=", 1).get_slice("&", 0)
	elif "?room=" in code:
		code = code.get_slice("?room=", 1).get_slice("&", 0)
	code = code.to_upper()
	if code.length() != 12:
		return ""
	for character in code:
		if not character in "0123456789ABCDEF":
			return ""
	return code


func start(as_host: bool, code: String) -> void:
	_host = as_host
	room_code = code
	_token = Crypto.new().generate_random_bytes(32).hex_encode()
	_endpoint = String(JavaScriptBridge.eval("window.location.origin", true)) + "/api/rooms"
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.body_size_limit = 131072
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_active = true
	_last_response = _now()
	_deadline = _now() + CONNECT_TIMEOUT
	_request({"action": "create" if as_host else "join"})


func mark_connected(id: int) -> void:
	var key := id if _host else local_peer
	if links.has(key):
		links[key].connected = true


func lock_room(peers: Array, generation: int) -> void:
	_commands.append({"action": "lock", "peers": peers, "generation": generation, "deadline": _now() + 20.0})


func reopen() -> void:
	_locked = false
	_signaling_done = false
	_commands.append({"action": "reopen"})


func remove_guest(id: int) -> void:
	if not _host:
		return
	_drop_link(id)
	_commands.append({"action": "remove", "peer": id})


func _drop_link(id: int) -> void:
	if not links.has(id):
		return
	var connection: WebRTCPeerConnection = links[id].connection
	links.erase(id)
	var remote := id if _host else 1
	if _peer != null and _peer.has_peer(remote):
		_peer.remove_peer(remote)
	connection.close()


func stop() -> void:
	_active = false
	if _http != null:
		_http.cancel_request()
	if room_code != "" and _token != "" and _peer != null:
		var request := HTTPRequest.new()
		request.timeout = 3.0
		get_tree().root.add_child(request)
		request.request_completed.connect(func(_a, _b, _c, _d): request.queue_free())
		var err := request.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify({"action": "leave", "room": room_code, "token": _token}))
		if err != OK:
			request.queue_free()
	for id in links.keys():
		_drop_link(id)


func _process(_delta: float) -> void:
	if not _active:
		return
	for id in links.keys():
		var link: Dictionary = links[id]
		var connection: WebRTCPeerConnection = link.connection
		if connection.get_connection_state() == WebRTCPeerConnection.STATE_FAILED or (not link.connected and _now() > link.deadline):
			if _host:
				remove_guest(id)
				status_changed.emit("A PLAYER COULD NOT CONNECT — THE SEAT IS OPEN")
			else:
				_fail("CONNECTION TIMED OUT — TRY AGAIN")
				return
	if _peer == null and _now() > _deadline:
		_fail("ROOM SERVICE NOT RESPONDING")
		return
	_signaling_done = not links.is_empty()
	for link in links.values():
		_signaling_done = _signaling_done and _settled(link)
	if _host:
		_signaling_done = _signaling_done and _locked
	if _action != "" or _now() < _retry_after:
		return
	if not _commands.is_empty():
		_request(_commands.pop_front())
	elif _peer != null and _now() >= _next_poll and (_host or not _signaling_done):
		var batches: Array = []
		for id in links:
			var link: Dictionary = links[id]
			batches.append({"peer": id, "cursor": link.cursor, "messages": link.outgoing.slice(0, 8), "ready": link.connected})
		_request({"action": "exchange", "links": batches})


func _settled(link: Dictionary) -> bool:
	return link.connected and link.peer_ready and link.ready_acked and link.outgoing.is_empty() and link.connection.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE


func _request(body: Dictionary) -> void:
	_action = body.action
	_request_body = body.duplicate(true)
	body.merge({"token": _token, "room": room_code, "protocol": PROTOCOL})
	var err := _http.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_action = ""
		_fail("COULD NOT CONTACT ROOM SERVICE")


func _on_response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if not _active:
		return
	var action := _action
	_action = ""
	_next_poll = _now() + (10.0 if _host and _signaling_done else POLL_INTERVAL)
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 429:
		if action == "lock" and _now() > float(_request_body.deadline):
			_commands.push_front({"action": "reopen"})
			lock_completed.emit("ROOM SERVICE UNAVAILABLE — TRY START AGAIN", int(_request_body.generation))
			return
		if action in ["exchange", "lock", "reopen", "remove"]:
			if action != "exchange":
				_commands.push_front(_request_body)
			_next_poll = _now() + 2.0
			_retry_after = _next_poll
			status_changed.emit("ROOM SERVICE UNAVAILABLE — RETRYING…")
			return
		_fail("ONLINE SERVICE UNAVAILABLE — TRY AGAIN LATER")
		return
	var decoded = JSON.parse_string(bytes.get_string_from_utf8())
	if not decoded is Dictionary:
		_fail("INVALID ROOM SERVICE RESPONSE")
		return
	var data: Dictionary = decoded
	if code != 200:
		var error := String(data.get("error", "COULD NOT CONNECT"))
		if action == "lock":
			lock_completed.emit(error, int(_request_body.generation))
		else:
			_fail(error)
		return
	_last_response = _now()
	if action == "lock":
		_locked = true
		lock_completed.emit("", int(_request_body.generation))
		return
	if action == "reopen" or action == "remove":
		return
	if action == "create" or action == "join":
		room_code = parse_room(String(data.get("room", "")))
		if room_code == "" or not data.get("rtc") is Dictionary:
			_fail("INVALID ROOM SERVICE RESPONSE")
			return
		_configuration = data.rtc
		local_peer = int(data.get("peer", 0))
		_peer = WebRTCMultiplayerPeer.new()
		var err := _peer.create_server() if _host else _peer.create_client(local_peer)
		if err != OK:
			_fail("COULD NOT START MULTIPLAYER")
			return
		prepared.emit(_peer)
		if _host:
			room_created.emit(room_code)
		else:
			_add_link(local_peer)
			status_changed.emit("CONNECTING TO HOST…")
		return
	var present: Array = data.get("peers", []).map(func(value): return int(value))
	if _host:
		for id in links.keys():
			if not present.has(id):
				_drop_link(id)
		for value in present:
			var id := int(value)
			if not links.has(id):
				_add_link(id)
	for batch in data.get("links", []):
		var id := int(batch.peer)
		if not links.has(id):
			continue
		var link: Dictionary = links[id]
		var ack := int(batch.get("ack", 0))
		link.outgoing = link.outgoing.filter(func(message): return int(message.seq) > ack)
		link.peer_ready = bool(batch.get("peerReady", false))
		for sent in _request_body.get("links", []):
			if int(sent.peer) == id and bool(sent.ready):
				link.ready_acked = true
		for message in batch.get("messages", []):
			if int(message.seq) <= link.cursor:
				continue
			if not _receive(id, message):
				return
			link.cursor = int(message.seq)


func _add_link(id: int) -> void:
	var connection := WebRTCPeerConnection.new()
	if connection.initialize(_configuration) != OK:
		_fail("THIS BROWSER COULD NOT START WEBRTC")
		return
	links[id] = {"connection": connection, "connected": false, "peer_ready": false, "ready_acked": false,
		"remote_description": false, "pending_ice": [], "outgoing": [], "sequence": 0, "cursor": 0,
		"deadline": _now() + CONNECT_TIMEOUT}
	connection.session_description_created.connect(_on_description.bind(id))
	connection.ice_candidate_created.connect(_on_ice.bind(id))
	if _peer.add_peer(connection, id if _host else 1, 100) != OK:
		_fail("COULD NOT START MULTIPLAYER")
		return
	if _host and connection.create_offer() != OK:
		remove_guest(id)


func _on_description(type: String, sdp: String, id: int) -> void:
	if not _active or not links.has(id):
		return
	if links[id].connection.set_local_description(type, sdp) != OK:
		_fail("COULD NOT NEGOTIATE CONNECTION")
		return
	_enqueue(id, {"type": type, "sdp": sdp})


func _on_ice(media: String, index: int, candidate: String, id: int) -> void:
	if _active and links.has(id):
		_enqueue(id, {"type": "ice", "media": media, "index": index, "candidate": candidate})


func _enqueue(id: int, message: Dictionary) -> void:
	var link: Dictionary = links[id]
	link.sequence += 1
	message.seq = link.sequence
	link.outgoing.append(message)
	_next_poll = 0.0


func _receive(id: int, message: Dictionary) -> bool:
	var link: Dictionary = links[id]
	var type := String(message.get("type", ""))
	if type == "offer" or type == "answer":
		if link.remote_description or type != ("answer" if _host else "offer"):
			_fail("INVALID CONNECTION HANDSHAKE")
			return false
		if link.connection.set_remote_description(type, String(message.sdp)) != OK:
			_fail("COULD NOT NEGOTIATE CONNECTION")
			return false
		link.remote_description = true
		for candidate in link.pending_ice:
			if not _add_ice(link, candidate):
				return false
		link.pending_ice.clear()
	elif type == "ice":
		if not link.remote_description:
			link.pending_ice.append(message)
		else:
			return _add_ice(link, message)
	return true


func _add_ice(link: Dictionary, message: Dictionary) -> bool:
	if link.connection.add_ice_candidate(String(message.media), int(message.index), String(message.candidate)) != OK:
		_fail("COULD NOT NEGOTIATE NETWORK ROUTE")
		return false
	return true


func _fail(message: String) -> void:
	_active = false
	failed.emit(message)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
