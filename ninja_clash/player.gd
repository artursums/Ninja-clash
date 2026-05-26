# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Player CharacterBody2D. Sprite-based ninja silhouette tinted per clan.

extends CharacterBody2D

# === Tuning (data-driven) ===
# Loaded from player_tuning.tres in _ready (or an injected PlayerTuning for tests) so balance is
# editable + testable. Declared as vars (not consts) for that reason; the defaults below match the
# validated prototype, so behaviour is identical when no resource is present. Structural values
# (PLAYER_W/H, sprite frame indices) stay as consts — they are not balance knobs.
const TUNING_PATH := "res://player_tuning.tres"
var tuning: PlayerTuning = null   # inject in tests; otherwise TUNING_PATH is loaded in _ready

var MAX_HSPEED := 158.4
var JUMP_STRENGTH := 480.0
var GRAVITY := 1400.0
var PLAYER_TERMINAL_FALL_SPEED := 320.0
var STOMP_BOUNCE_STRENGTH := 260.0
var SHURIKEN_POGO_BOUNCE := 240.0
var DOWN_THROW_SPEED := 720.0
var SHURIKEN_THROW_RECOIL := 260.0
var DEATH_KNOCKBACK := 90.0
var DEATH_TOPPLE_RATE := 5.0
var DODGE_TOTAL_DURATION_S := 0.30
var SLIDE_SPEED := 400.0
var SLIDE_DURATION_S := 0.20
var SLIDE_MAX_UP_SPEED := 282.8427124746191   # = SLIDE_SPEED·sin45°; recomputed in _apply_tuning()
var SLIDE_COOLDOWN_S := 0.417
var SLIDE_AIR_REFRESH_S := 0.5
var DOUBLE_TAP_WINDOW_S := 0.25
var WALL_JUMP_VSTRENGTH := 540.0
var WALL_JUMP_HKICK := 200.0
var WALL_JUMP_LOCK_S := 0.10
const PLAYER_W := 20.0
const PLAYER_H := 32.0

# HP + katana melee (tuning — see note above)
var MAX_HP := 5
var MAX_KATANA := 3
var HURT_IFRAME_S := 0.35
var KATANA_SWING_DURATION_S := 0.32
var KATANA_COOLDOWN_S := 0.2
var KATANA_HIT_START_S := 0.05
var KATANA_HIT_END_S := 0.22
var KATANA_RANGE := 30.0
var KATANA_HALF_H := 18.0
var KATANA_VISUAL_SCALE := 1.0
var KATANA_HIT_KNOCKBACK := 150.0
var KATANA_HIT_POP := 70.0
var KATANA_HIT_RECOIL_S := 0.10

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
var is_iframe: bool = false
var is_sliding: bool = false
var is_wall_grabbing: bool = false
var is_swinging: bool = false
var is_defending: bool = false         # holding L2/J — katana raised to block front shurikens & strikes
var is_aiming: bool = false            # holding throw → reticle shown, movement frozen (TowerFall)
var aim_dir: Vector2 = Vector2.RIGHT   # current 8-way throw aim while aiming (non-normalized intent)
var _aim_locked_dir: Vector2 = Vector2.ZERO  # snap direction frozen at aim-open / re-aim (no enemy tracking)
var _reticle: Node2D = null            # aim reticle, lazily built
var swing_start_t: float = -999.0
var katana_cooldown_until: float = -999.0   # earliest time the next swing is allowed (0.2 s gate)
var swing_hit_done: bool = false       # ensure one player-hit per swing
var hurt_iframe_until: float = 0.0
var jumps_remaining: int = 1   # single jump (no double jump); resets to 1 whenever on floor
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
var hit_recoil_until: float = 0.0     # while > now, hold the small katana-hit knock-back
var frozen_until: float = 0.0         # while > now, this fighter is in a clash hitstop (per-player, not global)
var throw_anim_until: float = 0.0   # show ATTACK frame for ~220ms after a throw
var death_time: float = -1.0        # set on _die() — drives spin/fade timing
var death_spin_dir: int = 0         # +1 or -1 — matches knockback horizontal direction
var _first_tick_done: bool = false

# === Bot AI (testing) — when is_bot, _bot_think() fills these virtual-input dicts
# each frame and the normal movement code reads them via _held()/_pressed(). ===
var is_bot: bool = false
var bot_difficulty: int = 1         # 1=GENIN (already tough), 2=CHUNIN, 3=JONIN
var _bot_held: Dictionary = {}      # action_name -> held this frame
var _bot_pressed: Dictionary = {}   # action_name -> just-pressed (edge) this frame
var _bot_jitter: float = 0.0        # small per-bot timing offset so two bots don't mirror
var _bot_next_throw_t: float = 0.0
var _bot_next_jump_t: float = 0.0
var _bot_next_dodge_t: float = 0.0
var _bot_next_katana_t: float = 0.0
var _bot_next_dash_t: float = 0.0
var _bot_strafe_dir: int = 1
var _bot_next_strafe_t: float = 0.0
var _bot_rush_until: float = 0.0    # while > now, commit to closing for melee pressure
var _bot_melee_until: float = 0.0     # while > now, committed to a katana duel (close in + timed strikes)
var _bot_melee_cooldown: float = 0.0  # earliest time to begin the next duel — rest between engagements
var _bot_strike_ready_t: float = 0.0  # the deliberate pre-strike pause; don't swing before this
var _bot_throw_dir: Vector2 = Vector2.ZERO  # the bot's intended throw aim (kept clean of strafe noise)
var _bot_threat_id: int = 0           # instance id of the incoming shuriken we're tracking
var _bot_threat_seen_t: float = 0.0   # when we first spotted it — drives human reaction latency

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
var input_defend: String = ""

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

var _spawn_collision_layer: int = 1   # captured at _ready; restored on respawn (a corpse goes to layer 0)
var _corpse_settled: bool = false     # once a dead body lands it freezes here permanently (unmovable)


## Apply data-driven tuning: copy the PlayerTuning resource into the runtime fields. Defaults
## match the resource, so behaviour is unchanged; editing player_tuning.tres re-balances the game.
func _apply_tuning() -> void:
	if tuning == null and ResourceLoader.exists(TUNING_PATH):
		tuning = load(TUNING_PATH)
	if tuning != null:
		MAX_HSPEED = tuning.max_hspeed
		JUMP_STRENGTH = tuning.jump_strength
		GRAVITY = tuning.gravity
		PLAYER_TERMINAL_FALL_SPEED = tuning.terminal_fall_speed
		STOMP_BOUNCE_STRENGTH = tuning.stomp_bounce_strength
		SHURIKEN_POGO_BOUNCE = tuning.shuriken_pogo_bounce
		DOWN_THROW_SPEED = tuning.down_throw_speed
		SHURIKEN_THROW_RECOIL = tuning.shuriken_throw_recoil
		DEATH_KNOCKBACK = tuning.death_knockback
		DEATH_TOPPLE_RATE = tuning.death_topple_rate
		DODGE_TOTAL_DURATION_S = tuning.dodge_total_duration_s
		SLIDE_SPEED = tuning.slide_speed
		SLIDE_DURATION_S = tuning.slide_duration_s
		SLIDE_COOLDOWN_S = tuning.slide_cooldown_s
		SLIDE_AIR_REFRESH_S = tuning.slide_air_refresh_s
		DOUBLE_TAP_WINDOW_S = tuning.double_tap_window_s
		WALL_JUMP_VSTRENGTH = tuning.wall_jump_vstrength
		WALL_JUMP_HKICK = tuning.wall_jump_hkick
		WALL_JUMP_LOCK_S = tuning.wall_jump_lock_s
		MAX_HP = tuning.max_hp
		MAX_KATANA = tuning.max_katana
		HURT_IFRAME_S = tuning.hurt_iframe_s
		KATANA_SWING_DURATION_S = tuning.katana_swing_duration_s
		KATANA_COOLDOWN_S = tuning.katana_cooldown_s
		KATANA_HIT_START_S = tuning.katana_hit_start_s
		KATANA_HIT_END_S = tuning.katana_hit_end_s
		KATANA_RANGE = tuning.katana_range
		KATANA_HALF_H = tuning.katana_half_h
		KATANA_VISUAL_SCALE = tuning.katana_visual_scale
		KATANA_HIT_KNOCKBACK = tuning.katana_hit_knockback
		KATANA_HIT_POP = tuning.katana_hit_pop
		KATANA_HIT_RECOIL_S = tuning.katana_hit_recoil_s
	SLIDE_MAX_UP_SPEED = SLIDE_SPEED * 0.7071067811865476


