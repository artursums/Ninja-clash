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
const SLIDE_SPEED := 400.0       # softer than the old 520 — was launching the player too far
const SLIDE_DURATION_S := 0.20   # ~80px slide (was ~114px)
const SLIDE_COOLDOWN_S := 0.417  # ground re-dash cooldown — TowerFall dodge cooldown (25 frames @ 60fps)
const SLIDE_AIR_REFRESH_S := 0.5 # after the air dash is spent, recharge this long after touching a surface
const DOUBLE_TAP_WINDOW_S := 0.25 # P2 keyboard: two taps of A/D within this window = dash (slot 2 only)
const WALL_JUMP_VSTRENGTH := 540.0   # snappy upward kick (TowerFall-style climb)
const WALL_JUMP_HKICK := 200.0       # less sideways push so you can grab same wall again
const WALL_JUMP_LOCK_S := 0.10       # short lock so player can press back toward wall fast
const PLAYER_W := 20.0
const PLAYER_H := 32.0

# HP + katana melee
const MAX_HP := 5
const MAX_KATANA := 3
const HURT_IFRAME_S := 0.35              # brief invuln after a non-lethal hit (prevents stunlock)
const KATANA_SWING_DURATION_S := 0.32    # full swing length
const KATANA_HIT_START_S := 0.05         # hitbox active window (start)
const KATANA_HIT_END_S := 0.22           # hitbox active window (end)
const KATANA_RANGE := 30.0               # reach in front of player
const KATANA_HALF_H := 18.0              # vertical half-extent of the swing hitbox
const KATANA_VISUAL_SCALE := 1.0         # swing-sprite scale (was 1.5 — smaller reads better)

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
var hp: int = 5
var katana_charges: int = 3
var alive: bool = true
var is_dodging: bool = false
var is_iframe: bool = false
var is_sliding: bool = false
var is_wall_grabbing: bool = false
var is_swinging: bool = false
var swing_start_t: float = -999.0
var swing_hit_done: bool = false       # ensure one player-hit per swing
var hurt_iframe_until: float = 0.0
var jumps_remaining: int = 2   # ground + air; resets to 2 whenever on floor
var dodge_t_end: float = 0.0
var iframe_t_end: float = 0.0
var slide_t_end: float = 0.0
var slide_dir: Vector2 = Vector2.ZERO   # normalized dash direction (8-way), set on each slide
var slide_charged: bool = true          # L2/R2 dash charge — spent on dash, restored on floor/wall contact
var slide_cooldown_until: float = 0.0   # earliest time the charge may refill (base cooldown + any air refresh)
var air_dash_penalty: bool = false      # set when a dash is taken airborne — adds the touch-down delay once
var last_left_tap_t: float = -999.0     # P2 keyboard double-tap-to-dash timing (slot 2 only)
var last_right_tap_t: float = -999.0
var wall_jump_lock_until: float = -999.0
var clash_recoil_until: float = 0.0   # while > now, hold the clash recoil velocity (input can't override)
var throw_anim_until: float = 0.0   # show ATTACK frame for ~220ms after a throw
var death_time: float = -1.0        # set on _die() — drives spin/fade timing
var death_spin_dir: int = 0         # +1 or -1 — matches knockback horizontal direction
var _first_tick_done: bool = false

# === Input action names ===
var input_left: String = ""
var input_right: String = ""
var input_jump: String = ""
var input_aim_up: String = ""
var input_aim_down: String = ""
var input_throw: String = ""
var input_dodge: String = ""
var input_katana: String = ""
var input_slide: String = ""

# === Visual (sprite child added by main.gd) ===
var visual: Sprite2D = null
var pose_texture: Texture2D = null   # 80×16, 5 frames (idle/walk1/walk2/jump/attack)
var idle_texture: Texture2D = null   # 96×16, 6 frames (neutral/inhale/exhale/blink/look-L/look-R)
var current_visual_mode: String = "pose"   # "pose" or "idle"

# === Above-head indicators (built by main.gd) ===
var stash_icons: Array = []    # 5 shuriken icons
var heart_icons: Array = []    # 5 HP hearts
var katana_icons: Array = []   # 3 katana-charge marks
var katana_sprite: Sprite2D = null   # swing visual ("Katana" child)

