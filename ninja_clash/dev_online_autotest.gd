# DEV ONLY — scripted driver for the online smoke test. Attached by main.gd when the process
# is launched with `-- --online-autotest` (see _handle_dev_args). Never part of a player build.
#
# Walks a full online session end-to-end with synthetic key events:
#   lobby: both sides confirm their default clans → host confirms the default arena →
#   both close the HOW TO PLAY overlay → countdown → ROUND.
# In the round the GUEST holds RIGHT and taps THROW, then verifies its own puppet fighter
# actually moved — which proves the whole pipeline: local intent → host simulation →
# snapshot → client puppet. Prints [AUTOTEST] lines and quits with 0 (PASS) / 1 (FAIL).

extends Node

const RUN_S := 6.0          # how long the guest drives its fighter before the verdict
const MOVE_PASS_PX := 20.0  # puppet must travel at least this far to count as "moving"

var _t: float = 0.0
var _cur_state: int = -1
var _since: float = 0.0
var _done: Dictionary = {}
var _round_entered_t: float = -1.0
var _start_x: float = -999.0
var _log_next: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	var s: int = GameState.current_state
	if s != _cur_state:
		_cur_state = s
		_since = _t
		_done.clear()
	var S = GameState.State
	var role: String = "host" if Net.is_host() else "client"

	match s:
		S.CLAN_SELECT:
			_once("confirm_clan", 1.2, func() -> void:
				print("[AUTOTEST] %s: confirming clan" % role)
				_tap(KEY_ENTER))
		S.MAP_SELECT:
			if Net.is_host():
				_once("confirm_map", 1.2, func() -> void:
					print("[AUTOTEST] host: confirming arena")
					_tap(KEY_ENTER))
				_once("start_fight", 1.8, func() -> void:
					_tap(KEY_ENTER))
		S.MATCH_INTRO:
			_once("close_tutorial", 1.2, func() -> void:
				_tap(KEY_ENTER))
		S.ROUND:
			_drive_round(role)

	# Host endgame: once the guest quits, the session drops — a clean host exit is the PASS.
	if Net.is_host() == false and Net.is_client() == false and _round_entered_t > 0.0:
		print("[AUTOTEST] %s: session over after ROUND — quitting" % role)
		get_tree().quit(0)


func _drive_round(role: String) -> void:
	if _round_entered_t < 0.0:
		_round_entered_t = _t
		print("[AUTOTEST] %s: ROUND reached" % role)
	if Net.is_host():
		# Projectile-replication probe: the host's P1 throws straight up (open air → the blade
		# sticks to the ceiling and persists). White-box on purpose: synthetic key events
		# injected from _process never register as physics-tick "just pressed" edges, so the
		# aim-release path can't be driven by fake keys — real keyboards don't have that issue.
		_once("host_throw", 1.0, func() -> void:
			var p1: Node = _player(1)
			if p1 != null:
				print("[AUTOTEST] host: P1 throws (direct sim call)")
				p1._throw_shuriken(Vector2(0, -1)))
		return
	_once("run_right", 2.0, func() -> void:
		_key(KEY_D, true))   # hold RIGHT — the guest's fighter should start running
	var p2: Node = _player(2)
	if _start_x < -900.0 and p2 != null and _t - _round_entered_t > 0.5:
		_start_x = p2.position.x
	if _t >= _log_next:
		_log_next = _t + 1.0
		if p2 != null:
			print("[AUTOTEST] client: t=%.1f p2=(%.0f,%.0f) puppet_shuris=%d" %
					[_t - _round_entered_t, p2.position.x, p2.position.y, Net._puppet_shurikens.size()])
	if _t - _round_entered_t > RUN_S:
		var moved: float = absf(p2.position.x - _start_x) if p2 != null else 0.0
		if moved >= MOVE_PASS_PX:
			print("[AUTOTEST] client: PASS — puppet fighter moved %.0f px on remote input" % moved)
			get_tree().quit(0)
		else:
			print("[AUTOTEST] client: FAIL — puppet fighter moved only %.0f px" % moved)
			get_tree().quit(1)


func _once(key: String, after_s: float, action: Callable) -> void:
	if _done.has(key) or _t - _since < after_s:
		return
	_done[key] = true
	action.call()


func _player(slot: int) -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		if p.slot == slot:
			return p
	return null


func _tap(key: int) -> void:
	_key(key, true)
	get_tree().create_timer(0.15).timeout.connect(func() -> void: _key(key, false))


func _key(key: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.pressed = pressed
	Input.parse_input_event(ev)