func _ready() -> void:
	add_to_group("players")
	_apply_tuning()   # data-driven balance: load player_tuning.tres (or use the injected resource)
	_spawn_collision_layer = collision_layer   # remember our solid layer so respawn restores it
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
	input_defend = prefix + "_defend"
	visual = get_node_or_null("Visual") as Sprite2D
	katana_sprite = get_node_or_null("Katana") as Sprite2D
	# Refresh the stash row the instant the count changes (throw/catch/pickup/die/respawn),
	# so it never lags a frame behind a change made from another node's physics step.
	stash_changed.connect(func(_s: int, _n: int): _update_stash_indicator())
	print("[PLAYER ", slot, "] _ready. visual=", visual != null)

func _physics_process(delta: float) -> void:
	if not _first_tick_done:
		_first_tick_done = true
		print("[PLAYER ", slot, "] first tick. pos=", position, " on_floor=", is_on_floor())
	# Dead body physics — carries knockback impulse + gravity until it lands, then FREEZES
	# in place forever. Once settled we stop calling move_and_slide entirely: a kinematic
	# body that isn't driven can't be pushed, so the corpse can never be shoved around.
	if not alive:
		_hide_reticle()
		is_swinging = false   # a corpse isn't swinging (it died mid-swing)
		is_defending = false  # ...nor holding a guard
		if _corpse_settled:
			velocity = Vector2.ZERO
			_update_visual()
			return
		velocity.y += GRAVITY * delta
		if velocity.y > PLAYER_TERMINAL_FALL_SPEED:
			velocity.y = PLAYER_TERMINAL_FALL_SPEED
		velocity.x = move_toward(velocity.x, 0.0, 220.0 * delta)
		move_and_slide()
		if is_on_floor():
			_corpse_settled = true   # landed — lock it down where it fell
			velocity = Vector2.ZERO
		_check_screen_wrap()
		_update_visual()
		return
	# Freeze input during MATCH_INTRO countdown and ROUND_END pause
	if not GameState.is_round_active():
		_hide_reticle()
		is_swinging = false   # don't hold a frozen blade through the round-end / victory pause
		is_defending = false
		velocity.x = 0.0
		# Still apply gravity gently to settle on platforms
		velocity.y = min(velocity.y + 600.0 * delta, 400.0)
		move_and_slide()
		_update_visual()
		return
	var t: float = Time.get_ticks_msec() / 1000.0

	# Clash hitstop — ONLY the two clashing fighters freeze for a beat (main sets frozen_until
	# on a clash). We hold the pose and skip physics/input entirely; bystanders keep playing,
	# so a clash between two players never freezes the rest of a 4-player match. The retained
	# recoil velocity kicks in the instant the freeze ends (clash_recoil_until covers the bounce).
	if t < frozen_until:
		_update_visual()
		return

	# Expire timed windows
	if is_iframe and t >= iframe_t_end:
		is_iframe = false
	if is_sliding and t >= slide_t_end:
		is_sliding = false

	# Bot AI fills its virtual input for this frame (read below via _held/_pressed).
	if is_bot:
		_bot_think(t)

	# Throw — HOLD to aim, RELEASE to fire. A reticle shows the chosen 8-way direction and
	# releasing fires that way; a quick tap is a fast quick-draw. Aiming is purely an
	# overlay: it does NOT touch movement, facing, or wall-grab — you keep running/jumping
	# exactly as normal while you aim. Bots skip the hold and fire instantly with their aim.
	if is_bot:
		if _pressed(input_throw) and stash > 0:
			_throw_shuriken(_throw_aim())
	else:
		if not is_aiming and _pressed(input_throw) and stash > 0 and not _held(input_defend):
			is_aiming = true
			aim_dir = _throw_aim()               # capture on press (covers instant quick-draws)
			_relock_aim()                        # lock the assist onto whoever's in the wedge NOW
		if is_aiming:
			if _held(input_throw):
				var new_aim: Vector2 = _throw_aim()
				if new_aim != aim_dir:           # the player re-aimed → re-lock for the new octant
					aim_dir = new_aim
					_relock_aim()
				# (steady aim → the lock stays frozen; it does NOT follow the foe's movement)
			else:
				# Released → fire the RETAINED, LOCKED aim. Not recomputed here, so letting go of
				# the direction a frame early (or with the button) still throws where you aimed.
				is_aiming = false
				if stash > 0:
					_throw_shuriken(aim_dir)
	_update_aim_reticle()

	# Movement input
	var move: float = 0.0
	if _held(input_left):
		move -= 1.0
	if _held(input_right):
		move += 1.0

	# Physics queries
	var on_floor_now := is_on_floor()
	var on_wall_now := is_on_wall() and not on_floor_now
	var wall_normal: Vector2 = get_wall_normal() if on_wall_now else Vector2.ZERO

	# Refresh jumps whenever touching floor — forgiving timing (no transition required)
	if on_floor_now:
		jumps_remaining = 1

	# Dash (L2/R2) recharge. Landing on the FLOOR after an air dash (the R2 up-boost) resets it
	# INSTANTLY — no leftover cooldown, no penalty — so you can boost again the moment you touch
	# down. A ground-to-ground re-dash still waits out the base cooldown (so the dodge can't be
	# mashed along the floor), and a wall contact keeps the old air-penalty timing.
	if not is_sliding:
		if on_floor_now and air_dash_penalty:
			slide_charged = true              # just landed from an air dash → reset immediately
			slide_cooldown_until = 0.0
			air_dash_penalty = false
		elif on_floor_now or on_wall_now:
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

	# Facing update — follows movement as normal (aiming never overrides it)
	if move != 0.0 and not is_sliding:
		facing = int(sign(move))

	# Defense (guard) — hold L2/J to plant the katana in front. Blocks front shurikens and
	# katana strikes (see _blocks_incoming); roots you in place; gives no ammo (vs dodge, which
	# catches). Mutually exclusive with dash / aim / swing / wall-grab. You may still turn to
	# face the incoming threat (facing follows movement above), but you cannot move.
	is_defending = _held(input_defend) and not is_swinging and not is_sliding \
		and not is_aiming and not is_wall_grabbing

	# Apply velocity — priority: dash-dodge > guard > clash-recoil > wall-jump-lock > walk.
	# Aiming does NOT appear here: you run while you aim, same as ever.
	if is_sliding:
		# Directional dash-dodge: drive the whole velocity vector (8-way, incl. up/diagonal).
		# Upward speed is capped (see _dash_velocity) so a straight-up dash matches a diagonal's height.
		velocity = _dash_velocity()
	elif is_defending:
		velocity.x = 0.0   # rooted while guarding — committal (gravity still applies below)
	elif t < clash_recoil_until:
		pass   # hold the post-clash push-apart; don't let movement input cancel it
	elif t < hit_recoil_until:
		pass   # hold the brief katana-hit knock-back so the bump reads
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

	# Jump: wall-jump (only when airborne and on wall) > single ground jump via jumps_remaining
	if _pressed(input_jump):
		if on_wall_now and not on_floor_now:
			velocity.y = -WALL_JUMP_VSTRENGTH
			velocity.x = wall_normal.x * WALL_JUMP_HKICK
			facing = int(sign(wall_normal.x))
			wall_jump_lock_until = t + WALL_JUMP_LOCK_S
			is_wall_grabbing = false
			jumps_remaining = 0  # the wall jump IS the jump — no bonus air jump (no double jump)
		elif jumps_remaining > 0:
			velocity.y = -JUMP_STRENGTH   # single jump, always full strength (coyote case included)
			jumps_remaining -= 1

	# Dash-dodge request — ONE move on L2, R2 AND Circle (slide + dodge are now unified),
	# plus a P2-only keyboard double-tap of A/D. Double-tap is scoped to slot 2 so an
	# analog stick can't trigger it.
	var dash_requested: bool = not is_defending and (_pressed(input_slide) or _pressed(input_dodge))
	if slot == 2:
		if _pressed(input_left):
			if t - last_left_tap_t <= DOUBLE_TAP_WINDOW_S:
				dash_requested = true
				last_left_tap_t = -999.0
			else:
				last_left_tap_t = t
		if _pressed(input_right):
			if t - last_right_tap_t <= DOUBLE_TAP_WINDOW_S:
				dash_requested = true
				last_right_tap_t = -999.0
			else:
				last_right_tap_t = t

	# Dash-dodge — fires toward the held aim (8-way) with brief i-frames that catch an
	# incoming shuriken. Spends the charge; in the air you get exactly one until you touch
	# floor/wall again (no infinite climbing). The cooldown forces timing per shuriken.
	if dash_requested and not is_sliding and not is_defending and slide_charged:
		slide_charged = false
		slide_cooldown_until = t + SLIDE_COOLDOWN_S
		air_dash_penalty = not (on_floor_now or on_wall_now)   # only airborne dashes pay the touch-down delay
		_start_slide(_aim_direction(), t)

	# Katana swing — start, then run hit checks while active.
	# Once all 3 charges are spent, the katana is locked out entirely for the rest of
	# the round (respawn refills it); pressing it does nothing until then.
	if _pressed(input_katana) and not is_swinging and not is_defending and katana_charges > 0 and t >= katana_cooldown_until:
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