# 6-frame idle pattern: list of [frame_index, ticks_at_60fps].
# ~2.6s full loop. Each player slot gets a small phase offset so blinks don't sync.
const IDLE_PATTERN: Array = [
	[0, 12],  # neutral
	[1,  8],  # inhale (body bobs up)
	[2, 10],  # exhale (body sinks, knees bend)
	[0, 14],  # neutral
	[3,  4],  # blink — quick
	[0, 18],  # neutral
	[1,  8],  # inhale
	[2, 10],  # exhale
	[0,  8],  # neutral
	[4,  6],  # look left
	[0, 20],  # neutral
	[3,  4],  # blink
	[0, 12],  # neutral
	[5,  6],  # look right
	[0, 16],  # neutral
]

signal stash_changed(slot: int, new_count: int)

func _ready() -> void:
	add_to_group("players")
	var prefix = "p1" if slot == 1 else "p2"
	input_left = prefix + "_left"
	input_right = prefix + "_right"
	input_jump = prefix + "_jump"
	input_aim_up = prefix + "_aim_up"
	input_aim_down = prefix + "_aim_down"
	input_throw = prefix + "_throw"
	input_dodge = prefix + "_dodge"
	input_katana = prefix + "_katana"
	input_slide = prefix + "_slide"
	visual = get_node_or_null("Visual") as Sprite2D
	katana_sprite = get_node_or_null("Katana") as Sprite2D
	print("[PLAYER ", slot, "] _ready. visual=", visual != null)

func _physics_process(delta: float) -> void:
	if not _first_tick_done:
		_first_tick_done = true
		print("[PLAYER ", slot, "] first tick. pos=", position, " on_floor=", is_on_floor())
	# Dead body physics — carries knockback impulse, gravity, friction (no input)
	if not alive:
		velocity.y += GRAVITY * delta
		if velocity.y > PLAYER_TERMINAL_FALL_SPEED:
			velocity.y = PLAYER_TERMINAL_FALL_SPEED
		velocity.x = move_toward(velocity.x, 0.0, 220.0 * delta)
		move_and_slide()
		_check_screen_wrap()
		_update_visual()
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

	# Dash (L2/R2) recharge — only on a real floor/wall contact. A dash taken while
	# airborne pays the SLIDE_AIR_REFRESH_S delay once on touchdown; a ground dash just
	# waits out the base cooldown. The penalty is decided at dash time (below) and
	# applied exactly once here — so the brief floor detachment a dash causes (and any
	# is_on_floor() flicker during fast movement) can't stack delays or stall recharge.
	if (on_floor_now or on_wall_now) and not is_sliding:
		if air_dash_penalty:
			slide_cooldown_until = maxf(slide_cooldown_until, t + SLIDE_AIR_REFRESH_S)
			air_dash_penalty = false
		if t >= slide_cooldown_until:
			slide_charged = true

	# Wall-grab detection (airborne + touching wall + pressing INTO wall)
	is_wall_grabbing = false
	if on_wall_now and move != 0.0:
		if sign(move) == -sign(wall_normal.x):
			is_wall_grabbing = true

	# Facing update
	if move != 0.0 and not is_dodging and not is_sliding:
		facing = int(sign(move))

	# Apply velocity — priority: dodge > slide/dash > clash-recoil > wall-jump-lock > walk
	if is_dodging:
		pass
	elif is_sliding:
		# Directional dash: drive the whole velocity vector (8-way, incl. up/diagonal).
		velocity = slide_dir * SLIDE_SPEED
	elif t < clash_recoil_until:
		pass   # hold the post-clash push-apart; don't let movement input cancel it
	elif t < wall_jump_lock_until:
		pass
	else:
		velocity.x = move * MAX_HSPEED

	# Gravity — skipped during a dash so up/diagonal dashes hold their line
	if not is_sliding:
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

	# Dash request — gamepad L2/R2 for everyone, plus a P2-only keyboard double-tap of
	# A/D (slot 2). Double-tap is scoped to slot 2 so an analog stick can't trigger it.
	var dash_requested: bool = Input.is_action_just_pressed(input_slide)
	if slot == 2:
		if Input.is_action_just_pressed(input_left):
			if t - last_left_tap_t <= DOUBLE_TAP_WINDOW_S:
				dash_requested = true
				last_left_tap_t = -999.0
			else:
				last_left_tap_t = t
		if Input.is_action_just_pressed(input_right):
			if t - last_right_tap_t <= DOUBLE_TAP_WINDOW_S:
				dash_requested = true
				last_right_tap_t = -999.0
			else:
				last_right_tap_t = t

	# Dash — fires toward the held aim (8-way). Spends the charge; in the air you get
	# exactly one until you touch floor/wall again (no infinite climbing).
	if dash_requested and not is_sliding and slide_charged:
		slide_charged = false
		slide_cooldown_until = t + SLIDE_COOLDOWN_S
		air_dash_penalty = not (on_floor_now or on_wall_now)   # only airborne dashes pay the touch-down delay
		_start_slide(_aim_direction(), t)

	# Dodge (dedicated key — cancels slide)
	if Input.is_action_just_pressed(input_dodge):
		if not is_dodging:
			is_sliding = false
			_start_dodge(t)

	# Throw — direction determined by aim_up/aim_down keys held at throw moment
	if Input.is_action_just_pressed(input_throw) and stash > 0:
		var aim_up_held: bool = Input.is_action_pressed(input_aim_up)
		var aim_down_held: bool = Input.is_action_pressed(input_aim_down)
		_throw_shuriken(aim_up_held, aim_down_held)

	# Katana swing — start, then run hit checks while active.
	# Once all 3 charges are spent, the katana is locked out entirely for the rest of
	# the round (respawn refills it); pressing it does nothing until then.
	if Input.is_action_just_pressed(input_katana) and not is_swinging and katana_charges > 0:
		_start_swing(t)
	if is_swinging:
		_process_swing(t)
		if t - swing_start_t >= KATANA_SWING_DURATION_S:
			is_swinging = false

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

