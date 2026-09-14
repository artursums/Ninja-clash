# Autoload: Net
# Online multiplayer session manager — 2–4 players over ENet / WebRTC.
# The host simulates every fighter. Guests send per-peer input and render authoritative
# snapshots; no client-side prediction. Reliable RPCs carry roster, rules and match state.

extends Node

const DEFAULT_PORT := 24565
const SNAPSHOT_EVERY_N_TICKS := 2       # 60 Hz physics → 30 Hz snapshots
const JOIN_TIMEOUT_S := 8.0
# Sim SFX relayed host → client. Menu/countdown cues are NOT relayed — the client's own
# screens generate those locally (relaying would double them).
const RELAY_SFX := ["throw", "hit", "dodge", "block", "click"]

enum NetMode { OFFLINE, HOST, CLIENT }

var mode: int = NetMode.OFFLINE
var last_status: String = ""            # shown on the online menu (disconnect reasons etc.)
var _peer_id: int = 0                   # A connected peer, or zero when waiting alone.
var _tick: int = 0
var _next_net_id: int = 0
var _join_deadline: float = 0.0
var _web_room: Node = null
var invitation_code := ""
const Roster := preload("res://online_roster.gd")
const PROTOCOL := 5
var lobby := Roster.new()
var player_name := ""
var lobby_message := ""
var _remote_inputs: Dictionary = {}
var _pending_peers: Dictionary = {}
var _starting := false
var _start_generation := 0
signal lobby_changed
signal lobby_error(message: String)

signal room_created(code: String)
signal connection_status(message: String)

# Client-side: puppet projectile registries (net_id → node).
var _puppet_shurikens: Dictionary = {}
var _puppet_waves: Dictionary = {}

var _main: Node = null                  # main.gd registers itself (arena root + players live there)

signal session_ended(reason: String)            # any disconnect / failure / deliberate leave
signal map_roll_started(from: int, target: int)
signal map_cursor_changed(cursor: int)          # client ← host: map-select browsing


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return mode != NetMode.OFFLINE


func is_host() -> bool:
	return mode == NetMode.HOST


func is_client() -> bool:
	return mode == NetMode.CLIENT


## main.gd hands us its arena so snapshots/FX can reach the players and projectile parents.
func register_main(m: Node) -> void:
	_main = m


func next_id() -> int:
	_next_net_id += 1
	return _next_net_id


# === Session lifecycle =======================================================

## Open a server with room for three guests. Returns "" on success, an error text otherwise.
func host_game(port: int = DEFAULT_PORT) -> String:
	_shutdown("", false)
	if player_name == "":
		return "ENTER YOUR PLAYER NAME"
	if OS.has_feature("web"):
		return _start_web_room(true, "")
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(port, Roster.MAX_PLAYERS - 1)
	if err != OK:
		return "CAN'T OPEN SERVER — PORT %d BUSY?" % port
	multiplayer.multiplayer_peer = peer
	mode = NetMode.HOST
	last_status = ""
	_open_host_lobby()
	return ""


## Connect to a host. Returns "" when the attempt started, an error text otherwise.
func join_game(ip: String, port: int = DEFAULT_PORT) -> String:
	if player_name == "":
		return "ENTER YOUR PLAYER NAME"
	if OS.has_feature("web"):
		var code: String = preload("res://web_room.gd").parse_room(ip)
		if code == "":
			return "ENTER A ROOM CODE OR INVITE LINK"
		_shutdown("", false)
		return _start_web_room(false, code)
	_shutdown("", false)
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, port)
	if err != OK:
		return "INVALID ADDRESS"
	multiplayer.multiplayer_peer = peer
	mode = NetMode.CLIENT
	_join_deadline = _now() + JOIN_TIMEOUT_S
	last_status = ""
	return ""


func _start_web_room(as_host: bool, code: String) -> String:
	mode = NetMode.HOST if as_host else NetMode.CLIENT
	invitation_code = code
	last_status = ""
	_web_room = preload("res://web_room.gd").new()
	add_child(_web_room)
	_web_room.prepared.connect(func(peer): multiplayer.multiplayer_peer = peer)
	_web_room.room_created.connect(func(room: String):
		invitation_code = room
		room_created.emit(room)
		_open_host_lobby())
	_web_room.status_changed.connect(func(message: String): connection_status.emit(message))
	_web_room.failed.connect(func(message: String): _shutdown(message, true))
	_web_room.lock_completed.connect(_on_room_locked)
	_web_room.start(as_host, code)
	return ""