# The dash IS the dodge: a directional burst (8-way) with brief invincibility frames that
# catch an incoming shuriken. L2 / R2 / Circle all trigger this one move.
func _start_slide(dir: Vector2, t: float) -> void:
	is_sliding = true
	slide_dir = dir
	is_iframe = true
	iframe_t_end = t + Combat.dodge_iframe_duration_s
	if dir.x != 0.0:
		facing = int(sign(dir.x))   # only reface on a horizontal component; pure-vertical keeps facing
	slide_t_end = t + SLIDE_DURATION_S
	velocity = _dash_velocity()
	Audio.play("dodge")

# Dash burst velocity for the current slide_dir, with the upward component capped so a
# straight-up dash can't out-climb a diagonal-up one — both reach the same peak height.
func _dash_velocity() -> Vector2:
	var v: Vector2 = slide_dir * SLIDE_SPEED
	if v.y < -SLIDE_MAX_UP_SPEED:
		v.y = -SLIDE_MAX_UP_SPEED
	return v

# Current 8-way aim from the stick/D-pad (move + aim_up/down actions).
# Falls back to the current facing when the stick is neutral, so a dash with no
# direction held still fires forward instead of stalling.
func _aim_direction() -> Vector2:
	var d: Vector2 = Vector2.ZERO
	if _held(input_left):
		d.x -= 1.0
	if _held(input_right):
		d.x += 1.0
	if _held(input_aim_up):
		d.y -= 1.0
	if _held(input_aim_down):
		d.y += 1.0
	if d == Vector2.ZERO:
		d.x = facing
	return d.normalized()

# Throw aim. Humans get full 8-way from held move + aim_up/down (so up/down + a side gives
# a diagonal). The bot uses its own pre-chosen aim so incidental strafing never skews a
# straight horizontal or vertical throw. Returns a NON-normalized intent vector
# (-1/0/+1 per axis); _throw_shuriken interprets the shape.
func _throw_aim() -> Vector2:
	if is_bot:
		return _bot_throw_dir
	var hx: int = 0
	if _held(input_left):
		hx -= 1
	if _held(input_right):
		hx += 1
	var vy: int = 0
	if _held(input_aim_up):
		vy -= 1
	if _held(input_aim_down):
		vy += 1
	if vy != 0 and hx != 0:
		return Vector2(hx, vy)        # diagonal (up/down-left/right)
	if vy != 0:
		return Vector2(0, vy)         # straight up / down
	return Vector2(facing, 0)         # horizontal, in the way we face

# === Target-snap aim assist ===
# A fixed 8-way direction rarely lines up with a foe — especially the 45° diagonals — so
# throws miss. If a living enemy sits within this half-angle of the aimed direction (i.e.
# inside that octant's wedge), we redirect the throw EXACTLY at them. This is the aiming aid
# that makes diagonal throws actually connect; the throw's in-flight steering then holds it.
const AIM_SNAP_HALF_ANGLE_DEG := 26.0   # ~the 45° octant (±22.5°), plus a little forgiveness
const AIM_SNAP_RANGE := 640.0           # whole-arena reach — if they're in your wedge, lock on

# Given the raw aim direction, return the direction to the nearest enemy inside the aimed
# wedge that we have a CLEAR SHOT to, or the original direction if none qualifies. A foe
# behind a wall or platform is skipped — snapping at them would just bury the blade in the
# obstacle. Result is captured once at aim-open via _relock_aim (it does not track movement).
func _aim_assist_dir(base_dir: Vector2) -> Vector2:
	if base_dir == Vector2.ZERO:
		return base_dir
	var base_angle: float = base_dir.angle()
	var best: Node = null
	var best_d: float = AIM_SNAP_RANGE
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		var to_p: Vector2 = p.global_position - global_position
		var d: float = to_p.length()
		if d < 8.0 or d > AIM_SNAP_RANGE:
			continue
		if rad_to_deg(absf(wrapf(to_p.angle() - base_angle, -PI, PI))) > AIM_SNAP_HALF_ANGLE_DEG:
			continue
		if not _has_clear_shot(p):   # a wall/platform is in the way → don't snap into it
			continue
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		return base_dir
	return (best.global_position - global_position).normalized()