func _start_slide(dir: Vector2, t: float) -> void:
	is_sliding = true
	slide_dir = dir
	if dir.x != 0.0:
		facing = int(sign(dir.x))   # only reface on a horizontal component; pure-vertical keeps facing
	slide_t_end = t + SLIDE_DURATION_S
	velocity = dir * SLIDE_SPEED

# Current 8-way aim from the stick/D-pad (move + aim_up/down actions).
# Falls back to the current facing when the stick is neutral, so a dash with no
# direction held still fires forward instead of stalling.
func _aim_direction() -> Vector2:
	var d: Vector2 = Vector2.ZERO
	if Input.is_action_pressed(input_left):
		d.x -= 1.0
	if Input.is_action_pressed(input_right):
		d.x += 1.0
	if Input.is_action_pressed(input_aim_up):
		d.y -= 1.0
	if Input.is_action_pressed(input_aim_down):
		d.y += 1.0
	if d == Vector2.ZERO:
		d.x = facing
	return d.normalized()

func _start_swing(t: float) -> void:
	is_swinging = true
	swing_start_t = t
	swing_hit_done = false
	Audio.play("dodge")   # placeholder swoosh

# Active during the swing's hit window: deflect any flying shuriken in front,
# and deal 1 damage to one enemy (consuming a katana charge, max 3).
func _process_swing(t: float) -> void:
	var elapsed: float = t - swing_start_t
	if elapsed < KATANA_HIT_START_S or elapsed > KATANA_HIT_END_S:
		return
	var hb_center: Vector2 = global_position + Vector2(facing * KATANA_RANGE * 0.5, 0.0)
	var hb_half: Vector2 = Vector2(KATANA_RANGE * 0.5 + 4.0, KATANA_HALF_H)
	# Deflect shurikens in the swing arc (defensive — no charge cost, unlimited)
	for s in get_tree().get_nodes_in_group("shurikens"):
		if not s.stuck and _point_in_box(s.global_position, hb_center, hb_half):
			s.deflect(slot, facing)
	if swing_hit_done:
		return
	# CLASH first: if an enemy is also mid-swing and we sit inside each other's reach
	# this frame, the blades meet — a parry, not a hit. No damage, no charge spent.
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		if _point_in_box(p.global_position, hb_center, hb_half) and _is_clashing_with(p):
			swing_hit_done = true
			Combat.register_clash(self, p)   # fires the freeze + lightning + recoil (de-duped)
			return
	# Strike an enemy (offensive — once per swing, costs a charge)
	if katana_charges > 0:
		for p in get_tree().get_nodes_in_group("players"):
			if p == self or not p.alive:
				continue
			if _point_in_box(p.global_position, hb_center, hb_half):
				if p.take_damage(1, Vector2(facing * 220.0, -80.0)):
					katana_charges -= 1
					swing_hit_done = true
					_spawn_strike_flash(p.global_position)
				break

