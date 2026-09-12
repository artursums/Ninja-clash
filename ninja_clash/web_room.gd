extends Node
## HTTPS signaling only; WebRTCMultiplayerPeer carries the actual match traffic.

const PROTOCOL := 2
const CONNECT_TIMEOUT := 45.0
const POLL_INTERVAL := 0.5

signal prepared(peer: WebRTCMultiplayerPeer)
signal room_created(code: String)
signal status_changed(message: String)
signal failed(message: String)

var room_code := ""
var connection: WebRTCPeerConnection
var _peer: WebRTCMultiplayerPeer
var _http: HTTPRequest
var _endpoint := ""
var _token := ""
var _host := false
var _active := false
var _connected := false
var _peer_ready := false
var _joined := false
var _remote_description := false
var _pending_ice: Array = []
var _outgoing: Array = []
var _sequence := 0
var _cursor := 0
var _action := ""
var _next_poll := 0.0
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
	_request("create" if as_host else "join")


func mark_connected() -> void:
	_connected = true


func stop() -> void:
	_active = false
	if _http != null:
		_http.cancel_request()
	if room_code != "" and _token != "":
		var request := HTTPRequest.new()
		request.timeout = 3.0
		get_tree().root.add_child(request)
		request.request_completed.connect(func(_a, _b, _c, _d): request.queue_free())
		var err := request.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify({"action": "leave", "room": room_code, "token": _token}))
		if err != OK:
			request.queue_free()
	if connection != null:
		connection.close()


func _process(_delta: float) -> void:
	if not _active:
		return
	if connection != null and connection.get_connection_state() == WebRTCPeerConnection.STATE_FAILED:
		_fail("COULD NOT CONNECT — CREATE A NEW ROOM")
		return
	if not _connected and _now() > _deadline:
		_fail("ROOM EXPIRED" if _host and not _joined else "CONNECTION TIMED OUT — TRY A NEW ROOM")
		return
	if _signaling_done:
		return
	if _now() - _last_response > 25.0:
		_fail("ROOM SERVICE NOT RESPONDING")
		return
	if _action == "" and connection != null and _now() >= _next_poll:
		if _connected and _peer_ready and _outgoing.is_empty() and connection.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE:
			_signaling_done = true
			return
		_request("exchange")


func _request(action: String) -> void:
	_action = action
	var body := {"action": action, "token": _token, "room": room_code, "protocol": PROTOCOL}
	if action == "exchange":
		body.merge({"cursor": _cursor, "messages": _outgoing.slice(0, 16), "ready": _connected})
	var err := _http.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_fail("COULD NOT CONTACT ROOM SERVICE")


func _on_response(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if not _active:
		return
	var action := _action
	_action = ""
	_next_poll = _now() + POLL_INTERVAL
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500:
		if action == "exchange":
			_next_poll = _now() + 1.5
			return
		_fail("ONLINE SERVICE UNAVAILABLE — TRY AGAIN LATER")
		return
	var decoded = JSON.parse_string(bytes.get_string_from_utf8())
	if not decoded is Dictionary:
		_fail("INVALID ROOM SERVICE RESPONSE")
		return
	var data: Dictionary = decoded
	if code != 200:
		_fail(String(data.get("error", "COULD NOT CONNECT")))
		return
	_last_response = _now()
	if action == "create" or action == "join":
		room_code = parse_room(String(data.get("room", "")))
		if room_code == "" or not data.get("rtc") is Dictionary:
			_fail("INVALID ROOM SERVICE RESPONSE")
			return
		if not _prepare(data.rtc):
			return
		if _host:
			_deadline = _now() + float(data.get("expiresIn", 600))
			room_created.emit(room_code)
		else:
			status_changed.emit("CONNECTING TO HOST…")
		return
	var ack := int(data.get("ack", 0))
	_outgoing = _outgoing.filter(func(message): return int(message.seq) > ack)
	_peer_ready = bool(data.get("peerReady", false))
	if _host and not _joined and bool(data.get("joined", false)):
		_joined = true
		_deadline = _now() + CONNECT_TIMEOUT
		status_changed.emit("OPPONENT FOUND — CONNECTING…")
		if connection.create_offer() != OK:
			_fail("COULD NOT START CONNECTION")
			return
	for message in data.get("messages", []):
		if int(message.seq) <= _cursor:
			continue
		if not _receive(message):
			return
		_cursor = int(message.seq)


func _prepare(configuration: Dictionary) -> bool:
	connection = WebRTCPeerConnection.new()
	if connection.initialize(configuration) != OK:
		_fail("THIS BROWSER COULD NOT START WEBRTC")
		return false
	connection.session_description_created.connect(_on_description)
	connection.ice_candidate_created.connect(_on_ice)
	_peer = WebRTCMultiplayerPeer.new()
	var err := _peer.create_server() if _host else _peer.create_client(2)
	if err == OK:
		err = _peer.add_peer(connection, 2 if _host else 1, 100)
	if err != OK:
		_fail("COULD NOT START MULTIPLAYER")
		return false
	prepared.emit(_peer)
	return true


func _on_description(type: String, sdp: String) -> void:
	if not _active:
		return
	if connection.set_local_description(type, sdp) != OK:
		_fail("COULD NOT NEGOTIATE CONNECTION")
		return
	_enqueue({"type": type, "sdp": sdp})


func _on_ice(media: String, index: int, candidate: String) -> void:
	if _active:
		_enqueue({"type": "ice", "media": media, "index": index, "candidate": candidate})


func _enqueue(message: Dictionary) -> void:
	_sequence += 1
	message.seq = _sequence
	_outgoing.append(message)
	_next_poll = 0.0


func _receive(message: Dictionary) -> bool:
	var type := String(message.get("type", ""))
	if type == "offer" or type == "answer":
		if _remote_description or type != ("answer" if _host else "offer"):
			_fail("INVALID CONNECTION HANDSHAKE")
			return false
		if connection.set_remote_description(type, String(message.sdp)) != OK:
			_fail("COULD NOT NEGOTIATE CONNECTION")
			return false
		_remote_description = true
		for candidate in _pending_ice:
			if not _add_ice(candidate):
				return false
		_pending_ice.clear()
	elif type == "ice":
		if not _remote_description:
			_pending_ice.append(message)
		else:
			return _add_ice(message)
	return true


func _add_ice(message: Dictionary) -> bool:
	if connection.add_ice_candidate(String(message.media), int(message.index), String(message.candidate)) != OK:
		_fail("COULD NOT NEGOTIATE NETWORK ROUTE")
		return false
	return true


func _fail(message: String) -> void:
	_active = false
	failed.emit(message)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
