# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Player CharacterBody2D. Sprite-based ninja silhouette tinted per clan.

extends CharacterBody2D

# === Hardcoded tuning ===
const MAX_HSPEED := 220.0
const JUMP_STRENGTH := 480.0
const AIR_JUMP_STRENGTH := 420.0
const GRAVITY := 1400.0
const PLAYER_TERMINAL_FALL_SPEED := 320.0   # TowerFall-style: caps fall acceleration so it feels constant
const STOMP_BOUNCE_STRENGTH := 260.0         # small TowerFall-style hop after stomping (~25 px height)
const DODGE_DASH_SPEED := 320.0
const DODGE_TOTAL_DURATION_S := 0.30
const SLIDE_SPEED := 520.0
const SLIDE_DURATION_S := 0.22
const DOUBLE_TAP_WINDOW_S := 0.25
const WALL_JUMP_VSTRENGTH := 540.0   # snappy upward kick (TowerFall-style climb)
const WALL_JUMP_HKICK := 200.0       # less sideways push so you can grab same wall again
const WALL_JUMP_LOCK_S := 0.10       # short lock so player can press back toward wall fast
const PLAYER_W := 20.0
const PLAYER_H := 32.0

# Sprite sheet frame indices — must match sprites/ninjas/generate_ninjas.py POSES order
const FRAME_IDLE := 0
const FRAME_WALK_1 := 1
const FRAME_WALK_2 := 2
const FRAME_JUMP := 3
const FRAME_ATTACK := 4
const WALK_CYCLE_S := 0.14   # ~7 fps gait

# === Per-player config ===
var slot: int = 1
var spawn_pos: Vector2 = Vector2.ZERO
# Clan tint comes from GameState.get_clan(slot).color (set per-match in clan select)

# === Runtime state ===
var facing: int = 1
var stash: int = 3
var alive: bool = true
var is_dodging: bool = false
var is_iframe: bool = false
var is_crouching: bool = false
var is_sliding: bool = false
var is_wall_grabbing: bool = false
var jumps_remaining: int = 2   # ground + air; resets to 2 whenever on floor
var dodge_t_end: float = 0.0
var iframe_t_end: float = 0.0
var slide_t_end: float = 0.0
var wall_jump_lock_until: float = -999.0
var last_left_tap_t: float = -999.0
var last_right_tap_t: float = -999.0
var throw_anim_until: float = 0.0   # show ATTACK frame for ~220ms after a throw
var _first_tick_done: bool = false

# === Input action names ===
var input_left: String = ""
var input_right: String = ""
var input_jump: String = ""
var input_crouch: String = ""
var input_throw: String = ""
var input_dodge: String = ""

# === Visual (sprite child added by main.gd) ===
var visual: Sprite2D = null

signal stash_changed(slot: int, new_count: int)

func _ready() -> void:
	add_to_group("players")
	var prefix = "p1" if slot == 1 else "p2"
	input_left = prefix + "_left"
	input_right = prefix + "_right"
	input_jump = prefix + "_jump"
	input_crouch = prefix + "_crouch"
	input_throw = prefix + "_throw"
	input_dodge = prefix + "_dodge"
	visual = get_node_or_null("Visual") as Sprite2D
	print("[PLAYER ", slot, "] _ready. visual=", visual != null)