# True if nothing solid (a wall/platform StaticBody2D) sits between us and the target.
func _has_clear_shot(target: Node2D) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, target.global_position)
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or not (hit.collider is StaticBody2D)

# Freeze the assist onto whoever is in the aimed wedge RIGHT NOW (clear shot only). Called
# at aim-open and whenever the player re-aims — never per-frame, so the lock can't chase the foe.
func _relock_aim() -> void:
	var d: Vector2 = aim_dir
	if d == Vector2.ZERO:
		d = Vector2(facing, 0)
	_aim_locked_dir = _aim_assist_dir(d.normalized())

# === Aim reticle (TowerFall feedback) ===
# A clan-colored chevron shown in the current 8-way aim direction while throw is held.
const RETICLE_DIST := 24.0   # px from player center to the reticle arrowhead

func _ensure_reticle() -> void:
	if _reticle != null:
		return
	_reticle = Node2D.new()
	_reticle.z_index = 70
	_reticle.visible = false
	add_child(_reticle)
	var col: Color = Color(GameState.get_clan(slot).color)
	# Arrowhead chevron pointing +x (local); rotated to the aim each frame.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-4, -5), Vector2(8, 0), Vector2(-4, 5), Vector2(0, 0)])
	var outline := Polygon2D.new()                  # dark backing for contrast
	outline.polygon = pts
	outline.color = Color(0.04, 0.03, 0.07, 0.85)
	outline.scale = Vector2(1.35, 1.35)
	_reticle.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(col.r, col.g, col.b, 0.95)
	_reticle.add_child(fill)

# Show the reticle in the current aim direction while aiming; hide otherwise.
func _update_aim_reticle() -> void:
	if not is_aiming:
		if _reticle != null:
			_reticle.visible = false
		return
	_ensure_reticle()
	# Show the LOCKED direction (frozen at aim-open / re-aim) so the reticle points where the
	# throw will actually go and does NOT drift after the foe as they move.
	var dir: Vector2 = _aim_locked_dir
	if dir == Vector2.ZERO:
		dir = aim_dir.normalized() if aim_dir != Vector2.ZERO else Vector2(facing, 0)
	_reticle.position = dir * RETICLE_DIST
	_reticle.rotation = dir.angle()
	_reticle.visible = true

func _hide_reticle() -> void:
	is_aiming = false
	if _reticle != null:
		_reticle.visible = false

# === Input source: bot virtual input, else the captured per-tick intent (ADR-0001) ===
# Humans read the PlayerInput router's snapshot — NOT the live device — so the simulation is
# driven by an intent that a future network layer could supply instead. Bots already inject
# virtual intent (_bot_held/_bot_pressed), so they were always device-independent.
func _held(action: String) -> bool:
	if is_bot:
		return _bot_held.get(action, false)
	return PlayerInput.held(action)

func _pressed(action: String) -> bool:
	if is_bot:
		return _bot_pressed.get(action, false)
	return PlayerInput.pressed(action)