func _point_in_box(point: Vector2, center: Vector2, half: Vector2) -> bool:
	return absf(point.x - center.x) <= half.x and absf(point.y - center.y) <= half.y

# True when `other` has a LIVE (unresolved) blade out and we sit inside its swing
# reach — i.e. both blades are out and overlapping. Deliberately NOT gated to the
# narrow hit window: two near-simultaneous swings are staggered by a frame or two,
# so requiring both to be in-window on the same frame made most "blade-on-blade"
# meetings register as a strike (charge spent, HP removed) before the clash fired.
# Now any time both blades are out and overlapping it parries cleanly — no charge,
# no HP. (`swing_hit_done` guard: a blade that already struck/parried can't re-clash.)
func _is_clashing_with(other) -> bool:
	if not other.is_swinging or other.swing_hit_done:
		return false
	var ohb_center: Vector2 = other.global_position + Vector2(other.facing * KATANA_RANGE * 0.5, 0.0)
	var ohb_half: Vector2 = Vector2(KATANA_RANGE * 0.5 + 4.0, KATANA_HALF_H)
	return _point_in_box(global_position, ohb_center, ohb_half)

# Called by main.gd on a clash. Pushes us away from the other blade and holds that
# velocity through the freeze + a short recoil so we visibly bounce a hair apart.
# Marks the swing as resolved (no damage) but lets its animation play out.
func apply_clash_recoil(dir_x: int) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	swing_hit_done = true
	velocity.x = float(dir_x) * Combat.clash_recoil_speed
	velocity.y = -Combat.clash_recoil_up
	clash_recoil_until = t + Combat.clash_freeze_duration_s + Combat.clash_recoil_duration_s

# Drop a quick 4-frame spark burst at a successful katana hit.
func _spawn_strike_flash(pos: Vector2) -> void:
	var path: String = "res://sprites/fx/strike_flash_4frame_native_96x24.png"
	if not ResourceLoader.exists(path):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = 4
	fx.fps = 22.0
	fx.texture = load(path)
	fx.position = pos
	fx.scale = Vector2(1.5, 1.5)
	fx.z_index = 50
	get_parent().add_child(fx)

func _throw_shuriken(aim_up: bool = false, aim_down: bool = false) -> void:
	var ShurikenScript: Script = load("res://shuriken.gd")
	var s = Area2D.new()
	s.set_script(ShurikenScript)
	s.thrower_slot = slot
	var v: float = Combat.shuriken_throw_velocity
	var spawn_offset: Vector2
	var vel: Vector2
	if aim_up:
		# Perfectly vertical from player center; gravity in shuriken.gd brings it back down
		spawn_offset = Vector2(0.0, -22.0)
		vel = Vector2(0.0, -v)
	elif aim_down:
		# Perfectly vertical downward from player center
		spawn_offset = Vector2(0.0, 22.0)
		vel = Vector2(0.0, v)
	else:
		# Horizontal (current default)
		spawn_offset = Vector2(facing * 16.0, -4.0)
		vel = Vector2(facing * v, -30.0)
	s.position = global_position + spawn_offset
	s.velocity_v = vel
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
		# Dodge i-frames → catch the shuriken (or reflect if stash full)
		if stash < 5:
			stash += 1
			stash_changed.emit(slot, stash)
			return true
		else:
			shuriken.velocity_v = -shuriken.velocity_v
			shuriken.stuck = false
			return false
	if t < hurt_iframe_until:
		return false   # recently hit — invincible; shuriken passes through
	take_damage(1, shuriken.velocity_v)
	return true

# Apply damage. Returns true if it landed (false if blocked by dodge/hurt i-frames or already dead).
# Death (knockback + score) only happens when HP reaches 0.
func take_damage(amount: int, impact_velocity: Vector2) -> bool:
	if not alive:
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	if is_iframe or t < hurt_iframe_until:
		return false
	hp -= amount
	if hp <= 0:
		_die(impact_velocity)
	else:
		hurt_iframe_until = t + HURT_IFRAME_S
		Audio.play("hit")
		# Small knockback (not the full death throw)
		if impact_velocity.length_squared() > 1.0:
			velocity += impact_velocity.normalized() * 130.0
			velocity.y -= 50.0
	return true

