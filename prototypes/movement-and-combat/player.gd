# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Player CharacterBody2D.
# Reads input per assigned slot (1 or 2). Handles walk, jump, dodge (with i-frames),
# throw, catch, deflect, die, respawn. Reads live tuning from Combat singleton.

extends CharacterBody2D

# === Hardcoded tuning (not exposed to TuningPanel) ===
const MAX_HSPEED := 220.0
const JUMP_STRENGTH := 480.0
const GRAVITY := 1400.0
const DODGE_DASH_SPEED := 320.0
const DODGE_TOTAL_DURATION_S := 0.30  # i-frame portion comes from Combat (live-tunable)
const PLAYER_W := 20.0
const PLAYER_H := 32.0
const STATIONARY_THRESHOLD := 5.0

# === Per-player config ===
var slot: int = 1
var spawn_pos: Vector2 = Vector2.ZERO

# === Runtime state ===
var facing: int = 1
var stash: int = 3
var alive: bool = true
var is_dodging: bool = false
var is_iframe: bool = false
var dodge_t_end: float = 0.0
var iframe_t_end: float = 0.0
var _first_tick_done: bool = false

# === Input action names (resolved from slot in _ready) ===
var input_left: String = ""
var input_right: String = ""
var input_jump: String = ""   # A-button: jump-or-dodge
var input_throw: String = ""

# === Visual children (built programmatically in main.gd) ===
# NOT @onready — resolve lazily with safe fallbacks
var visual: ColorRect = null
var stash_label: Label = null

signal stash_changed(slot: int, new_count: int)

func _ready() -> void:
	add_to_group("players")
	if slot == 1:
		input_left = "p1_left"
		input_right = "p1_right"
		input_jump = "p1_jump"
		input_throw = "p1_throw"
	else:
		input_left = "p2_left"
		input_right = "p2_right"
		input_jump = "p2_jump"
		input_throw = "p2_throw"
	# Resolve visual children
	visual = get_node_or_null("Visual") as ColorRect
	stash_label = get_node_or_null("StashLabel") as Label
	print("[PLAYER ", slot, "] _ready done. visual=", visual != null,
		" stash_label=", stash_label != null,
		" actions={l=", input_left, ", r=", input_right,
		", j=", input_jump, ", t=", input_throw, "}")

func _physics_process(delta: float) -> void:
	if not _first_tick_done:
		_first_tick_done = true
		print("[PLAYER ", slot, "] first _physics_process tick. pos=", position,
			" is_on_floor=", is_on_floor())
	if not alive:
		return
	var t: float = Time.get_ticks_msec() / 1000.0

	# Expire dodge / i-frame windows
	if is_iframe and t >= iframe_t_end:
		is_iframe = false
	if is_dodging and t >= dodge_t_end:
		is_dodging = false

	# Read movement input
	var move: float = 0.0
	if Input.is_action_pressed(input_left):
		move -= 1.0
	if Input.is_action_pressed(input_right):
		move += 1.0
	if move != 0.0:
		facing = int(sign(move))

	# Apply horizontal velocity (unless locked by dodge)
	if not is_dodging:
		velocity.x = move * MAX_HSPEED

	# Gravity always applied
	velocity.y += GRAVITY * delta

	# A-button: contextual jump-or-dodge
	if Input.is_action_just_pressed(input_jump):
		print("[PLAYER ", slot, "] jump_pressed. on_floor=", is_on_floor(),
			" vx=", velocity.x, " is_dodging=", is_dodging)
		if is_dodging:
			pass  # locked; ignore
		elif is_on_floor() and abs(velocity.x) < STATIONARY_THRESHOLD:
			_start_dodge(t)
		elif is_on_floor():
			velocity.y = -JUMP_STRENGTH

	# Throw
	if Input.is_action_just_pressed(input_throw) and stash > 0:
		print("[PLAYER ", slot, "] throw_pressed. stash=", stash)
		_throw_shuriken()

	move_and_slide()
	_update_visual()

func _start_dodge(t: float) -> void:
	is_dodging = true
	is_iframe = true
	iframe_t_end = t + Combat.dodge_iframe_duration_s
	dodge_t_end = t + DODGE_TOTAL_DURATION_S
	velocity.x = facing * DODGE_DASH_SPEED

func _throw_shuriken() -> void:
	var ShurikenScript: Script = load("res://shuriken.gd")
	var s = Area2D.new()
	s.set_script(ShurikenScript)
	s.thrower_slot = slot
	s.position = global_position + Vector2(facing * 16.0, -4.0)
	s.velocity_v = Vector2(facing * Combat.shuriken_throw_velocity, -30.0)
	s.throw_time = Time.get_ticks_msec() / 1000.0
	get_parent().add_child(s)
	stash -= 1
	stash_changed.emit(slot, stash)

# Called by shuriken.gd on overlap. Returns true if shuriken should be freed.
func hit_by_shuriken(shuriken) -> bool:
	if not alive:
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	# Self-hit immunity
	if shuriken.thrower_slot == slot and (t - shuriken.throw_time) < Combat.self_hit_immunity_s:
		return false  # pass through, do not free
	if is_iframe:
		if stash < 3:
			stash += 1
			stash_changed.emit(slot, stash)
			return true  # catch — free the shuriken
		else:
			# Deflect: mirror velocity, keep ownership
			shuriken.velocity_v = -shuriken.velocity_v
			shuriken.stuck = false
			return false
	else:
		_die()
		return true

func _die() -> void:
	alive = false
	stash_changed.emit(slot, stash)  # for UI consistency
	Combat.on_kill(slot)

func respawn(at_pos: Vector2) -> void:
	alive = true
	position = at_pos
	velocity = Vector2.ZERO
	is_dodging = false
	is_iframe = false
	stash = 3
	facing = 1 if slot == 1 else -1
	stash_changed.emit(slot, stash)

func _update_visual() -> void:
	if visual != null:
		if not alive:
			visual.color = Color(0.1, 0.1, 0.1, 0.4)
		elif is_iframe:
			visual.color = Color(1.0, 1.0, 0.2, 1.0)  # bright yellow during i-frames
		elif is_dodging:
			visual.color = Color(0.55, 0.55, 0.55, 1.0)  # grey during dodge recovery
		else:
			visual.color = Color(0.85, 0.25, 0.25, 1.0) if slot == 1 else Color(0.25, 0.45, 0.95, 1.0)
	if stash_label != null:
		stash_label.text = str(stash)