# === Bot AI ===
# A genuinely competent fighter, tiered by bot_difficulty (1 GENIN / 2 CHUNIN / 3 JONIN).
# Even GENIN dodges most incoming shurikens (the hardest thing to deal with) — the tiers
# scale dodge reliability, fire rate, spacing tightness and aggression. Tap actions are
# edge-set via _bot_pressed; per-action cooldowns stop it machine-gunning.
func _bot_think(t: float) -> void:
	_bot_held.clear()
	_bot_pressed.clear()

	var lvl: int = clampi(bot_difficulty, 1, 3)
	# Per-tier knobs (index 0 unused). Dodge isn't a guaranteed escape — if it were,
	# two equal bots would dodge everything and never resolve — so even JONIN lets ~20%
	# of throws through; the tiers scale defence, fire rate, spacing and aggression.
	var dodge_chance: float = [0.0, 0.45, 0.63, 0.80][lvl]   # chance to read an incoming shuriken
	var dodge_range: float  = [0.0, 82.0, 98.0, 116.0][lvl]  # how far out it reacts (timed to catch)
	var throw_cd: float     = [0.0, 0.75, 0.52, 0.34][lvl]   # min gap between throws
	var jump_react_h: float = [0.0, 72.0, 58.0, 46.0][lvl]   # eagerness to chase a higher foe
	# Chasing dialed back ~15% (the ×1.15 spacing) so the bot sits further out and crowds the
	# player less — more room to breathe. Rush frequency is likewise trimmed 15% below.
	var near_range: float   = [0.0, 70.0, 62.0, 54.0][lvl] * 1.15   # back off sooner (keep more distance)
	var far_range: float    = [0.0, 220.0, 195.0, 172.0][lvl] * 1.15# only close when the player is further out
	var hop_chance: float   = [0.0, 0.010, 0.014, 0.020][lvl]
	var rush_chance: float  = [0.0, 0.004, 0.007, 0.011][lvl] * 0.85  # 15% fewer pressure rushes
	# Katana-duel knobs. The bot picks its moment, closes, then HOLDS a beat before each
	# cut — deliberate pacing, never a flurry. Pauses also give the human room to read it.
	var melee_commit_chance: float = [0.0, 0.006, 0.009, 0.013][lvl] * 0.85 # 15% less eager to start a duel (throws more instead)
	var melee_windup: float        = [0.0, 0.50,  0.42,  0.34][lvl]  # pause before a strike (the "stare-down")
	var melee_recovery: float      = [0.0, 1.10,  0.90,  0.72][lvl]  # rest after a strike — no spamming
	# Human-like movement & defence knobs.
	var deflect_chance: float   = [0.0, 0.40,  0.55,  0.70][lvl]  # parry an incoming shuriken with the blade
	var dash_close_chance: float= [0.0, 0.020, 0.032, 0.048][lvl] # burst-dash to close a big gap
	var dash_air_chance: float  = [0.0, 0.030, 0.050, 0.080][lvl] # air-dash mid-jump toward the foe
	# Human-feel knobs (research: "start from perfect play, then add reaction lag + errors").
	var reaction_s: float       = [0.0, 0.24,  0.17,  0.11][lvl]  # lag before it answers a NEW threat (point-blank throws beat it)
	var pickup_range: float     = [0.0, 120.0, 150.0, 180.0][lvl] # how far it detours to grab a loose blade (stash<5)

	var enemy: Node = _bot_nearest_enemy()
	if enemy == null:
		return
	var dx: float = enemy.global_position.x - global_position.x
	var dy: float = enemy.global_position.y - global_position.y
	var adx: float = absf(dx)
	var ady: float = absf(dy)
	var to_enemy: int = 1 if dx >= 0.0 else -1

	# 1) Survive an incoming shuriken — like a human, EITHER slash it out of the air with
	# the katana OR dodge it (i-frames catch it). Parry first when it's at blade range and
	# we still have a charge; otherwise dodge.
	var incoming = _bot_incoming_shuriken(dodge_range)
	# Human reaction lag: start a clock when a new threat first enters our awareness and
	# only answer it once we've "had eyes on it" for reaction_s. A throw that arrives faster
	# than that (point-blank or very fast) lands — exactly the reward for an aggressive human.
	if incoming != null:
		var iid: int = incoming.get_instance_id()
		if iid != _bot_threat_id:
			_bot_threat_id = iid
			_bot_threat_seen_t = t
	else:
		_bot_threat_id = 0
	var reacted: bool = incoming != null and (t - _bot_threat_seen_t) >= reaction_s
	if reacted and t >= _bot_next_dodge_t:
		var ix: float = incoming.global_position.x - global_position.x
		var iy: float = incoming.global_position.y - global_position.y
		var can_parry: bool = katana_charges > 0 and not is_swinging and t >= _bot_next_katana_t
		# Always TRY to cut an incoming shuriken out of the air — deflecting costs no charge,
		# and when we're out of shurikens the blade is the ONLY answer, so make it near-certain.
		var parry_chance: float = 0.97 if stash <= 0 else deflect_chance
		if can_parry and absf(ix) <= 58.0 and absf(iy) < 22.0 and randf() < parry_chance:
			facing = 1 if ix >= 0.0 else -1     # face the projectile and cut it down
			_bot_pressed[input_katana] = true
			_bot_next_katana_t = t + randf_range(0.18, 0.34)
			return
		if randf() < dodge_chance:
			_bot_pressed[input_dodge] = true
			_bot_next_dodge_t = t + DODGE_TOTAL_DURATION_S + 0.04
			return
		_bot_next_dodge_t = t + 0.22   # missed the read → brief vulnerable window

	# 1b) Defend against the foe's BLADE: if they're swinging at us within reach, swing too
	# so the katanas CLASH (lightning, no damage) instead of eating the cut. Reactive parry.
	if katana_charges > 0 and not is_swinging and t >= _bot_next_katana_t and enemy.is_swinging:
		if adx < 34.0 and ady < 18.0:
			facing = to_enemy
			_bot_pressed[input_katana] = true
			_bot_next_katana_t = t + randf_range(0.28, 0.45)
			return

	# 2) Out of shurikens → MIX re-arming with the blade. Go grab a dropped shuriken when it's
	# worth it (close, or lying on the way to the foe — a free re-arm on the approach), AND cut
	# the foe if they wander into reach while we fetch. When nothing's worth grabbing, fall
	# through to §3 and hunt them down with the katana. The two blend frame-to-frame; we never
	# freeze and never just turn our back on a crowding foe.
	var fetch_target = _bot_nearest_stuck_shuriken() if stash <= 0 else null
	var scavenge_ok: bool = false
	if fetch_target != null:
		var bdx: float = fetch_target.global_position.x - global_position.x
		var bdist: float = global_position.distance_to(fetch_target.global_position)
		var blade_toward_foe: bool = (bdx >= 0.0) == (dx >= 0.0)
		# A blade on the way to the foe is a free grab at any sane range; one the OTHER way
		# only when the foe isn't crowding us (don't turn your back into a cut).
		scavenge_ok = bdist <= 240.0 and (blade_toward_foe or adx > 80.0)
	if scavenge_ok:
		var sdx: float = fetch_target.global_position.x - global_position.x
		var sdy: float = fetch_target.global_position.y - global_position.y
		var to_sh: int = 1 if sdx >= 0.0 else -1
		var acted: bool = false
		if absf(sdx) > 6.0:
			if is_on_floor() and t >= _bot_next_jump_t and (sdy < -28.0 or not _bot_ground_ahead(to_sh)):
				_bot_pressed[input_jump] = true
				_bot_next_jump_t = t + randf_range(0.4, 0.7)
			_bot_held[input_left if to_sh < 0 else input_right] = true
			acted = true
		elif sdy < -28.0 and is_on_floor() and t >= _bot_next_jump_t:
			_bot_pressed[input_jump] = true
			_bot_next_jump_t = t + 0.5
			acted = true
		# MIX: cut the foe if they're in blade reach while we scavenge.
		if adx < 44.0 and ady < 26.0 and katana_charges > 0 and t >= _bot_next_katana_t:
			facing = to_enemy
			_bot_pressed[input_katana] = true
			_bot_next_katana_t = t + melee_recovery
			acted = true
		if acted:
			return
		# blade unreachable AND foe out of reach → fall through to the hunt (never freeze)
	var ammo_starved: bool = stash <= 0   # out of shurikens → commit to the blade below

	# 3) Either commit to a KATANA DUEL or hold ranged spacing.
	# Normal duels are deliberate: pick a moment (only when roughly level), close to blade
	# range, then PLANT and hold a beat before each cut. But when ammo_starved with nothing
	# to scavenge, the bot goes ALL-IN on the blade — it HUNTS the player across the whole
	# arena (heights too) and swings as fast as it can. The katana becomes its win condition.
	# Out of shurikens = commit to the blade: hunt the foe down, swing when we have a charge,
	# and head-stomp when we don't. (Pressing the katana with no charge is a harmless no-op.)
	var must_melee: bool = ammo_starved
	var level_for_melee: bool = ady < 45.0
	# Proximity engage: whenever the foe is at blade range and we have a charge, FIGHT — don't
	# wander off. Makes "they get close → it duels" reliable instead of a random commit roll.
	var enemy_in_blade_range: bool = adx < 46.0 and ady < 28.0
	if katana_charges > 0 and level_for_melee and t >= _bot_melee_cooldown and randf() < melee_commit_chance:
		_bot_melee_until = t + randf_range(1.6, 2.6)
		_bot_melee_cooldown = t + randf_range(3.2, 5.0)   # rest before the next engagement
	var in_melee: bool = must_melee or (katana_charges > 0 and enemy_in_blade_range) \
		or (katana_charges > 0 and level_for_melee and t < _bot_melee_until)

	var desired: int = 0
	if in_melee:
		if adx > 30.0:
			desired = to_enemy                      # close to blade range
			# All-in skips the stare-down — just relentless pressure.
			_bot_strike_ready_t = t + (0.0 if must_melee else melee_windup)
		else:
			# In blade range — never freeze: micro-dance in and out around strike range so
			# the bot is always moving (and harder to read), while facing the foe.
			facing = to_enemy
			desired = -to_enemy if adx < 24.0 else to_enemy
			if t >= _bot_strike_ready_t and t >= _bot_next_katana_t and ady < 16.0:
				_bot_pressed[input_katana] = true
				var recov: float = (melee_recovery * 0.5) if must_melee else melee_recovery
				_bot_next_katana_t = t + recov + randf_range(0.0, 0.25)
				_bot_strike_ready_t = _bot_next_katana_t + randf_range(0.05, 0.2)
				if not must_melee and randf() < 0.45:
					_bot_melee_until = 0.0          # sometimes break off after a strike (varies spacing)
		# All-in chases vertically too — jump up to the player's platform to reach them.
		if must_melee and dy < -28.0 and is_on_floor() and t >= _bot_next_jump_t:
			_bot_pressed[input_jump] = true
			_bot_next_jump_t = t + randf_range(0.4, 0.7)
		# (No deliberate head-stomp — the bot relies on shurikens + the katana. An incidental
		# stomp can still happen via _check_headstomp if it just lands on the foe in play.)
	else:
		# Ranged spacing: grab loose blades when safe, else hold a pocket / strafe / rush.
		if t >= _bot_rush_until and randf() < rush_chance:
			_bot_rush_until = t + randf_range(0.6, 1.1)
		# Opportunistic pickup — TowerFall players hoard arrows. If a loose blade is nearby,
		# we have room (stash<5) and nothing's incoming, drift over and scoop it up first.
		var grab = _bot_nearest_stuck_shuriken() if (stash < 5 and incoming == null) else null
		var grab_close: bool = grab != null and global_position.distance_to(grab.global_position) <= pickup_range
		if grab_close:
			var gdx: float = grab.global_position.x - global_position.x
			var gdy: float = grab.global_position.y - global_position.y
			desired = 0 if absf(gdx) < 6.0 else (1 if gdx > 0.0 else -1)
			if gdy < -28.0 and is_on_floor() and t >= _bot_next_jump_t:
				_bot_pressed[input_jump] = true        # hop up to a higher blade
				_bot_next_jump_t = t + randf_range(0.4, 0.7)
		elif t < _bot_rush_until:
			desired = to_enemy            # rushing — close into katana/stomp range
		elif adx > far_range:
			desired = to_enemy
		elif adx < near_range:
			desired = -to_enemy
		else:
			if t >= _bot_next_strafe_t:
				_bot_strafe_dir = -_bot_strafe_dir
				_bot_next_strafe_t = t + randf_range(0.35, 0.9)
			desired = _bot_strafe_dir

	# 4) Aim vertically toward the foe (drives up/down throws).
	if dy < -42.0:
		_bot_held[input_aim_up] = true
	elif dy > 42.0:
		_bot_held[input_aim_down] = true

	# 5) Throw — full 8-way aim toward the foe (incl. diagonals), snapped to the nearest
	# of 8 directions; the shuriken's aim-assist trims the rest. Set explicitly via
	# _bot_throw_dir so incidental strafing never skews it. Not while in a blade duel.
	var can_throw: bool = adx < 420.0 and ady < 340.0
	if not in_melee and stash > 0 and t >= _bot_next_throw_t and can_throw:
		# Lead a moving target: aim where the foe will be in ~0.2s, not where they stand now.
		var ev: Vector2 = enemy.velocity
		var pdx: float = dx + ev.x * 0.20
		var pdy: float = dy + ev.y * 0.20
		var hx: int = (1 if pdx > 0.0 else -1) if absf(pdx) > 26.0 else 0
		var vy: int = (1 if pdy > 0.0 else -1) if absf(pdy) > 26.0 else 0
		if hx == 0 and vy == 0:
			hx = to_enemy
		_bot_throw_dir = Vector2(hx, vy)
		_bot_pressed[input_throw] = true
		_bot_next_throw_t = t + throw_cd + randf_range(0.0, 0.16) + _bot_jitter

	# Edge guard: a pro never strolls off a platform into the chasm. If the chosen step
	# has no ground ahead, either HOP across the gap (when chasing the foe that way) or
	# turn back; if both sides are edges, hold still.
	if is_on_floor() and desired != 0 and not _bot_ground_ahead(desired):
		if desired == to_enemy and t >= _bot_next_jump_t:
			_bot_pressed[input_jump] = true            # leap the gap toward the foe (air control carries across)
			_bot_next_jump_t = t + randf_range(0.4, 0.8)
		else:
			desired = -desired                          # back away from the ledge
			if not _bot_ground_ahead(desired):
				desired = 0                             # both sides drop off — stay put

	# Wall play: airborne against a wall, USE it. If the foe is above, hug the wall and
	# wall-jump in a tight rhythm to CLIMB it fast (TowerFall zig-zag); otherwise kick off
	# to rejoin the fight. Never just cling. Overrides the horizontal hold so the climb sticks.
	var want_height: bool = dy < -50.0
	if is_on_wall() and not is_on_floor():
		var wn: Vector2 = get_wall_normal()
		var into_wall: int = -1 if wn.x > 0.0 else 1   # press opposite the wall's outward normal
		if want_height:
			desired = into_wall                         # cling & scale toward the higher foe
			if t >= _bot_next_jump_t:
				_bot_pressed[input_jump] = true
				_bot_next_jump_t = t + randf_range(0.12, 0.22)
		elif t >= _bot_next_jump_t:
			_bot_pressed[input_jump] = true             # kick off the wall
			_bot_next_jump_t = t + randf_range(0.2, 0.4)

	# Apply chosen horizontal movement.
	if desired < 0:
		_bot_held[input_left] = true
	elif desired > 0:
		_bot_held[input_right] = true

	# 7) Jumps on the ground / in the air (wall-jumps are handled in the wall block above).
	if t >= _bot_next_jump_t:
		if is_on_floor() and (dy < -jump_react_h or randf() < hop_chance):
			_bot_pressed[input_jump] = true
			_bot_next_jump_t = t + randf_range(0.45, 1.0)

	# 8) Dashes — close distance and add unpredictability, ON THE GROUND and IN THE AIR.
	# Mixing an air-dash after a jump (dash-jump) is how a human covers ground fast; we
	# never queue a dash on the same frame as a jump (the dash would swallow the jump),
	# and never ground-dash off a ledge.
	if slide_charged and t >= _bot_next_dash_t and not _bot_pressed.get(input_jump, false):
		var want_dash: bool = false
		if is_on_floor():
			# burst toward a distant foe, but only if there's ground to land the dash on
			if desired == to_enemy and adx > far_range and _bot_ground_ahead(to_enemy):
				want_dash = randf() < dash_close_chance
		else:
			# air-dash mid-jump: chase across a gap, OR burst diagonally UP toward a higher
			# foe (aim_up is held, so the dash fires up-diagonal — the jump+dash climb).
			var chasing: bool = desired == to_enemy and adx > 50.0
			if (chasing or want_height) and randf() < dash_air_chance:
				want_dash = true
		if want_dash:
			_bot_pressed[input_slide] = true
			_bot_next_dash_t = t + randf_range(0.8, 1.5)