# Called by another player who landed on top of us (head-stomp).
# Returns true if the stomp landed (stomper bounces). Deals 1 damage like other hits.
func hit_by_stomp(_stomper) -> bool:
	if not alive:
		return false
	if is_iframe:
		return false   # dodge i-frames block the stomp
	return take_damage(1, Vector2(0.0, 400.0))   # downward stomp impulse

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

func _die(impact_velocity: Vector2 = Vector2.ZERO) -> void:
	alive = false
	# Carry the projectile's impulse for a dramatic knockback throw.
	if impact_velocity.length_squared() > 1.0:
		var dir: Vector2 = impact_velocity.normalized()
		velocity = dir * 380.0   # base knockback speed
		velocity.y -= 140.0      # extra upward kick → arcing throw, not a straight slide
		death_spin_dir = -1 if impact_velocity.x < 0.0 else 1
	else:
		velocity = Vector2.ZERO
		death_spin_dir = 1
	death_time = Time.get_ticks_msec() / 1000.0
	stash_changed.emit(slot, stash)
	Combat.on_kill(slot)

func respawn(at_pos: Vector2) -> void:
	alive = true
	position = at_pos
	velocity = Vector2.ZERO
	is_dodging = false
	is_iframe = false
	is_sliding = false
	is_wall_grabbing = false
	is_swinging = false
	swing_hit_done = false
	hurt_iframe_until = 0.0
	jumps_remaining = 2
	wall_jump_lock_until = -999.0
	clash_recoil_until = 0.0
	slide_charged = true
	slide_cooldown_until = 0.0
	air_dash_penalty = false
	last_left_tap_t = -999.0
	last_right_tap_t = -999.0
	stash = 3
	hp = MAX_HP
	katana_charges = MAX_KATANA
	facing = 1 if slot == 1 else -1
	death_time = -1.0
	death_spin_dir = 0
	if visual != null:
		visual.rotation = 0.0
		visual.modulate = Color.WHITE
	if katana_sprite != null:
		katana_sprite.visible = false
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
	# === Dead body — tumbling airborne (knockback drama) ===
	if not alive:
		var t_since_death: float = max(0.0, t - death_time)
		_set_visual_mode("pose")
		visual.frame = FRAME_JUMP   # tucked airborne pose suits the tumble
		visual.rotation = death_spin_dir * t_since_death * 11.0   # ~1.75 rev/s spin
		var alpha: float = clamp(1.0 - t_since_death * 0.25, 0.55, 1.0)
		visual.modulate = Color(0.6, 0.35, 0.40, alpha)
		visual.flip_h = false   # facing irrelevant while spinning
		return
	# === Alive: determine state & pick texture mode + frame ===
	var in_action: bool = is_dodging or is_sliding or t < throw_anim_until
	if in_action:
		_set_visual_mode("pose")
		visual.frame = FRAME_ATTACK
	elif is_wall_grabbing or not is_on_floor():
		_set_visual_mode("pose")
		visual.frame = FRAME_JUMP
	elif abs(velocity.x) > 15.0:
		_set_visual_mode("pose")
		visual.frame = FRAME_WALK_1 if (int(t / WALK_CYCLE_S) % 2 == 0) else FRAME_WALK_2
	else:
		# True idle on the ground — play the 6-frame breathing animation
		if idle_texture != null:
			_set_visual_mode("idle")
			visual.frame = _idle_frame_at(t)
		else:
			_set_visual_mode("pose")
			visual.frame = FRAME_IDLE
	# === Modulate: dodge i-frame (yellow) > hurt i-frame (red) > white ===
	if is_iframe:
		var blink: bool = (int(t * 12.0) % 2 == 0)
		visual.modulate = Color(1.8, 1.8, 0.5, 1.0) if blink else Color.WHITE
	elif t < hurt_iframe_until:
		var hblink: bool = (int(t * 16.0) % 2 == 0)
		visual.modulate = Color(2.0, 0.55, 0.55, 1.0) if hblink else Color.WHITE
	else:
		visual.modulate = Color.WHITE
	# === Clear any leftover death rotation; facing flip ===
	visual.rotation = 0.0
	visual.flip_h = (facing < 0)
	# === Katana swing sprite — two poses only: vertical windup → diagonal strike ===
	# The ninja must GRIP THE HANDLE. Each V2 frame draws the grip at a different spot,
	# so we anchor that grip pixel to the hand via `offset`, place the hand just in front
	# of the body, and mirror with a NEGATIVE scale.x (not flip_h) — negative scale flips
	# around the node origin (the anchored handle), keeping the grip put while the blade
	# swings to the facing side. The V2 art is drawn blade-left, so facing right => mirror.
	if katana_sprite != null:
		katana_sprite.visible = is_swinging
		if is_swinging:
			katana_sprite.flip_h = false
			katana_sprite.scale = Vector2(-facing * KATANA_VISUAL_SCALE, KATANA_VISUAL_SCALE)
			katana_sprite.position = Vector2(facing * 7.0, -1.0)   # hand: just in front of the chest
			# V2 frame order: 0 sheathed, 1 drawn, 2 raised, 3 mid_swing, 4 strike_hit, 5 follow_thru.
			# raised(2) = vertical windup (grip pixel ~16,14); follow_thru(5) = forward slash (grip ~25,1).
			# offset = (16 - grip_x, 8 - grip_y) puts that grip pixel on the node origin (= the hand).
			var elapsed: float = t - swing_start_t
			if elapsed >= KATANA_HIT_START_S:
				katana_sprite.frame = 5
				katana_sprite.offset = Vector2(-9.0, 7.0)
			else:
				katana_sprite.frame = 2
				katana_sprite.offset = Vector2(0.0, -6.0)
	# === Above-head indicators ===
	_update_stash_indicator()
	_update_hp_indicator()
	_update_katana_indicator()