func invitation_url() -> String:
	if not OS.has_feature("web") or invitation_code == "":
		return ""
	return String(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)) + "#room=" + invitation_code


func pending_invitation() -> String:
	if not OS.has_feature("web"):
		return ""
	return preload("res://web_room.gd").parse_room(String(JavaScriptBridge.eval("window.location.href", true)))


## Deliberate leave (menu back / quit to menu). Notifies the other side first when connected.
func leave(reason: String = "") -> void:
	if is_host() and _peer_id != 0:
		_session_closed.rpc("HOST LEFT")
	player_name = ""
	_shutdown(reason, false)


## Tear the session down. `notify_screens` routes the local player to the online menu with a
## status message (used for unexpected drops mid-flow).
func _shutdown(reason: String, notify_screens: bool) -> void:
	var was_online := is_online()
	mode = NetMode.OFFLINE
	if _web_room != null:
		var room: Node = _web_room
		_web_room = null
		room.stop()
		room.queue_free()
	invitation_code = ""
	_peer_id = 0
	_join_deadline = 0.0
	_remote_inputs.clear()
	_pending_peers.clear()
	lobby = Roster.new()
	_starting = false
	_start_generation += 1
	GameState.online_players.clear()
	_clear_puppets()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	if reason != "":
		last_status = reason
	if was_online and notify_screens:
		session_ended.emit(reason)
		GameState.change_state(GameState.State.ONLINE_MENU)


func _clear_puppets() -> void:
	for d in [_puppet_shurikens, _puppet_waves]:
		for id in d:
			var n = d[id]
			if is_instance_valid(n):
				n.queue_free()
		d.clear()


## LAN IPv4 addresses of this machine — shown on the host screen so the friend knows where to join.
func local_ipv4_addresses() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s: String = String(a)
		if s.count(".") == 3 and not s.begins_with("127."):
			out.append(s)
	return out


# === Connection signals ======================================================

func _open_host_lobby() -> void:
	lobby.add(1, player_name)
	GameState.game_mode = GameState.Mode.HUMAN_VS_HUMAN
	_publish_lobby()
	GameState.change_state(GameState.State.ONLINE_LOBBY)


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	_pending_peers[id] = _now() + JOIN_TIMEOUT_S
	if _web_room != null:
		_web_room.mark_connected(id)


@rpc("any_peer", "call_remote", "reliable")
func _hello(display_name: String, protocol: int) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if not _pending_peers.has(id):
		return
	_pending_peers.erase(id)
	if protocol != PROTOCOL or _starting or not lobby.add(id, display_name):
		_session_closed.rpc_id(id, "ROOM FULL, STARTED OR INCOMPATIBLE")
		_disconnect_peer.call_deferred(id)
		return
	_peer_id = id
	_remote_inputs[id] = {"held": 0, "pressed": 0, "seen": 0.0}
	lobby_message = "%s JOINED" % lobby.member(id).name
	_publish_lobby()
	_apply_state.rpc_id(id, GameState.State.ONLINE_LOBBY, _build_state_bundle())


func _disconnect_peer(id: int) -> void:
	if _web_room != null:
		_web_room.remove_guest(id)
	elif multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	_pending_peers.erase(id)
	_remote_inputs.erase(id)
	var player := lobby.member(id)
	if player.is_empty():
		return
	var departed := String(player.name)
	lobby.remove(id)
	_peer_id = int(lobby.members[1].peer) if lobby.members.size() > 1 else 0
	if _web_room != null:
		_web_room.remove_guest(id)
	return_to_lobby("%s LEFT — READY AGAIN TO CONTINUE" % departed)


func _on_connected_to_server() -> void:
	_peer_id = 1
	_join_deadline = 0.0
	if _web_room != null:
		_web_room.mark_connected(1)
	_hello.rpc_id(1, player_name, PROTOCOL)


func _on_connection_failed() -> void:
	_shutdown("CONNECTION FAILED", true)


func _on_server_disconnected() -> void:
	_shutdown("CONNECTION LOST", true)


@rpc("authority", "call_remote", "reliable")
func _session_closed(reason: String) -> void:
	_shutdown(reason, true)


# === Per-tick pumps ==========================================================