# Is there solid ground just ahead in `dir` (so the bot can step that way without
# walking off into the chasm)? Casts a short ray down past foot level a little ahead.
func _bot_ground_ahead(dir: int) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(dir * (PLAYER_W * 0.5 + 6.0), PLAYER_H * 0.5 - 4.0)
	var to: Vector2 = from + Vector2(0.0, 16.0)
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	return not hit.is_empty() and hit.collider is StaticBody2D

func _bot_nearest_enemy() -> Node:
	var enemy: Node = null
	var best_d: float = 1e9
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			enemy = p
	return enemy

# Nearest non-stuck enemy shuriken actually closing on us within `range_px` (or null).
func _bot_incoming_shuriken(range_px: float):
	var best = null
	var best_d: float = range_px
	for s in get_tree().get_nodes_in_group("shurikens"):
		if s.stuck or s.thrower_slot == slot:
			continue
		var to_me: Vector2 = global_position - s.global_position
		var d: float = to_me.length()
		if d > best_d:
			continue
		if s.velocity_v.dot(to_me) > 0.0:   # heading toward us
			best_d = d
			best = s
	return best

func _bot_threatened(range_px: float) -> bool:
	return _bot_incoming_shuriken(range_px) != null

func _bot_nearest_stuck_shuriken():
	var best = null
	var best_d: float = 1e9
	for s in get_tree().get_nodes_in_group("shurikens"):
		if not s.stuck:
			continue
		var d: float = global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best