# Update above-head stash icons: filled (alpha 1.0) for held shurikens, dim (0.2) for used,
# hidden entirely (alpha 0) when dead.
func _update_stash_indicator() -> void:
	if stash_icons.is_empty():
		return
	var dead_mult: float = 0.0 if not alive else 1.0
	for i in stash_icons.size():
		var icon: Sprite2D = stash_icons[i]
		var has_it: bool = i < stash
		var a: float = (1.0 if has_it else 0.22) * dead_mult
		icon.modulate.a = a

func _update_hp_indicator() -> void:
	if heart_icons.is_empty():
		return
	var dead_mult: float = 0.0 if not alive else 1.0
	for i in heart_icons.size():
		var icon: Sprite2D = heart_icons[i]
		var has_it: bool = i < hp
		icon.modulate.a = (1.0 if has_it else 0.18) * dead_mult

func _update_katana_indicator() -> void:
	if katana_icons.is_empty():
		return
	var dead_mult: float = 0.0 if not alive else 1.0
	for i in katana_icons.size():
		var icon: Sprite2D = katana_icons[i]
		var has_it: bool = i < katana_charges
		icon.modulate.a = (1.0 if has_it else 0.18) * dead_mult

# Swap the Sprite2D's texture + hframes when the visual mode changes.
# No-op if already in the requested mode (avoids per-frame texture re-assignment).
func _set_visual_mode(mode: String) -> void:
	if visual == null or current_visual_mode == mode:
		return
	if mode == "idle" and idle_texture == null:
		return   # graceful fallback: stay in pose mode if idle sheet missing
	current_visual_mode = mode
	if mode == "idle":
		visual.texture = idle_texture
		visual.hframes = 6
	else:
		visual.texture = pose_texture
		visual.hframes = 5
	visual.frame = 0   # reset to avoid out-of-bounds when hframes changes

# Compute which idle frame to display at time t, walking the IDLE_PATTERN.
# Slot offset gives each player a different phase so blinks/glances desynchronize.
func _idle_frame_at(t: float) -> int:
	var total_ticks: int = 0
	for entry in IDLE_PATTERN:
		total_ticks += entry[1]
	if total_ticks <= 0:
		return 0
	var tick: int = (int(t * 60.0) + slot * 19) % total_ticks
	for entry in IDLE_PATTERN:
		if tick < entry[1]:
			return entry[0]
		tick -= entry[1]
	return 0