func _physics_process(_delta: float) -> void:
	match mode:
		NetMode.HOST:
			for id in _pending_peers.keys():
				if _now() > _pending_peers[id]:
					_pending_peers.erase(id)
					_disconnect_peer(id)
			for input in _remote_inputs.values():
				if _now() - input.seen > 0.25:
					input.held = 0
					input.pressed = 0
			if _peer_id == 0:
				return
			_tick += 1
			if _tick % SNAPSHOT_EVERY_N_TICKS == 0 and _main != null and GameState.current_state in [GameState.State.MATCH_INTRO, GameState.State.ROUND, GameState.State.ROUND_END]:
				_snapshot.rpc(_build_snapshot())
		NetMode.CLIENT:
			if _peer_id != 0:
				_intent.rpc_id(1, _local_held_mask(), _local_pressed_mask())
			elif _join_deadline > 0.0 and _now() > _join_deadline:
				_shutdown("HOST NOT RESPONDING", true)


## Merged local devices → held mask. Online there is ONE local human per machine, so both the
## p1_* (gamepad) and p2_* (keyboard) action sets drive them — keyboard-only players included.
func _local_held_mask() -> int:
	if PlayerInput.suppress_local:
		return 0   # local pause overlay open — this machine's fighter stands down
	var mask: int = 0
	for i in NetCodec.ACTIONS.size():
		var a: String = NetCodec.ACTIONS[i]
		if Input.is_action_pressed("p1_" + a) or Input.is_action_pressed("p2_" + a):
			mask |= 1 << i
	return mask


func _local_pressed_mask() -> int:
	if PlayerInput.suppress_local:
		return 0
	var mask: int = 0
	for i in NetCodec.ACTIONS.size():
		var a: String = NetCodec.ACTIONS[i]
		if Input.is_action_just_pressed("p1_" + a) or Input.is_action_just_pressed("p2_" + a):
			mask |= 1 << i
	return mask