func _start_swing(t: float) -> void:
	is_swinging = true
	swing_start_t = t
	swing_hit_done = false
	katana_cooldown_until = t + KATANA_SWING_DURATION_S + KATANA_COOLDOWN_S   # 0.2 s recovery after the swing finishes (0.52 s total swing-to-swing)
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
				if p.take_damage(1, Vector2(facing * 220.0, -80.0), slot):
					katana_charges -= 1
					_update_katana_indicator()   # reflect the spent charge this instant, no frame lag
					swing_hit_done = true
					_spawn_strike_flash(p.global_position)
					if p.alive and p.has_method("apply_hit_recoil"):
						p.apply_hit_recoil(facing)   # small bump on a survivor — sells the hit
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

# Small, brief knock-back when a katana hit lands on a SURVIVING foe — sells the impact, then
# they recover. Held over a short window (movement chain) so their input can't cancel it.
func apply_hit_recoil(push_dir: int) -> void:
	velocity.x = float(push_dir) * KATANA_HIT_KNOCKBACK
	velocity.y = minf(velocity.y, -KATANA_HIT_POP)
	hit_recoil_until = Time.get_ticks_msec() / 1000.0 + KATANA_HIT_RECOIL_S

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

# aim is a NON-normalized intent vector (per-axis -1/0/+1) from _throw_aim():
#   (±1, 0) horizontal · (0, ±1) vertical · (±1, ±1) diagonal.
func _throw_shuriken(aim: Vector2) -> void:
	var ShurikenScript: Script = load("res://shuriken.gd")
	var s = Area2D.new()
	s.set_script(ShurikenScript)
	s.thrower_slot = slot
	var v: float = Combat.shuriken_throw_velocity
	var spawn_offset: Vector2
	var vel: Vector2
	if aim.x != 0.0 and aim.y != 0.0:
		# Diagonal — fly straight along the aim; gravity arcs it down over distance.
		var dir: Vector2 = aim.normalized()
		vel = dir * v
		spawn_offset = dir * 18.0
		facing = int(signf(aim.x))   # face the throw
	elif aim.y != 0.0:
		# Pure vertical from player center
		var sgn: float = signf(aim.y)
		spawn_offset = Vector2(0.0, sgn * 22.0)
		vel = Vector2(0.0, sgn * v)
	else:
		# Horizontal with a slight initial lift (the original feel)
		var hdir: int = int(signf(aim.x)) if aim.x != 0.0 else facing
		spawn_offset = Vector2(hdir * 16.0, -4.0)
		vel = Vector2(hdir * v, -30.0)
		facing = hdir
	# Target-snap (humans only): fire along the direction LOCKED at aim-open (a foe in the
	# wedge with a clear shot), not a fresh re-aim — so the throw goes where the reticle showed,
	# not where the foe has since moved. Bots keep their own aim (leading + in-flight assist).
	if not is_bot and _aim_locked_dir != Vector2.ZERO and not _aim_locked_dir.is_equal_approx(aim.normalized()):
		vel = _aim_locked_dir * v
		spawn_offset = _aim_locked_dir * 16.0
		if _aim_locked_dir.x != 0.0:
			facing = int(signf(_aim_locked_dir.x))
	s.position = global_position + spawn_offset
	# A straight-down throw drops faster than the player's fall so it pulls away instead of
	# being overtaken (which used to make the thrower self-hit). Raise its fall cap to match.
	if vel.x == 0.0 and vel.y > 0.0:
		vel.y = DOWN_THROW_SPEED
		s.max_fall = DOWN_THROW_SPEED
		# Throwing straight down WHILE AIRBORNE recoils you upward: it pauses the fall and
		# pops you a little, imitating extra hang-time. minf() so it never slows a faster
		# ascent (it only ever helps) and rapid throws can't stack past one pop's worth.
		if not is_on_floor():
			velocity.y = minf(velocity.y, -SHURIKEN_THROW_RECOIL)
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
	# A RICOCHETED blade (bounced off another shuriken in a clash) is spent — it can NEVER
	# take a life. On contact it's CAUGHT into the stash; if the stash is already full it
	# simply passes harmlessly through (it can't be held, so it stays in play to grab later).
	if shuriken.ricocheted:
		if stash < 5:
			stash += 1
			stash_changed.emit(slot, stash)
			return true   # caught into the stash → consume
		return false       # stash full → fly painlessly through
	var t: float = Time.get_ticks_msec() / 1000.0
	if shuriken.thrower_slot == slot and (t - shuriken.throw_time) < Combat.self_hit_immunity_s:
		return false
	if is_iframe:
		# Successful, well-timed dodge → CATCH it: the shuriken goes into our stash
		# (it's kept in play, just held). Stash full → deflect it back into the round.
		if stash < 5:
			stash += 1
			stash_changed.emit(slot, stash)
			return true   # consumed into stash (held — not destroyed)
		else:
			shuriken.velocity_v = -shuriken.velocity_v
			shuriken.stuck = false
			return false
	# Your OWN shuriken never harms you. If you fall onto it from above, it gives a brief
	# upward pogo — momentary, then you keep falling (a touch of extra air-time, not a hit).
	if shuriken.thrower_slot == slot:
		if velocity.y > 0.0 and not shuriken.stuck and shuriken.global_position.y >= global_position.y:
			velocity.y = -SHURIKEN_POGO_BOUNCE
			Audio.play("dodge")
		return false   # never self-damage, never free — the blade stays in play
	if t < hurt_iframe_until:
		return false   # recently hit — invincible; shuriken passes through
	if _blocks_incoming(shuriken.velocity_v):
		# Guard up and facing the throw → the blade knocks it away. No damage, no catch:
		# unlike a dodge (which pockets the blade as ammo), a block deflects it back into play.
		shuriken.deflect(slot, facing)
		_on_block(shuriken.velocity_v)
		return false   # not caught into stash, not destroyed
	# A clean hit lands — the blade is spent and VANISHES. This is the ONLY way a shuriken
	# leaves the round; every other interaction (deflect, clash, miss) keeps it retrievable.
	take_damage(1, shuriken.velocity_v, shuriken.thrower_slot)
	return true   # caller frees the shuriken

# True when a guard is up AND the hit comes from the front (the side we face). The hit's
# travel direction is impact_velocity.x; a front guard faces INTO the threat, so we block
# when our facing points opposite to where the hit is heading. Vertical hits (stomps,
# impact_velocity.x == 0) are never blocked — the blade is held to the side, not overhead.
func _blocks_incoming(impact_velocity: Vector2) -> bool:
	if not is_defending:
		return false
	var hx: float = signf(impact_velocity.x)
	return hx != 0.0 and int(hx) == -facing

# Feedback for a successful block: a spark off the blade + a metallic clink. No damage,
# no knockback — a held guard stays planted (the velocity root re-zeroes x next frame anyway).
func _on_block(_impact_velocity: Vector2) -> void:
	Audio.play("block")
	_spawn_strike_flash(global_position + Vector2(facing * 12.0, -2.0))