func _physics_process(delta: float) -> void:
	if not _first_tick_done:
		_first_tick_done = true
		print("[PLAYER ", slot, "] first tick. pos=", position, " on_floor=", is_on_floor())
	if not alive:
		return
	# Freeze input during MATCH_INTRO countdown and ROUND_END pause
	if not GameState.is_round_active():
		velocity.x = 0.0
		# Still apply gravity gently to settle on platforms
		velocity.y = min(velocity.y + 600.0 * delta, 400.0)
		move_and_slide()
		_update_visual()
		return
	var t: float = Time.get_ticks_msec() / 1000.0

	# Expire timed windows
	if is_iframe and t >= iframe_t_end:
		is_iframe = false
	if is_dodging and t >= dodge_t_end:
		is_dodging = false
	if is_sliding and t >= slide_t_end:
		is_sliding = false

	# Crouch (visual only — hitbox unchanged)
	is_crouching = Input.is_action_pressed(input_crouch)

	# Double-tap slide detection
	if Input.is_action_just_pressed(input_left):
		if t - last_left_tap_t < DOUBLE_TAP_WINDOW_S:
			_start_slide(-1, t)
			last_left_tap_t = -999.0
		else:
			last_left_tap_t = t
	if Input.is_action_just_pressed(input_right):
		if t - last_right_tap_t < DOUBLE_TAP_WINDOW_S:
			_start_slide(1, t)
			last_right_tap_t = -999.0
		else:
			last_right_tap_t = t

	# Movement input
	var move: float = 0.0
	if Input.is_action_pressed(input_left):
		move -= 1.0
	if Input.is_action_pressed(input_right):
		move += 1.0

	# Physics queries
	var on_floor_now := is_on_floor()
	var on_wall_now := is_on_wall() and not on_floor_now
	var wall_normal: Vector2 = get_wall_normal() if on_wall_now else Vector2.ZERO

	# Refresh jumps whenever touching floor — forgiving timing (no transition required)
	if on_floor_now:
		jumps_remaining = 2

	# Wall-grab detection (airborne + touching wall + pressing INTO wall)
	is_wall_grabbing = false
	if on_wall_now and move != 0.0:
		if sign(move) == -sign(wall_normal.x):
			is_wall_grabbing = true

	# Facing update
	if move != 0.0 and not is_dodging and not is_sliding:
		facing = int(sign(move))

	# Apply horizontal velocity — priority: dodge > slide > wall-jump-lock > walk
	if is_dodging:
		pass
	elif is_sliding:
		velocity.x = facing * SLIDE_SPEED
	elif t < wall_jump_lock_until:
		pass
	else:
		velocity.x = move * MAX_HSPEED

	# Gravity
	velocity.y += GRAVITY * delta
	# Cap fall speed (TowerFall: predictable max, not endless acceleration)
	if velocity.y > PLAYER_TERMINAL_FALL_SPEED:
		velocity.y = PLAYER_TERMINAL_FALL_SPEED

	# Wall-grab vertical cap (slow slide down wall while pressing into it)
	if is_wall_grabbing and velocity.y > Combat.wall_grab_fall_speed:
		velocity.y = Combat.wall_grab_fall_speed

	# Jump: wall-jump (only when airborne and on wall) > ground/air via jumps_remaining
	if Input.is_action_just_pressed(input_jump):
		if on_wall_now and not on_floor_now:
			velocity.y = -WALL_JUMP_VSTRENGTH
			velocity.x = wall_normal.x * WALL_JUMP_HKICK
			facing = int(sign(wall_normal.x))
			wall_jump_lock_until = t + WALL_JUMP_LOCK_S
			is_wall_grabbing = false
			jumps_remaining = 2  # full double jump available — chain wall + 2 air jumps upward
		elif jumps_remaining > 0:
			var strength: float = JUMP_STRENGTH if on_floor_now else AIR_JUMP_STRENGTH
			velocity.y = -strength
			jumps_remaining -= 1

	# Dodge (dedicated key — cancels slide)
	if Input.is_action_just_pressed(input_dodge):
		if not is_dodging:
			is_sliding = false
			_start_dodge(t)

	# Throw
	if Input.is_action_just_pressed(input_throw) and stash > 0:
		_throw_shuriken()

	# Head-stomp detection: snapshot fall velocity, then check collisions after move
	var was_falling: bool = velocity.y > 50.0
	move_and_slide()
	if was_falling:
		_check_headstomp()
	_check_screen_wrap()
	_update_visual()

func _start_dodge(t: float) -> void:
	is_dodging = true
	is_iframe = true
	iframe_t_end = t + Combat.dodge_iframe_duration_s
	dodge_t_end = t + DODGE_TOTAL_DURATION_S
	velocity.x = facing * DODGE_DASH_SPEED
	Audio.play("dodge")

