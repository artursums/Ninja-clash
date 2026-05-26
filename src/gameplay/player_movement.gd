class_name PlayerMovement
extends Node
## The player-verb composition layer (design/gdd/movement.md). Sits between Couch Input (intent)
## and the Character Controller (physics primitives): reads the stick + A-button, reads CC state,
## and decides the verb — walk, jump, jump-cut, dodge — composing them from CC's command API.
## A child of PlayerCharacterBody; one per slot, instantiated by Round Flow.
##
## Per ADR-0001 it reads NO input directly — only CouchInput intent + the primary_action signal.
##
## SCOPE (Sprint 2 / T4 — core verbs): walk, single ground-jump (+ coyote + jump-buffer),
## jump-cut, dodge (+ i-frames). Wall-jump/wall-slide → T5; drop-through → T6. Air-jump (double
## jump) is CUT per the prototype reconciliation in the GDD.

## Injected dependencies (DI for testability): the body to drive, the input source, the slot.
var cc: Object = null                ## PlayerCharacterBody (duck-typed so tests can stub it)
var input_source: Object = null      ## CouchInput autoload (get_intent + primary_action_pressed)
var slot: int = 0
var config: MovementConfig = MovementConfig.new()
var time_source: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var facing: int = 1

var _dodge_start_t: float = -INF
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _was_on_floor: bool = false
var _jumped: bool = false            ## a jump executed → the next floor-leave is a take-off, not coyote
var _dead: bool = false
var _last_move: Vector2 = Vector2.ZERO


func _ready() -> void:
	if cc == null:
		cc = get_parent()
	if input_source == null:
		input_source = get_node_or_null(^"/root/CouchInput")
	if input_source != null and input_source.has_signal("primary_action_pressed"):
		input_source.primary_action_pressed.connect(_on_primary_action_signal)


func _physics_process(delta: float) -> void:
	if input_source == null:
		return
	var intent = input_source.get_intent(slot)
	_tick(delta, intent.move, intent.primary_held)


func _on_primary_action_signal(pressed_slot: int) -> void:
	if pressed_slot == slot:
		on_primary_action()


# === Public queries (contracts for Combat / Visual FX) ===

## True for DODGE_TOTAL_DURATION_S after a dodge — A-button is locked during this window.
func is_dodging() -> bool:
	return (time_source.call() - _dodge_start_t) < config.dodge_total_duration_s


## True for DODGE_IFRAME_DURATION_S after a dodge — Combat catches instead of kills while true.
func is_iframe_active() -> bool:
	return (time_source.call() - _dodge_start_t) < config.dodge_iframe_duration_s


func is_dead() -> bool:
	return _dead


## Transition to the Dead state (Rule 13). Idempotent. Called by Combat on kill.
func set_dead() -> void:
	_dead = true


# === A-button decision tree (Rule 4, reconciled: no air-jump) ===

func on_primary_action() -> void:
	if _dead or is_dodging():
		return
	# (Rule 4.1 drop-through → T6; Rule 4.3 wall-jump → T5)
	if cc.is_stationary():                                   # 4.4 dodge
		_start_dodge()
		return
	if cc.is_on_floor() or _coyote_remaining > 0.0:           # 4.5 ground-jump
		_ground_jump()
		return
	# Air-jump CUT — no jump available airborne → buffer for the next landing (4.7).
	_jump_buffer_remaining = config.jump_buffer_s


# === Per-tick logic (called each physics tick; `_tick` is unit-testable off the tree) ===

func _tick(delta: float, move: Vector2, primary_held: bool) -> void:
	if _dead:
		return
	# Walk — suppressed during the dodge dash so it can't override the burst.
	if not is_dodging():
		cc.set_horizontal_intent(move.x * cc.config.max_hspeed_px_s)
	if move.x != 0.0:
		facing = int(signf(move.x))
	_last_move = move
	# Jump-cut: A released while rising → clamp the arc (Rule 9 / Formula 7).
	if cc.velocity.y < 0.0 and not primary_held:
		cc.cancel_jump()
	_update_timers(delta)


func _update_timers(delta: float) -> void:
	var on_floor: bool = cc.is_on_floor()
	if on_floor and not _was_on_floor:                        # landed
		_jumped = false
		if _jump_buffer_remaining > 0.0:                      # buffered jump fires on landing (Rule 11)
			_ground_jump()
	elif not on_floor and _was_on_floor:                      # left the floor
		if _jumped:
			_jumped = false                                   # jump take-off → no coyote
		else:
			_coyote_remaining = config.coyote_time_s          # walk-off → grant coyote (Rule 10)
	_was_on_floor = on_floor
	_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)


# === Verb implementations ===

func _ground_jump() -> void:
	cc.apply_jump_impulse(config.jump_strength)
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_jumped = true


func _start_dodge() -> void:
	cc.apply_dodge_impulse(_compute_dodge_direction(_last_move, facing), config.dodge_dash_speed)
	_dodge_start_t = time_source.call()


## Stick direction if past the neutral threshold, else a horizontal dash in the facing direction.
func _compute_dodge_direction(stick: Vector2, facing_dir: int) -> Vector2:
	if stick.length() >= config.stick_neutral_threshold:
		return stick.normalized()
	return Vector2(float(facing_dir), 0.0)