# === Remote intent (host side, consumed by PlayerInputRouter) ===============

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _intent(held_mask: int, pressed_mask: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not _remote_inputs.has(id):
		return
	var input: Dictionary = _remote_inputs[id]
	input.seen = _now()
	input.held = held_mask
	input.pressed |= pressed_mask


func remote_held(slot: int, action_suffix: String) -> bool:
	var input := _input_for_slot(slot)
	return NetCodec.mask_has(int(input.get("held", 0)), action_suffix)


func consume_remote_pressed(slot: int) -> int:
	var input := _input_for_slot(slot)
	var mask := int(input.get("pressed", 0))
	input.pressed = 0
	return mask


func _input_for_slot(slot: int) -> Dictionary:
	for player in lobby.members:
		if int(player.slot) == slot:
			return _remote_inputs.get(int(player.peer), {})
	return {}


# === World snapshot (host → client) =========================================

func _build_snapshot() -> Dictionary:
	var now: float = _now()
	var players: Array = []
	for p in _main.players:
		players.append(NetCodec.encode_player(p, now))
	var shuris: Array = []
	for s in get_tree().get_nodes_in_group("shurikens"):
		shuris.append(NetCodec.encode_shuriken(s))
	var waves: Array = []
	for w in get_tree().get_nodes_in_group("blade_waves"):
		waves.append(NetCodec.encode_wave(w))
	var platforms: Array = []
	for platform in _main.current_map_nodes:
		if platform.is_in_group("crumble_platforms"):
			platforms.append([platform.phase, platform.remaining])
	return {"p": players, "s": shuris, "w": waves, "c": platforms, "perks": _main.perk_director.snapshot(), "clock": _main.round_clock.snapshot(), "map": _main._current_loaded_map}


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(snap: Dictionary) -> void:
	if not is_client() or _main == null:
		return
	if int(snap.get("map", -1)) != _main._current_loaded_map:
		return
	_main.perk_director.apply_snapshot(snap.get("perks", []))
	_main.round_clock.apply_snapshot(snap.get("clock", []))
	var platforms: Array = snap.get("c", [])
	var index := 0
	for platform in _main.current_map_nodes:
		if platform.is_in_group("crumble_platforms"):
			if index < platforms.size():
				platform.apply_snapshot(platforms[index])
			index += 1
	var now: float = _now()
	for arr in snap.get("p", []):
		var slot: int = int(arr[NetCodec.P.SLOT])
		for p in _main.players:
			if p.slot == slot:
				NetCodec.apply_player(p, arr, now)
				break
	_apply_projectiles(_puppet_shurikens, snap.get("s", []), NetCodec.S.ID, _spawn_puppet_shuriken)
	_apply_projectiles(_puppet_waves, snap.get("w", []), NetCodec.W.ID, _spawn_puppet_wave)


## Sync one puppet-projectile registry against the snapshot list: create the new, update the
## living, free the gone (a consumed/hit projectile simply stops appearing).
func _apply_projectiles(registry: Dictionary, list: Array, id_idx: int, spawner: Callable) -> void:
	var seen: Dictionary = {}
	for arr in list:
		var id: int = int(arr[id_idx])
		seen[id] = true
		var node = registry.get(id)
		if node == null or not is_instance_valid(node):
			node = spawner.call(arr)
			if node == null:
				continue
			registry[id] = node
		node.apply_net(arr)
	for id in registry.keys():
		var node = registry[id]
		if not seen.has(id) or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			registry.erase(id)


func _spawn_puppet_shuriken(arr: Array) -> Node:
	if _main == null:
		return null
	var s: Area2D = Area2D.new()
	s.set_script(load("res://shuriken.gd"))
	s.puppet = true
	s.net_id = int(arr[NetCodec.S.ID])
	s.thrower_slot = int(arr[NetCodec.S.THROWER])
	s.position = Vector2(arr[NetCodec.S.X], arr[NetCodec.S.Y])
	_main.arena_root.add_child(s)
	return s


func _spawn_puppet_wave(arr: Array) -> Node:
	if _main == null:
		return null
	var w: Area2D = Area2D.new()
	w.set_script(load("res://blade_wave.gd"))
	w.puppet = true
	w.net_id = int(arr[NetCodec.W.ID])
	w.thrower_slot = int(arr[NetCodec.W.THROWER])
	w.velocity_v = Vector2(arr[NetCodec.W.VX], arr[NetCodec.W.VY])
	var clan: Dictionary = GameState.get_clan(w.thrower_slot)
	w.tint = clan.get("secondary", Color(0.7, 0.9, 1.0))
	w.position = Vector2(arr[NetCodec.W.X], arr[NetCodec.W.Y])
	_main.arena_root.add_child(w)
	return w


# === Screen/state + score sync (host → client) ==============================

## Hooked from GameState.change_state. The host mirrors every screen change to the client with
## the full match context, EXCEPT the host-local Fight Setup screen (the client keeps its lobby
## while the host tweaks variants; the config ships inside the next state bundle).
func on_local_state_changed(s: int) -> void:
	if not is_host():
		return
	if s == GameState.State.MATCH_SETUP:
		return
	# The host walking out to the offline menus ends the session (a client at TITLE while still
	# connected makes no sense) — the guest is notified and lands on its online menu.
	if s == GameState.State.TITLE or s == GameState.State.MODE_SELECT:
		leave("")
		return
	if _peer_id != 0:
		_apply_state.rpc(s, _build_state_bundle())


func _build_state_bundle() -> Dictionary:
	return {
		"mode": GameState.game_mode,
		"players": lobby.members.duplicate(true),
		"round": GameState.current_round,
		"map": GameState.selected_map_index,
		"p1_clan": GameState.p1_clan, "p2_clan": GameState.p2_clan,
		"p1_skin": GameState.p1_skin, "p2_skin": GameState.p2_skin,
		"target": GameState.target_score,
		"winner": GameState.match_winner_slot,
		"round_winner": _main._round_winner_slot if _main != null else 0,
		"clock": _main.round_clock.snapshot() if _main != null else [],
		"last_killer": GameState.last_kill_killer, "last_victim": GameState.last_kill_victim,
		"scores": Combat.scores,
		"stats": Combat.match_stats.duplicate(true),
		"cfg": {
			"katana_enabled": MatchConfig.katana_enabled,
			"katana_recharge": MatchConfig.katana_recharge,
			"katana_charges": MatchConfig.katana_charges,
			"shurikens_enabled": MatchConfig.shurikens_enabled,
			"start_shurikens": MatchConfig.start_shurikens,
			"infinite_shurikens": MatchConfig.infinite_shurikens,
			"max_hp": MatchConfig.max_hp,
			"blade_wave_enabled": MatchConfig.blade_wave_enabled,
			"round_time_seconds": MatchConfig.round_time_seconds,
		},
	}


@rpc("authority", "call_remote", "reliable")
func _apply_state(s: int, bundle: Dictionary) -> void:
	if not is_client():
		return
	GameState.game_mode = int(bundle.get("mode", GameState.game_mode))
	GameState.apply_online_players(bundle.get("players", []))
	GameState.current_round = int(bundle.get("round", 1))
	GameState.selected_map_index = int(bundle.get("map", 0))
	GameState.p1_clan = int(bundle.get("p1_clan", 0))
	GameState.p2_clan = int(bundle.get("p2_clan", 1))
	GameState.p1_skin = int(bundle.get("p1_skin", 0))
	GameState.p2_skin = int(bundle.get("p2_skin", 0))
	GameState.target_score = int(bundle.get("target", 5))
	GameState.match_winner_slot = int(bundle.get("winner", 0))
	GameState.last_kill_killer = int(bundle.get("last_killer", 0))
	GameState.last_kill_victim = int(bundle.get("last_victim", 0))
	Combat.match_stats = bundle.get("stats", {}).duplicate(true)
	Combat.scores = bundle.get("scores", Combat.scores)
	Combat.score_changed.emit()
	_apply_rules(bundle)
	if _main != null:
		_main._round_winner_slot = int(bundle.get("round_winner", 0))
	GameState.change_state(s)
	if _main != null:
		_main.round_clock.apply_snapshot(bundle.get("clock", []))


# === Lobby sync (clan + map select) =========================================

## Host → client: map-select browsing position (the client watches the host choose).
func send_map_cursor(cursor: int) -> void:
	if is_host() and _peer_id != 0:
		_map_cursor.rpc(cursor)


@rpc("authority", "call_remote", "reliable")
func _map_cursor(cursor: int) -> void:
	if is_client():
		map_cursor_changed.emit(cursor)


# === SFX / FX relay (host → client) =========================================

## Called by Audio.play on every SFX. Mirrors combat sounds to the client during match screens;
## menu screens generate their own sounds locally on each machine.
func relay_sfx(key: String) -> void:
	if not is_host() or _peer_id == 0:
		return
	if not key in RELAY_SFX:
		return
	var s: int = GameState.current_state
	if s == GameState.State.ROUND or s == GameState.State.ROUND_END or s == GameState.State.MATCH_INTRO:
		_sfx.rpc(key)


@rpc("authority", "call_remote", "unreliable")
func _sfx(key: String) -> void:
	if is_client():
		Audio.play(key)


## Called by the sim's strip-FX spawners (dust, clash lightning, strike flash) so the client
## sees the same juice. scale is a Vector2 — dust mirrors by negative x.
func relay_strip_fx(path: String, frame_count: int, fps: float, pos: Vector2, fx_scale: Vector2, z: int) -> void:
	if is_host() and _peer_id != 0:
		_strip_fx.rpc(path, frame_count, fps, pos, fx_scale, z)


@rpc("authority", "call_remote", "unreliable")
func _strip_fx(path: String, frame_count: int, fps: float, pos: Vector2, fx_scale: Vector2, z: int) -> void:
	if not is_client() or _main == null or not ResourceLoader.exists(path):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = frame_count
	fx.fps = fps
	fx.texture = load(path)
	fx.position = pos
	fx.scale = fx_scale
	fx.z_index = z
	_main.arena_root.add_child(fx)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func send_map_roll(from: int, target: int) -> void:
	if is_host() and _peer_id != 0:
		_map_roll.rpc(from,target)

@rpc("authority", "call_remote", "reliable")
func _map_roll(from: int, target: int) -> void:
	map_roll_started.emit(from,target)

func local_member() -> Dictionary:
	return lobby.member(multiplayer.get_unique_id()) if is_online() and multiplayer.multiplayer_peer != null else {}


func _publish_lobby() -> void:
	GameState.apply_online_players(lobby.members)
	lobby_changed.emit()
	if _peer_id != 0:
		_lobby_state.rpc(_build_state_bundle(), lobby.rules_revision, lobby.editing_rules, lobby.locked, lobby_message)


@rpc("authority", "call_remote", "reliable")
func _lobby_state(bundle: Dictionary, revision: int, editing: bool, locked: bool, message: String) -> void:
	if not is_client():
		return
	lobby.members = bundle.get("players", []).duplicate(true)
	lobby.rules_revision = revision
	lobby.editing_rules = editing
	lobby.locked = locked
	lobby_message = message
	GameState.apply_online_players(lobby.members)
	GameState.selected_map_index = int(bundle.get("map", 0))
	_apply_rules(bundle)
	lobby_changed.emit()


func choose_character(clan: int, skin: int, ready: bool) -> void:
	if is_host():
		_accept_pick(1, clan, skin, ready, lobby.rules_revision)
	elif is_client():
		_lobby_pick.rpc_id(1, clan, skin, ready, lobby.rules_revision)


@rpc("any_peer", "call_remote", "reliable")
func _lobby_pick(clan: int, skin: int, ready: bool, revision: int) -> void:
	if is_host():
		_accept_pick(multiplayer.get_remote_sender_id(), clan, skin, ready, revision)


func _accept_pick(id: int, clan: int, skin: int, ready: bool, revision: int) -> void:
	var error := lobby.pick(id, clan, skin, ready, revision, GameState.skin_count())
	if error != "":
		if id == 1:
			lobby_error.emit(error)
		else:
			_pick_error.rpc_id(id, error)
		return
	lobby_message = ""
	_publish_lobby()


@rpc("authority", "call_remote", "reliable")
func _pick_error(error: String) -> void:
	if is_client():
		lobby_error.emit(error)


func choose_map() -> void:
	if not is_host() or lobby.locked:
		return
	GameState.selected_map_index = (GameState.selected_map_index + 1) % Maps.count()
	lobby.invalidate_ready()
	lobby_message = "ARENA CHANGED — READY AGAIN"
	_publish_lobby()


func edit_rules() -> void:
	if not is_host() or lobby.locked:
		return
	lobby.editing_rules = true
	lobby.invalidate_ready()
	lobby_message = "HOST IS CHOOSING THE RULES"
	_publish_lobby()
	GameState.change_state(GameState.State.MATCH_SETUP)


func finish_rules() -> void:
	if not is_host():
		return
	lobby.editing_rules = false
	lobby_message = "CHECK THE RULES AND READY UP"
	_publish_lobby()
	GameState.change_state(GameState.State.ONLINE_LOBBY)


func start_lobby_match() -> void:
	if not is_host() or not lobby.can_start() or _starting:
		return
	if not _pending_peers.is_empty():
		lobby_error.emit("A PLAYER IS STILL CONNECTING")
		return
	_starting = true
	_start_generation += 1
	lobby.locked = true
	lobby_message = "STARTING MATCH…"
	_publish_lobby()
	multiplayer.multiplayer_peer.refuse_new_connections = true
	if _web_room != null:
		var peers: Array = []
		for player in lobby.members:
			if int(player.peer) != 1:
				peers.append(int(player.peer))
		_web_room.lock_room(peers, _start_generation)
	else:
		_on_room_locked("", _start_generation)


func _on_room_locked(error: String, generation: int) -> void:
	if not is_host():
		return
	if not _starting or generation != _start_generation:
		return
	_starting = false
	if error != "":
		lobby.locked = false
		multiplayer.multiplayer_peer.refuse_new_connections = false
		lobby_message = error
		_publish_lobby()
		return
	GameState.apply_online_players(lobby.members)
	GameState.start_new_match()


func return_to_lobby(message: String = "READY UP FOR THE NEXT MATCH") -> void:
	if not is_host():
		return
	_starting = false
	_start_generation += 1
	lobby.locked = false
	lobby.editing_rules = false
	lobby.invalidate_ready()
	lobby_message = message
	multiplayer.multiplayer_peer.refuse_new_connections = false
	if _web_room != null:
		_web_room.reopen()
	_publish_lobby()
	GameState.change_state(GameState.State.ONLINE_LOBBY)


func _apply_rules(bundle: Dictionary) -> void:
	GameState.target_score = int(bundle.get("target", 5))
	MatchConfig.target_score = GameState.target_score
	var cfg: Dictionary = bundle.get("cfg", {})
	# The match variants come from the host verbatim — do NOT persist them into the client's own
	# saved config (direct field writes, no set_* mutators).
	if not cfg.is_empty():
		MatchConfig.katana_enabled = bool(cfg.get("katana_enabled", true))
		MatchConfig.katana_recharge = bool(cfg.get("katana_recharge", true))
		MatchConfig.katana_charges = int(cfg.get("katana_charges", 3))
		MatchConfig.shurikens_enabled = bool(cfg.get("shurikens_enabled", true))
		MatchConfig.start_shurikens = int(cfg.get("start_shurikens", 3))
		MatchConfig.infinite_shurikens = bool(cfg.get("infinite_shurikens", false))
		MatchConfig.max_hp = int(cfg.get("max_hp", 5))
		MatchConfig.blade_wave_enabled = bool(cfg.get("blade_wave_enabled", false))
		MatchConfig.round_time_seconds = MatchConfig.normalize_round_time(int(cfg.get("round_time_seconds", MatchConfig.DEFAULT_ROUND_TIME)))