func _start_slide(dir: int, t: float) -> void:
	is_sliding = true
	facing = dir
	slide_t_end = t + SLIDE_DURATION_S
	velocity.x = dir * SLIDE_SPEED

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
	Audio.play("throw")
	throw_anim_until = Time.get_ticks_msec() / 1000.0 + 0.22

func hit_by_shuriken(shuriken) -> bool:
	if not alive:
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	if shuriken.thrower_slot == slot and (t - shuriken.throw_time) < Combat.self_hit_immunity_s:
		return false
	if is_iframe:
		if stash < 3:
			stash += 1
			stash_changed.emit(slot, stash)
			return true
		else:
			shuriken.velocity_v = -shuriken.velocity_v
			shuriken.stuck = false
			return false
	else:
		_die()
		return true

# Called by another player who landed on top of us (head-stomp).
# Returns true if the stomp killed us — stomper bounces only on a successful kill.
func hit_by_stomp(_stomper) -> bool:
	if not alive:
		return false
	if is_iframe:
		return false   # dodge i-frames block the stomp (TowerFall-style dodge cancel)
	_die()
	return true

# Detect if we landed on top of another player this frame and trigger the stomp.
func _check_headstomp() -> void:
	if not alive:
		return
	for i in get_slide_collision_count():
		var coll: KinematicCollision2D = get_slide_collision(i)
		var other = coll.get_collider()
		if other == null or other == self:
			continue
		if not (other is CharacterBody2D) or not other.has_method("hit_by_stomp"):
			continue
		# Normal points outward from the collided surface. Landing on top of
		# another player → their top-surface normal points up (-Y).
		if coll.get_normal().y < -0.5:
			if other.hit_by_stomp(self):
				velocity.y = -STOMP_BOUNCE_STRENGTH   # bounce up
				jumps_remaining = 2                    # refresh for chain stomps

func _die() -> void:
	alive = false
	stash_changed.emit(slot, stash)
	Combat.on_kill(slot)

func respawn(at_pos: Vector2) -> void:
	alive = true
	position = at_pos
	velocity = Vector2.ZERO
	is_dodging = false
	is_iframe = false
	is_crouching = false
	is_sliding = false
	is_wall_grabbing = false
	jumps_remaining = 2
	wall_jump_lock_until = -999.0
	last_left_tap_t = -999.0
	last_right_tap_t = -999.0
	stash = 3
	facing = 1 if slot == 1 else -1
	stash_changed.emit(slot, stash)

func _check_screen_wrap() -> void:
	# TowerFall-style: fall off bottom → appear at top; rise above top → appear at bottom.
	# X is PRESERVED so a wall-slide stays on the wall continuously through the wrap.
	if position.y > 470.0:
		position.y = -30.0
	elif position.y < -60.0:
		position.y = 470.0

func _update_visual() -> void:
	if visual == null:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	# === Pick sprite frame (priority: dead > action > airborne > walking > idle) ===
	var f: int = FRAME_IDLE
	if not alive:
		f = FRAME_IDLE
	elif is_dodging or is_sliding or t < throw_anim_until:
		f = FRAME_ATTACK
	elif is_wall_grabbing:
		f = FRAME_JUMP
	elif not is_on_floor():
		f = FRAME_JUMP
	elif abs(velocity.x) > 15.0:
		# Walk cycle — alternate every WALK_CYCLE_S
		f = FRAME_WALK_1 if (int(t / WALK_CYCLE_S) % 2 == 0) else FRAME_WALK_2
	else:
		f = FRAME_IDLE
	visual.frame = f
	# === Modulate overlay (state tint on top of sprite's native colors) ===
	if not alive:
		visual.modulate = Color(0.25, 0.25, 0.30, 0.55)
	elif is_iframe:
		# Bright yellow flash ~12 Hz
		var blink: bool = (int(t * 12.0) % 2 == 0)
		visual.modulate = Color(1.8, 1.8, 0.5, 1.0) if blink else Color.WHITE
	else:
		visual.modulate = Color.WHITE
	# === Facing — horizontal flip ===
	visual.flip_h = (facing < 0)