# Apply damage. Returns true if it landed (false if blocked by guard/dodge/hurt i-frames or dead).
# Death (knockback + score) only happens when HP reaches 0.
func take_damage(amount: int, impact_velocity: Vector2, killer_slot: int = 0) -> bool:
	if not alive:
		return false
	if _blocks_incoming(impact_velocity):
		_on_block(impact_velocity)   # guard catches a front katana strike — sparks off, no damage
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	if is_iframe or t < hurt_iframe_until:
		return false
	hp -= amount
	if hp <= 0:
		_die(impact_velocity, killer_slot)
	else:
		hurt_iframe_until = t + HURT_IFRAME_S
		Audio.play("hit")
		# Small knockback (not the full death throw)
		if impact_velocity.length_squared() > 1.0:
			velocity += impact_velocity.normalized() * 130.0
			velocity.y -= 50.0
	_update_hp_indicator()   # reflect the new HP (or the death-hide) this instant, no frame lag
	return true

# Called by another player who landed on top of us (head-stomp).
# Returns true if the stomp landed (stomper bounces). Deals 1 damage like other hits.
func hit_by_stomp(stomper) -> bool:
	if not alive:
		return false
	if is_iframe:
		return false   # dodge i-frames block the stomp
	return take_damage(1, Vector2(0.0, 400.0), stomper.slot)   # downward stomp impulse

# Detect if we landed on top of another player this frame and trigger the stomp.
func _check_headstomp() -> void:
	if not alive:
		return
	# The AI never head-stomps — it does everything else (shurikens, katana, mobility) but
	# will not jump on the player's head. Landing on a foe is just a harmless collision.
	if is_bot:
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
				jumps_remaining = 1                    # refresh the single jump for chain stomps

func _die(impact_velocity: Vector2 = Vector2.ZERO, killer_slot: int = 0) -> void:
	alive = false
	# A corpse is no obstacle — drop off the collision layer so the living run straight
	# through it (it still rests on the ground via its own mask). Restored on respawn.
	collision_layer = 0
	_update_hp_indicator()   # hide all hearts the instant we die (don't wait for next _process)
	# Gentle topple: a small shove in the hit direction, then it just drops and settles —
	# no big launch, no spinning-ball flight across the screen.
	if impact_velocity.length_squared() > 1.0:
		velocity = Vector2(signf(impact_velocity.x) * DEATH_KNOCKBACK, -30.0)
		death_spin_dir = -1 if impact_velocity.x < 0.0 else 1
	else:
		velocity = Vector2.ZERO
		death_spin_dir = 1
	death_time = Time.get_ticks_msec() / 1000.0
	stash_changed.emit(slot, stash)
	Combat.on_kill(slot, killer_slot)

func respawn(at_pos: Vector2) -> void:
	alive = true
	collision_layer = _spawn_collision_layer   # solid again — back to being a real fighter
	_corpse_settled = false
	position = at_pos
	velocity = Vector2.ZERO
	is_iframe = false
	is_sliding = false
	is_wall_grabbing = false
	is_swinging = false
	is_defending = false
	swing_hit_done = false
	hurt_iframe_until = 0.0
	jumps_remaining = 1
	wall_jump_lock_until = -999.0
	clash_recoil_until = 0.0
	hit_recoil_until = 0.0
	frozen_until = 0.0
	katana_cooldown_until = -999.0
	slide_charged = true
	slide_cooldown_until = 0.0
	air_dash_penalty = false
	last_left_tap_t = -999.0
	last_right_tap_t = -999.0
	_bot_jitter = randf() * 0.10
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
	stash_changed.emit(slot, stash)   # refreshes the stash row
	_update_hp_indicator()            # full hearts back immediately
	_update_katana_indicator()

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
	# === Dead body — collapses aside (tips to lying-down and holds, not a spinning tumble) ===
	if not alive:
		var t_since_death: float = max(0.0, t - death_time)
		_set_visual_mode("pose")
		visual.frame = FRAME_JUMP   # tucked pose; rotated ~90° it reads as collapsed
		visual.rotation = clampf(death_spin_dir * t_since_death * DEATH_TOPPLE_RATE, -PI * 0.5, PI * 0.5)
		# Fade to clearly see-through — a translucent corpse reads as "non-solid, run through me".
		var alpha: float = clamp(1.0 - t_since_death * 0.5, 0.35, 1.0)
		visual.modulate = Color(0.6, 0.35, 0.40, alpha)
		visual.flip_h = false   # facing irrelevant while spinning
		if katana_sprite != null:
			katana_sprite.visible = false   # never leave a blade stuck on a corpse (died mid-swing)
		# Hearts/stash/katana belong to a LIVING ninja — hide them on the corpse here too
		# (belt-and-suspenders with the _process refresh) so a dead body can never display a
		# frozen heart row, regardless of which update path runs this frame.
		_update_hp_indicator()
		_update_stash_indicator()
		_update_katana_indicator()
		return
	# === Alive: determine state & pick texture mode + frame ===
	var in_action: bool = is_sliding or t < throw_anim_until
	if is_defending:
		_set_visual_mode("pose")
		visual.frame = FRAME_IDLE   # planted brace; the raised blade (below) sells the guard
	elif in_action:
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
	# === Modulate: NO dodge glow (the dodge reads from its pose/animation, TowerFall-style).
	# A brief red flash still marks a damage hit; otherwise the ninja stays its clan colour. ===
	if t < hurt_iframe_until:
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
		if is_swinging:
			katana_sprite.visible = true
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
		elif is_defending:
			# Guard stance: the raised(2) vertical blade held planted in front of the chest.
			# Same grip-anchor as the swing windup, nudged a touch further forward.
			katana_sprite.visible = true
			katana_sprite.flip_h = false
			katana_sprite.scale = Vector2(-facing * KATANA_VISUAL_SCALE, KATANA_VISUAL_SCALE)
			katana_sprite.position = Vector2(facing * 8.0, -2.0)
			katana_sprite.frame = 2
			katana_sprite.offset = Vector2(0.0, -6.0)
		else:
			katana_sprite.visible = false
	# Above-head indicators are refreshed in _process (every rendered frame, after all
	# physics mutations), so HP / stash / katana counts can't lag behind a hit, catch,
	# pickup or stomp that another node applied this frame.

# Refresh the above-head HP / stash / katana icons every rendered frame. Done in _process
# (not _physics_process) so the counts reflect the latest values even when another node
# (a shuriken catch/pickup, the opponent's stomp/katana) changed them this physics step.
func _process(_delta: float) -> void:
	_update_hp_indicator()
	_update_stash_indicator()
	_update_katana_indicator()

# Update above-head stash icons: filled (alpha 1.0) for held shurikens, dim (0.2) for used,
# hidden entirely (alpha 0) when dead.
# For all three rows: a held icon shows full, a spent/lost icon is FULLY hidden (not just
# dimmed) — so the number of visible icons always equals the real count. A faint "ghost"
# icon at low alpha was still readable and made 1 HP look like 5. All hidden while dead.
func _update_stash_indicator() -> void:
	if stash_icons.is_empty():
		return
	for i in stash_icons.size():
		stash_icons[i].modulate.a = 1.0 if (alive and i < stash) else 0.0

func _update_hp_indicator() -> void:
	if heart_icons.is_empty():
		return
	for i in heart_icons.size():
		heart_icons[i].modulate.a = 1.0 if (alive and i < hp) else 0.0

func _update_katana_indicator() -> void:
	if katana_icons.is_empty():
		return
	for i in katana_icons.size():
		katana_icons[i].modulate.a = 1.0 if (alive and i < katana_charges) else 0.0

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
