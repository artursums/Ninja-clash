# Player CharacterBody2D — a sprite-based ninja, tinted and skinned per clan.
#
# Drives one fighter slot: movement, wall-jump, dash-dodge, throwing, katana, guard,
# damage and death. Reads its intent from the PlayerInputRouter snapshot (ADR-0001)
# rather than Godot Input directly, so identical code runs for a local human, a bot
# (_bot_think fills the same virtual-input dicts) and an online puppet (ADR-0003).
# Balance values are data-driven from player_tuning.tres — see _apply_tuning().

extends CharacterBody2D

const FighterArt := preload("res://fighter_art.gd")
const Parry := preload("res://katana_parry.gd")

const Arena := preload("res://arena_rules.gd")

# === Tuning (data-driven) ===
# Loaded from player_tuning.tres in _ready (or an injected PlayerTuning for tests) so balance is
# editable + testable. Declared as vars (not consts) for that reason; the defaults below match the
# validated prototype, so behaviour is identical when no resource is present. Structural values
# (PLAYER_W/H, sprite frame indices) stay as consts — they are not balance knobs.
const TUNING_PATH := "res://player_tuning.tres"
var tuning: PlayerTuning = null   # inject in tests; otherwise TUNING_PATH is loaded in _ready
const BOT_TUNING_PATH := "res://bot_tuning.tres"
var bot_tuning: BotTuning = null  # inject in tests; otherwise loaded lazily on the first _bot_think

var MAX_HSPEED := 158.4
var JUMP_STRENGTH := 480.0
var GRAVITY := 1400.0
var PLAYER_TERMINAL_FALL_SPEED := 320.0
var STOMP_BOUNCE_STRENGTH := 260.0
var STOMP_BOUNCE_SIDEWAYS := 150.0
var STOMP_BOUNCE_LOCK_S := 0.12
var STOMP_COOLDOWN_S := 0.45
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
# How much of a foe's body must be inside the blade box to count as a hit, as a fraction of their
# half-extents. 0 = their CENTRE must be inside (old behaviour — tip could enter without landing);
# 1 = any part of the body counts (reached a touch too far). 0.6 sits in between: the tip must bite
# in a little, not merely graze the edge.
const KATANA_HIT_BODY_FRAC := 0.6
var KATANA_VISUAL_SCALE := 1.0
var KATANA_HIT_KNOCKBACK := 150.0
var KATANA_HIT_POP := 70.0
var KATANA_HIT_RECOIL_S := 0.10

# Charged katana "blade-wave" projectile (DEV-005 — optional variant, gated by MatchConfig.blade_wave_enabled).
# Holding the katana past CHARGE_TIME then releasing fires a straight directional slash-wave instead
# of a second swing; the release ALWAYS spends one katana charge (miss/terrain/block all cost it).
var BLADE_WAVE_CHARGE_TIME_S := 3.0
var BLADE_WAVE_SPEED := 340.0
var BLADE_WAVE_DAMAGE := 1
var BLADE_WAVE_LIFETIME_S := 2.5
# Charge tell: up to three wave "pips" stack in front while holding. Fixed (clan-independent) colours
# so the player learns the cue — the HOT 3rd colour means "fully charged, release now".
const BLADE_WAVE_TELL_SHEET := "res://sprites/fx/katana_slash_5frame_native_400x80.png"
const CHARGE_PIP_COLORS := [
	Color(0.45, 0.75, 1.0),   # 1 — cool blue (just started)
	Color(1.0, 0.82, 0.25),   # 2 — gold (charging)
	Color(1.0, 0.30, 0.18),   # 3 — hot red = READY, let go now
]

# Guard mobility + bounces (L2). You can RUN while guarding (was rooted). When a blade lands
# on a raised guard the attacker is knocked back a little; when two raised guards collide both
# fighters are shoved apart. All sell with a spark + clash flash.
var BLOCK_RECOIL_SPEED := 155.0   # attacker pushed back off a guard they struck
var BLOCK_RECOIL_POP := 55.0      # small upward pop on that recoil
var BLOCK_RECOIL_S := 0.12        # how long the recoil velocity is held
var SHIELD_BUMP_SPEED := 175.0    # two guards meeting shove each other apart
var SHIELD_BUMP_POP := 45.0
var SHIELD_BUMP_S := 0.14
var SHIELD_BUMP_RANGE := 24.0     # horizontal gap within which two guards "meet"
var SHIELD_BUMP_VRANGE := 28.0    # vertical tolerance (must be on roughly the same level)

# Guard meter ("mana"). A full guard sustains GUARD_MAX_S of held block. Once you begin spending it
# the meter never regenerates until it is fully drained: releasing early just freezes the bar where
# it stands, and only emptying it triggers the GUARD_COOLDOWN_S lockout (no blocking) that refills it.
# This commits a fighter to spending the whole bar — guard can't be feathered/spammed. Shown as a
# depleting bar above the head.
var GUARD_MAX_S := 4.0
var GUARD_COOLDOWN_S := 5.0

# Movement dust (TowerFall-style scuff/puff). Feet sit half the 32px hitbox below origin.
const DUST_FEET_OFFSET := 16.0
const DUST_BODY_HALF := 11.0        # body half-width; puffs are pushed fully OUTSIDE this so nothing sits under the ninja
const DUST_SCALE := 0.7             # one knob for puff size (was 1.4-1.6 — shrunk so dust reads as small scuffs)
const RUN_DUST_INTERVAL_S := 0.16   # real-time gap between run scuffs
const RUN_DUST_MIN_HSPEED := 40.0   # only kick up dust above this ground speed

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
var katana_charging: bool = false      # blade-wave variant: katana held, a directional wave charging
var katana_charge_ready: bool = false  # held past BLADE_WAVE_CHARGE_TIME_S — releasing now fires the wave
var katana_press_t: float = -999.0     # real-time the current katana hold began
var _charge_pips: Array = []           # up to 3 coloured wave sprites in front, the charge tell
var hurt_iframe_until: float = 0.0
var jumps_remaining: int = 1   # single jump (no double jump); resets to 1 whenever on floor
var iframe_t_end: float = 0.0
var slide_t_end: float = 0.0
var slide_dir: Vector2 = Vector2.ZERO   # normalized dash direction (8-way), set on each slide
var slide_charged: bool = true          # L2/R2 dash charge — spent on dash, restored on floor/wall contact
var slide_cooldown_until: float = 0.0   # earliest time the charge may refill (base cooldown + any air refresh)
var air_dash_penalty: bool = false      # set when a dash is taken airborne — adds the touch-down delay once
var last_left_tap_t: float = -999.0     # keyboard double-tap-to-dash timing (any human slot, 4-way)
var last_right_tap_t: float = -999.0
var last_up_tap_t: float = -999.0
var last_down_tap_t: float = -999.0
var wall_jump_lock_until: float = -999.0
var stomp_cooldown_until: float = -999.0     # stomper can't head-stomp again until this real-time
var stomp_bounce_lock_until: float = -999.0  # holds the sideways stomp bounce against movement input
var clash_recoil_until: float = 0.0   # while > now, hold the clash recoil velocity (input can't override)
var hit_recoil_until: float = 0.0     # while > now, hold the small katana-hit / block knock-back
var shield_bump_until: float = 0.0    # while > now, hold the guard-vs-guard shove (input can't override)
var guard_meter: float = 4.0          # remaining guard time (seconds); GUARD_MAX_S when full
var guard_cooldown_until: float = 0.0 # while > now, guard is broken/locked out (refilling)
var frozen_until: float = 0.0         # while > now, this fighter is in a clash hitstop (per-player, not global)
var throw_anim_until: float = 0.0   # show ATTACK frame for ~220ms after a throw
var _was_on_floor: bool = false     # previous-frame floor state — drives the landing dust puff
var _next_run_dust_t: float = 0.0   # real-time gate so run scuffs spawn at intervals, not every frame
var death_time: float = -1.0        # set on _die() — drives spin/fade timing
var death_spin_dir: int = 0         # +1 or -1 — matches knockback horizontal direction
var _first_tick_done: bool = false

# === Online puppet state (ADR-0003) ===
# On the online CLIENT every fighter is a puppet: the host owns the simulation and Net applies
# its snapshots onto these fields (via NetCodec.apply_player). _puppet_tick dead-reckons between
# snapshots and blends toward the latest authoritative position.
var net_target_pos: Vector2 = Vector2.ZERO   # latest host position for this fighter
var net_has_target: bool = false
const PUPPET_SNAP_DIST := 90.0      # beyond this, teleport (spawn / screen wrap), don't lerp
const PUPPET_BLEND := 0.35          # per-tick pull toward the authoritative position

# Pure bot decision helpers. preload (not a class_name) so it resolves on a fresh headless boot
# without depending on the editor's global class cache being regenerated first.
const BotLogic := preload("res://bot_logic.gd")

const BotBrain := preload("res://bot_brain.gd")
var is_bot := false
var bot_difficulty := 1
var _bot_held: Dictionary = {}
var _bot_pressed: Dictionary = {}
var _bot_throw_dir := Vector2.RIGHT
var _bot_brain: RefCounted

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
var _motion_clock := 0.0

# === Above-head indicators (built by main.gd) ===
var stash_icons: Array = []    # 5 shuriken icons
var heart_icons: Array = []    # 5 HP hearts
var katana_icons: Array = []   # 3 katana-charge marks
var guard_bar_bg: ColorRect = null    # guard-meter bar (track + fill), above the head
var guard_bar_fill: ColorRect = null
const GUARD_BAR_W := 26.0
var katana_sprite: Sprite2D = null   # swing visual ("Katana" child)
var slash_fx: Node2D = null          # blade-aligned slash trail (slash_fx.gd)

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
		STOMP_BOUNCE_SIDEWAYS = tuning.stomp_bounce_sideways
		STOMP_BOUNCE_LOCK_S = tuning.stomp_bounce_lock_s
		STOMP_COOLDOWN_S = tuning.stomp_cooldown_s
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
		BLADE_WAVE_CHARGE_TIME_S = tuning.blade_wave_charge_time_s
		BLADE_WAVE_SPEED = tuning.blade_wave_speed
		BLADE_WAVE_DAMAGE = tuning.blade_wave_damage
		BLADE_WAVE_LIFETIME_S = tuning.blade_wave_lifetime_s
	SLIDE_MAX_UP_SPEED = SLIDE_SPEED * 0.7071067811865476


func _ready() -> void:
	add_to_group("players")
	_apply_tuning()   # data-driven balance: load player_tuning.tres (or use the injected resource)
	_spawn_collision_layer = collision_layer   # remember our solid layer so respawn restores it
	var prefix = "p%d" % slot   # every slot reads ITS OWN action set (pads 3/4 bind to p3_/p4_)
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
	# Online client: puppet mode — render the host's snapshots, never simulate or read input.
	if Net.is_client():
		_puppet_tick(delta)
		return
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
		# Pin the horizontal spawn column through the MATCH_INTRO countdown: a fighter must never
		# drift off its pad before the round begins. (Root cause of the rare "same-spot at round
		# start" was never caught in testing, so we hard-hold the column as belt-and-braces.)
		if GameState.current_state == GameState.State.MATCH_INTRO and spawn_pos != Vector2.ZERO:
			position.x = spawn_pos.x
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
	# exactly as normal while you aim. Bots manage their own timed aim and release intent.
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
	# katana strikes (see _blocks_incoming); gives no ammo (vs dodge, which catches). Mutually
	# exclusive with dash / aim / swing / wall-grab. You CAN run while guarding (shield charge):
	# two raised guards that meet bounce apart (see _check_shield_bump).
	# Guard requires meter and no active lockout (see the meter update just below).
	is_defending = _held(input_defend) and not is_swinging and not is_sliding \
		and not is_aiming and not is_wall_grabbing \
		and guard_meter > 0.0 and t >= guard_cooldown_until

	# Guard meter: drain while guarding (empties in GUARD_MAX_S), break into a GUARD_COOLDOWN_S
	# lockout on empty (the bar refills across it). Releasing without emptying freezes the meter —
	# no regen until it is fully spent, so a started guard must be drained to the bottom.
	if is_defending:
		guard_meter = maxf(0.0, guard_meter - delta)
		if guard_meter <= 0.0:
			guard_cooldown_until = t + GUARD_COOLDOWN_S
			Audio.play("hit")   # guard-break cue
	elif t < guard_cooldown_until:
		guard_meter = GUARD_MAX_S * clampf(1.0 - (guard_cooldown_until - t) / GUARD_COOLDOWN_S, 0.0, 1.0)

	# Apply velocity — priority: dash-dodge > recoils (clash / hit / shield-bump) > guard-run >
	# wall-jump-lock > walk. Recoils sit above the guard so a bump shove can't be cancelled by
	# simply holding the guard. Aiming does NOT appear here: you run while you aim, same as ever.
	if is_sliding:
		# Directional dash-dodge: drive the whole velocity vector (8-way, incl. up/diagonal).
		# Upward speed is capped (see _dash_velocity) so a straight-up dash matches a diagonal's height.
		velocity = _dash_velocity()
	elif t < clash_recoil_until:
		pass   # hold the post-clash push-apart; don't let movement input cancel it
	elif t < hit_recoil_until:
		pass   # hold the brief katana-hit / block knock-back so the bump reads
	elif t < shield_bump_until:
		pass   # hold the guard-vs-guard shove
	elif t < stomp_bounce_lock_until:
		pass   # hold the sideways bounce off a stomped head so input can't cancel the knock-away
	elif is_defending:
		velocity.x = move * MAX_HSPEED   # run while guarding (shield charge)
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
			# puff against the wall (the side the ninja is pushing off), not under it
			_spawn_dust(Vector2(global_position.x, global_position.y + DUST_FEET_OFFSET), "jump", -signf(wall_normal.x))
		elif jumps_remaining > 0:
			velocity.y = -JUMP_STRENGTH   # single jump, always full strength (coyote case included)
			jumps_remaining -= 1
			# kick-off puff beside the trailing foot
			_spawn_dust(Vector2(global_position.x, global_position.y + DUST_FEET_OFFSET), "jump", -float(facing))

	# Dash-dodge request — ONE move on L2, R2 AND Circle (slide + dodge are now unified),
	# plus a keyboard double-tap of any move/aim direction (W/A/S/D or numpad 8/4/5/6) for
	# every HUMAN slot. The dash fires toward the held aim, so the second tap's held key
	# already points it the right way. (A pad stick crossing the deadzone twice inside the
	# window also counts — accepted: the dash still costs the charge + cooldown.)
	var dash_requested: bool = not is_defending and (_pressed(input_slide) or _pressed(input_dodge))
	if not is_bot:
		last_left_tap_t = _tap_check(input_left, last_left_tap_t, t)
		last_right_tap_t = _tap_check(input_right, last_right_tap_t, t)
		last_up_tap_t = _tap_check(input_aim_up, last_up_tap_t, t)
		last_down_tap_t = _tap_check(input_aim_down, last_down_tap_t, t)
		if last_left_tap_t == TAP_FIRED or last_right_tap_t == TAP_FIRED \
				or last_up_tap_t == TAP_FIRED or last_down_tap_t == TAP_FIRED:
			dash_requested = true
			last_left_tap_t = -999.0; last_right_tap_t = -999.0
			last_up_tap_t = -999.0;   last_down_tap_t = -999.0

	# Dash-dodge — fires toward the held aim (8-way) with brief i-frames that catch an
	# incoming shuriken. Spends the charge; in the air you get exactly one until you touch
	# floor/wall again (no infinite climbing). The cooldown forces timing per shuriken.
	if dash_requested and not is_sliding and not is_defending and slide_charged:
		slide_charged = false
		slide_cooldown_until = t + SLIDE_COOLDOWN_S
		air_dash_penalty = not (on_floor_now or on_wall_now)   # only airborne dashes pay the touch-down delay
		_start_slide(_aim_direction(), t)

	# Katana. Standard rules: a press swings instantly (zero latency). When the blade-wave variant
	# is ON the katana becomes HOLD-TO-CHARGE: holding winds up a wave (no swing yet), a quick tap
	# swings on release, and holding past the threshold then releasing throws the wave.
	# Once all charges are spent the katana is locked out for the round (respawn refills it).
	if MatchConfig.blade_wave_enabled:
		_update_katana_charge_input(t)
	elif _pressed(input_katana) and not is_swinging and not is_defending and katana_charges > 0 and t >= katana_cooldown_until:
		_start_swing(t)
	if is_swinging:
		_process_swing(t)
		if t - swing_start_t >= KATANA_SWING_DURATION_S:
			is_swinging = false

	# Guard-vs-guard: two raised guards meeting shove both fighters apart (+ spark).
	_check_shield_bump(t)

	# Head-stomp detection: snapshot fall velocity, then check collisions after move
	var was_falling: bool = velocity.y > 50.0
	move_and_slide()
	if was_falling:
		_check_headstomp()
	_update_movement_dust(t, was_falling)
	_check_screen_wrap()
	_update_visual()

# Online-client frame: move with the snapshot velocity through the real level colliders (so
# is_on_floor() and the run/jump poses read correctly), then blend toward the authoritative
# position. All state fields were set by NetCodec.apply_player; this only renders them.
func _puppet_tick(delta: float) -> void:
	if not alive:
		_hide_reticle()
		if net_has_target:
			position = net_target_pos   # corpses just track the host exactly (they barely move)
		_update_visual()
		return
	if not is_sliding:
		velocity.y += GRAVITY * delta   # dead-reckon the arc between 30 Hz snapshots
		velocity.y = minf(velocity.y, PLAYER_TERMINAL_FALL_SPEED)
	move_and_slide()
	if net_has_target:
		if position.distance_to(net_target_pos) > PUPPET_SNAP_DIST:
			position = net_target_pos   # spawn / screen-wrap jump — snap, never streak across
		else:
			position = position.lerp(net_target_pos, PUPPET_BLEND)
	_check_screen_wrap()
	_update_aim_reticle()
	_update_visual()

# Double-tap detection for one direction action. Returns the updated "last tap" timestamp:
# TAP_FIRED when this press completed a double-tap (caller dashes and resets all four),
# the press time on a first tap, or the old value when the action wasn't pressed this tick.
const TAP_FIRED := -1.0
func _tap_check(action: String, last_t: float, t: float) -> float:
	if not _pressed(action):
		return last_t
	if t - last_t <= DOUBLE_TAP_WINDOW_S:
		return TAP_FIRED
	return t

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
func _prepare_bot() -> void:
	if bot_tuning == null:
		bot_tuning = load(BOT_TUNING_PATH)
	if _bot_brain == null:
		_bot_brain = BotBrain.new()
	_bot_brain.prepare(self)

func _bot_think(t: float) -> void:
	if _bot_brain == null:
		_prepare_bot()
	_bot_brain.tick(self, t)
	is_aiming = _bot_brain.aim_release > 0
	if is_aiming:
		aim_dir = _bot_brain.aim
		_aim_locked_dir = aim_dir.normalized()

func _bot_should_stomp() -> bool:
	var scavengeable := false
	if _bot_brain != null and _bot_brain.navigation != null:
		var standing: int = _bot_brain.navigation.nearest_ledge(global_position)
		scavengeable = _bot_brain._pickup(self, standing) != null
	return BotLogic.should_stomp(stash, katana_charges, scavengeable)

func _start_swing(t: float) -> void:
	Combat.record(slot, "strikes")
	is_swinging = true
	swing_start_t = t
	swing_hit_done = false
	katana_cooldown_until = t + KATANA_SWING_DURATION_S + KATANA_COOLDOWN_S   # 0.2 s recovery after the swing finishes (0.52 s total swing-to-swing)
	Audio.play("dodge")   # placeholder swoosh

# Blade-wave hold-to-charge input (DEV-005, only while the variant is ON). A press begins a charge
# WITHOUT swinging — holding is the wind-up. Held past BLADE_WAVE_CHARGE_TIME_S it arms (charge tell
# peaks); releasing while armed throws the wave, releasing before then does the normal swing. So a
# quick tap still swings (on release) and a long hold throws. Cancels cleanly on guard/death/no
# charges. Bots only pulse the press for one frame, so they fall straight through to the normal swing.
func _update_katana_charge_input(t: float) -> void:
	if _pressed(input_katana) and not katana_charging and not is_swinging and not is_defending \
			and katana_charges > 0 and t >= katana_cooldown_until:
		katana_charging = true
		katana_charge_ready = false
		katana_press_t = t
	if not katana_charging:
		return
	if is_defending or katana_charges <= 0 or not alive:
		katana_charging = false
		katana_charge_ready = false
		return
	if _held(input_katana):
		if not katana_charge_ready and t - katana_press_t >= BLADE_WAVE_CHARGE_TIME_S:
			katana_charge_ready = true
			Audio.play("dodge")   # "charged / ready" cue
		return
	# Released:
	if katana_charge_ready:
		_fire_blade_wave(t)            # held past the threshold → throw the wave
	elif t >= katana_cooldown_until:
		_start_swing(t)               # quick tap → normal swing (on release)
	katana_charging = false
	katana_charge_ready = false

# Spawn the directional slash-wave and ALWAYS spend one katana charge (the explicit contrast with the
# melee swing, which never wastes a charge on a whiff/clash). Direction reuses the 8-way throw aim.
func _fire_blade_wave(t: float) -> void:
	if katana_charges <= 0:
		return
	Combat.record(slot, "strikes")
	var dir: Vector2 = _throw_aim().normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)
	if dir.x != 0.0:
		facing = int(signf(dir.x))   # face the wave
	katana_charges -= 1
	_update_katana_indicator()
	var WaveScript: Script = load("res://blade_wave.gd")
	var w: Area2D = Area2D.new()
	w.set_script(WaveScript)
	w.thrower_slot = slot
	w.damage = BLADE_WAVE_DAMAGE
	w.lifetime_s = BLADE_WAVE_LIFETIME_S
	w.velocity_v = dir * BLADE_WAVE_SPEED
	var clan: Dictionary = GameState.get_clan(slot)
	w.tint = clan.get("secondary", Color(0.7, 0.9, 1.0))
	w.position = global_position + dir * 18.0
	get_parent().add_child(w)
	Audio.play("throw")
	throw_anim_until = t + 0.22
	if slash_fx != null:
		slash_fx.stop()
	_hide_charge_pips()

# Active during the swing's hit window: deflect any flying shuriken in front,
# and deal 1 damage to one enemy (consuming a katana charge, max 3).
func _process_swing(t: float) -> void:
	var elapsed: float = t - swing_start_t
	if Parry.active(elapsed):
		for shuriken in get_tree().get_nodes_in_group("shurikens"):
			_try_katana_parry(shuriken, t)
	if elapsed < KATANA_HIT_START_S or elapsed > KATANA_HIT_END_S:
		return
	var hb_center: Vector2 = global_position + Vector2(facing * KATANA_RANGE * 0.5, 0.0)
	var hb_half: Vector2 = Vector2(KATANA_RANGE * 0.5 + 4.0, KATANA_HALF_H)
	if swing_hit_done:
		return
	# CLASH first: if an enemy is also mid-swing and we sit inside each other's reach
	# this frame, the blades meet — a parry, not a hit. No damage, no charge spent.
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		if _box_hits_body(p.global_position, hb_center, hb_half) and _is_clashing_with(p):
			swing_hit_done = true
			Combat.register_clash(self, p)   # fires the freeze + lightning + recoil (de-duped)
			return
	# Strike an enemy — or get parried by their raised guard, which bounces US back.
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		if not _box_hits_body(p.global_position, hb_center, hb_half):
			continue
		var impact: Vector2 = Vector2(facing * 220.0, -80.0)
		if p.is_guarding_against(impact):
			# Blade meets a front guard: spark on the guard, no damage — and we recoil off it.
			swing_hit_done = true
			p._on_block(impact)
			apply_block_recoil()
			_spawn_clash_burst((global_position + p.global_position) * 0.5)
		elif katana_charges > 0 and p.take_damage(1, impact, slot):
			katana_charges -= 1
			_update_katana_indicator()   # reflect the spent charge this instant, no frame lag
			swing_hit_done = true
			_spawn_strike_flash(p.global_position)
			if p.alive and p.has_method("apply_hit_recoil"):
				p.apply_hit_recoil(facing)   # small bump on a survivor — sells the hit
		break

func _point_in_box(point: Vector2, center: Vector2, half: Vector2) -> bool:
	return absf(point.x - center.x) <= half.x and absf(point.y - center.y) <= half.y

# True when a fighter's BODY box (PLAYER_W×PLAYER_H, centred on body_center) overlaps the blade
# hitbox — AABB vs AABB. A center-only test let the blade TIP visibly enter a foe without landing,
# because the foe's centre could still sit outside the box; testing the whole body fixes that so the
# tip connects whenever any part of the foe is in reach.
func _box_hits_body(body_center: Vector2, hb_center: Vector2, hb_half: Vector2) -> bool:
	return absf(hb_center.x - body_center.x) <= hb_half.x + PLAYER_W * 0.5 * KATANA_HIT_BODY_FRAC \
		and absf(hb_center.y - body_center.y) <= hb_half.y + PLAYER_H * 0.5 * KATANA_HIT_BODY_FRAC

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
	return _box_hits_body(global_position, ohb_center, ohb_half)

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

# True when our guard is up AND `impact_velocity` comes at our front — i.e. we parry this strike.
# Queried by an attacker's swing so a blocked blade can bounce the attacker instead of cutting.
func is_guarding_against(impact_velocity: Vector2) -> bool:
	return _blocks_incoming(impact_velocity)

# Our blade landed on a foe's raised guard: bounce us back off it (opposite our facing), briefly
# held so the parry reads. No damage, no charge — the swing is already marked resolved.
func apply_block_recoil() -> void:
	velocity.x = float(-facing) * BLOCK_RECOIL_SPEED
	velocity.y = minf(velocity.y, -BLOCK_RECOIL_POP)
	hit_recoil_until = Time.get_ticks_msec() / 1000.0 + BLOCK_RECOIL_S

# Guard-vs-guard: while we hold a guard, if another guarding fighter overlaps us, shove both
# apart with a spark. The lower slot drives the pair (applies the shove to both) so it fires once.
func _check_shield_bump(t: float) -> void:
	if not is_defending or not alive or t < shield_bump_until:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive or not p.is_defending or slot >= p.slot:
			continue
		var dx: float = p.global_position.x - global_position.x
		if absf(dx) > SHIELD_BUMP_RANGE or absf(p.global_position.y - global_position.y) > SHIELD_BUMP_VRANGE:
			continue
		var dir: int = 1 if dx >= 0.0 else -1   # +1 when the foe is to our right
		apply_shield_bump(-dir, t)              # we are shoved away from the foe
		p.apply_shield_bump(dir, t)             # the foe is shoved the other way
		_spawn_clash_burst((global_position + p.global_position) * 0.5)
		Audio.play("block")
		return

# Shove from a guard-vs-guard meeting: push along dir_x, small pop, face the foe we bumped.
func apply_shield_bump(dir_x: int, t: float) -> void:
	velocity.x = float(dir_x) * SHIELD_BUMP_SPEED
	velocity.y = minf(velocity.y, -SHIELD_BUMP_POP)
	shield_bump_until = t + SHIELD_BUMP_S
	facing = -dir_x   # keep facing the fighter we just clashed guards with

# A clash spark (the 5-frame lightning) for guard bounces — juicier than the small hit flash.
func _spawn_clash_burst(pos: Vector2) -> void:
	var path: String = "res://sprites/fx/clash_lightning_5frame_native_160x32.png"
	if not ResourceLoader.exists(path):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = 5
	fx.fps = 20.0
	fx.texture = load(path)
	fx.position = pos
	fx.scale = Vector2(1.5, 1.5)
	fx.z_index = 55
	get_parent().add_child(fx)
	Net.relay_strip_fx(path, 5, 20.0, pos, fx.scale, 55)

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
	Net.relay_strip_fx(path, 4, 22.0, pos, fx.scale, 50)

# TowerFall-style movement puff. kind = "run" | "jump" | "land". Spawned into the
# world (like the other FX) so the dust stays put while the ninja keeps moving.
# flip_x mirrors the strip so a run scuff trails the correct way.
# foot_pos = ground contact at the player's CENTRE x; side = -1 (left) / +1 (right).
# fx_anim centres the sprite, so we re-anchor it: inner edge pushed past the body
# (DUST_BODY_HALF) so it sits BESIDE the ninja, and the LOWEST dust pixel (base_row,
# since the cell's lower rows are empty padding) lands exactly on foot_pos.y — so the
# puff rests ON the ground, not floating in the air, and nothing pokes below the floor.
func _spawn_dust(foot_pos: Vector2, kind: String, side: float) -> void:
	# [path, frame_count, fps, native_w, native_h, base_row]  (base_row = lowest dust pixel)
	var info: Array = {
		"run":  ["res://sprites/fighters/dust_run.png", 8, 30.0, 32.0, 32.0, 25.0],
		"jump": ["res://sprites/fighters/dust_burst.png", 8, 32.0, 32.0, 32.0, 25.0],
		"land": ["res://sprites/fighters/dust_burst.png", 8, 28.0, 32.0, 32.0, 25.0],
	}.get(kind, [])
	if info.is_empty() or not ResourceLoader.exists(info[0]):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = info[1]
	fx.fps = info[2]
	fx.texture = load(info[0])
	var s: float = DUST_SCALE
	var dir: float = -1.0 if side < 0.0 else 1.0
	var half_w: float = info[3] * s * 0.5
	var half_h: float = info[4] * s * 0.5
	fx.position = Vector2(
		foot_pos.x + dir * (DUST_BODY_HALF + half_w),
		foot_pos.y + half_h - info[5] * s)   # drop so the lowest dust pixel sits on the floor
	fx.scale = Vector2(dir * s, s)   # mirror so the puff drifts/leans OUTWARD
	fx.z_index = 1   # just above the floor tiles, below combat sparks (z 50)
	get_parent().add_child(fx)
	Net.relay_strip_fx(info[0], info[1], info[2], fx.position, fx.scale, 1)

# Run scuffs + landing puff. Called once per physics step AFTER move_and_slide(),
# so is_on_floor() and global_position reflect this frame's result.
func _update_movement_dust(t: float, was_falling: bool) -> void:
	var on_floor_now: bool = is_on_floor()
	if alive:
		var foot: Vector2 = Vector2(global_position.x, global_position.y + DUST_FEET_OFFSET)
		if on_floor_now and not _was_on_floor and was_falling:
			# landing: a puff kicks out to EACH side (nothing directly under the ninja)
			_spawn_dust(foot, "land", -1.0)
			_spawn_dust(foot, "land", 1.0)
		elif on_floor_now and not is_sliding and absf(velocity.x) > RUN_DUST_MIN_HSPEED:
			if t >= _next_run_dust_t:    # periodic scuff trailing BEHIND the direction of travel
				_next_run_dust_t = t + RUN_DUST_INTERVAL_S
				_spawn_dust(foot, "run", -signf(velocity.x))
	_was_on_floor = on_floor_now

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
	Combat.record(slot, "throws")
	if not MatchConfig.infinite_shurikens:
		stash -= 1
		stash_changed.emit(slot, stash)
	Audio.play("throw")
	throw_anim_until = Time.get_ticks_msec() / 1000.0 + 0.22

func _try_katana_parry(shuriken, t: float) -> bool:
	if not alive or not is_swinging or shuriken.stuck or shuriken.consumed or shuriken.puppet or shuriken.thrower_slot == slot:
		return false
	if not Parry.active(t - swing_start_t):
		return false
	if not Parry.intersects(global_position, facing, shuriken._previous_position, shuriken.global_position):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, shuriken.global_position, 1)
	query.exclude = [get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return false
	shuriken.deflect(slot, facing)
	_spawn_strike_flash(shuriken.global_position)
	return true

func hit_by_shuriken(shuriken) -> bool:
	if _try_katana_parry(shuriken, Time.get_ticks_msec() / 1000.0):
		return false
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
	Combat.record(slot, "blocks")
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
	if killer_slot != slot:
		Combat.record(killer_slot, "hits")
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
# Someone landed on our head. We ALWAYS bounce them off (return true) while alive, so a stomper
# can never perch on the head — but we only take DAMAGE when not protected by dodge/hurt i-frames.
# The damage path opens a hurt-iframe window (take_damage), so even back-to-back stomps can't drain
# HP faster than that window. Returns true = valid head contact, bounce the stomper.
func hit_by_stomp(stomper) -> bool:
	if not alive:
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	if not is_iframe and t >= hurt_iframe_until:
		take_damage(1, Vector2(0.0, 400.0), stomper.slot)   # downward stomp impulse; plays "hit", opens i-frames
	else:
		Audio.play("dodge")   # protected — soft bounce blip, no damage
	return true

# Detect if we landed on top of another player this frame and trigger the stomp.
func _check_headstomp() -> void:
	if not alive:
		return
	# Head-stomp is a LAST RESORT for the AI: a bot only stomps when fully disarmed (no shurikens,
	# no katana charges, no loose blade to scavenge — see _bot_should_stomp). While armed it never
	# stomps, so even an incidental landing on the foe is a harmless collision.
	if is_bot and not _bot_should_stomp():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < stomp_cooldown_until:
		return   # just stomped — must wait before stomping again (anti rapid multi-stomp)
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
				# Bounce UP and SIDEWAYS away from the victim so we're knocked off the head instead
				# of dropping straight back on it. The sideways shove is briefly input-locked, and a
				# stomp cooldown blocks an instant re-stomp. NO jump refresh (it enabled chain-stomps).
				velocity.y = -STOMP_BOUNCE_STRENGTH
				var away: float = signf(global_position.x - other.global_position.x)
				if away == 0.0:
					away = float(facing)   # dead-centre overlap: shove the way we're facing
				velocity.x = away * STOMP_BOUNCE_SIDEWAYS
				facing = int(away)
				stomp_bounce_lock_until = t + STOMP_BOUNCE_LOCK_S
				stomp_cooldown_until = t + STOMP_COOLDOWN_S
				break   # one stomp per frame

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
	spawn_pos = at_pos   # remembered so the MATCH_INTRO freeze can pin us to this column
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
	stomp_cooldown_until = -999.0
	stomp_bounce_lock_until = -999.0
	clash_recoil_until = 0.0
	hit_recoil_until = 0.0
	shield_bump_until = 0.0
	frozen_until = 0.0
	guard_meter = GUARD_MAX_S
	guard_cooldown_until = 0.0
	katana_cooldown_until = -999.0
	katana_charging = false
	katana_charge_ready = false
	katana_press_t = -999.0
	slide_charged = true
	slide_cooldown_until = 0.0
	air_dash_penalty = false
	last_left_tap_t = -999.0
	last_right_tap_t = -999.0
	if _bot_brain != null:
		_bot_brain.reset()
	_bot_held.clear()
	_bot_pressed.clear()
	# Loadout from the global match variants (MatchConfig). Defaults reproduce the standard game.
	stash = MatchConfig.effective_start_shurikens()
	hp = MatchConfig.max_hp
	# Katana: PER-ROUND recharge (default) refills charges on every spawn; NEVER-recharge grants
	# them only at the match's first spawn (round 1) and carries the remainder across later rounds.
	# Disabled = no katana at all.
	if not MatchConfig.katana_enabled:
		katana_charges = 0
	elif MatchConfig.katana_recharge or GameState.current_round == 1:
		katana_charges = MatchConfig.katana_charges
	# else (NEVER recharge, round > 1): keep katana_charges — carry the remaining charges over.
	facing = 1 if slot == 1 else -1
	death_time = -1.0
	death_spin_dir = 0
	if visual != null:
		visual.rotation = 0.0
		visual.modulate = Color.WHITE
	if katana_sprite != null:
		katana_sprite.visible = false
	if slash_fx != null:
		slash_fx.stop()
	stash_changed.emit(slot, stash)   # refreshes the stash row
	_update_hp_indicator()            # full hearts back immediately
	_update_katana_indicator()

func _check_screen_wrap() -> void:
	position = Arena.wrap_position(position)

# Lazily build the procedural slash arc as a child, tinted to this fighter's clan colour. Created on
# the first swing so it picks up the clan assigned for the match.
func _ensure_slash_fx() -> void:
	if slash_fx != null and is_instance_valid(slash_fx):
		return
	slash_fx = load("res://slash_fx.gd").new()
	add_child(slash_fx)
	var clan: Dictionary = GameState.get_clan(slot)
	slash_fx.set_tint(clan.get("secondary", Color(0.7, 0.9, 1.0)))


# Lazily build the three blade-wave charge "pips" — small slash crescents that sit in front of the
# fighter while charging. Built once and then shown/hidden + recoloured each frame.
func _ensure_charge_pips() -> void:
	if not _charge_pips.is_empty():
		return
	var tex: Texture2D = null
	if ResourceLoader.exists(BLADE_WAVE_TELL_SHEET):
		tex = load(BLADE_WAVE_TELL_SHEET)
	for i in 3:
		var pip: Sprite2D = Sprite2D.new()
		if tex != null:
			pip.texture = tex
			pip.hframes = 5
			pip.frame = 2                                    # fullest crescent frame
		pip.centered = true
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pip.z_index = 56
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		pip.material = mat
		pip.visible = false
		add_child(pip)
		_charge_pips.append(pip)


# Charge tell. While holding, 1→2→3 coloured wave pips stack outward in front of the fighter; the
# 3rd (hot-red, pulsing) only appears when fully charged — the "release now" signal. Hidden otherwise.
func _update_charge_pips(t: float) -> void:
	if not katana_charging or not alive or not GameState.is_round_active():
		_hide_charge_pips()
		return
	_ensure_charge_pips()
	var progress: float = clampf((t - katana_press_t) / maxf(BLADE_WAVE_CHARGE_TIME_S, 0.001), 0.0, 1.0)
	var shown: int = 1
	if katana_charge_ready:
		shown = 3                # fully charged → all three, 3rd = release colour
	elif progress >= 0.5:
		shown = 2
	for i in _charge_pips.size():
		var pip: Sprite2D = _charge_pips[i]
		if i < shown:
			var s: float = 0.42
			if i == 2 and katana_charge_ready:
				s *= 0.9 + 0.16 * sin(t * 22.0)   # the ready pip pulses to draw the eye
			pip.visible = true
			pip.position = Vector2(facing * (13.0 + i * 11.0), -2.0)
			pip.scale = Vector2(facing * s, s)
			pip.modulate = CHARGE_PIP_COLORS[i]
		else:
			pip.visible = false


func _hide_charge_pips() -> void:
	for pip in _charge_pips:
		pip.visible = false


func _update_visual() -> void:
	if visual == null:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	# === Dead body — collapses aside (tips to lying-down and holds, not a spinning tumble) ===
	if not alive:
		var t_since_death: float = max(0.0, t - death_time)
		visual.frame = FighterArt.frame_for("fall", 0.8)   # tucked pose; rotated ~90° it reads as collapsed
		visual.rotation = clampf(death_spin_dir * t_since_death * DEATH_TOPPLE_RATE, -PI * 0.5, PI * 0.5)
		# Fade to clearly see-through — a translucent corpse reads as "non-solid, run through me".
		var alpha: float = clamp(1.0 - t_since_death * 0.5, 0.35, 1.0)
		visual.modulate = Color(0.6, 0.35, 0.40, alpha)
		visual.flip_h = false   # facing irrelevant while spinning
		if katana_sprite != null:
			katana_sprite.visible = false   # never leave a blade stuck on a corpse (died mid-swing)
		if slash_fx != null:
			slash_fx.stop()
		_hide_charge_pips()
		# Hearts/stash/katana belong to a LIVING ninja — hide them on the corpse here too
		# (belt-and-suspenders with the _process refresh) so a dead body can never display a
		# frozen heart row, regardless of which update path runs this frame.
		_update_hp_indicator()
		_update_stash_indicator()
		_update_katana_indicator()
		return
	var animation := "idle"
	var phase := fposmod(_motion_clock * 0.8, 1.0)
	if is_swinging:
		animation = "swing"
		phase = clampf((t - swing_start_t) / KATANA_SWING_DURATION_S, 0, 1)
	elif is_sliding or is_iframe:
		animation = "dodge"
		phase = fposmod(_motion_clock * 3.4, 1)
	elif t < throw_anim_until:
		animation = "throw"
		phase = 0.25 + 0.75 * (1.0 - clampf((throw_anim_until - t) / 0.22, 0, 1))
	elif is_aiming:
		animation = "throw"
		phase = 0.0
	elif is_defending or katana_charging:
		animation = "swing"
		phase = 0.0
	elif is_wall_grabbing:
		animation = "wall"
		phase = fposmod(_motion_clock, 1)
	elif not is_on_floor():
		animation = "rise" if velocity.y < -20 else "fall"
		phase = clampf(1.0 - absf(velocity.y) / 480.0, 0, 0.99) if animation == "rise" else clampf(velocity.y / 320.0, 0, 0.99)
	elif absf(velocity.x) > 15 and not is_defending:
		animation = "run"
		phase = fposmod(_motion_clock * 1.5, 1.0)
	visual.frame = FighterArt.frame_for(animation, phase)
	# === Modulate: NO dodge glow (the dodge reads from its pose/animation, TowerFall-style).
	# A brief red flash still marks a damage hit; otherwise the ninja stays its clan colour. ===
	if t < hurt_iframe_until:
		var hblink: bool = (int(t * 16.0) % 2 == 0)
		visual.modulate = Color(2.0, 0.55, 0.55, 1.0) if hblink else Color.WHITE
	else:
		visual.modulate = Color.WHITE
	visual.rotation = 0.0
	visual.flip_h = facing < 0
	if katana_sprite != null:
		katana_sprite.visible = is_swinging or is_defending or katana_charging
		katana_sprite.offset = Vector2(13, 0)
		katana_sprite.scale = Vector2(facing, 1)
		if is_swinging:
			var progress := clampf((t - swing_start_t) / KATANA_SWING_DURATION_S, 0, 1)
			var hand := FighterArt.sword_hand(progress)
			katana_sprite.position = Vector2(hand.x * facing, hand.y)
			katana_sprite.rotation = FighterArt.sword_angle(progress) * facing
			_ensure_slash_fx()
			slash_fx.play(progress, facing)
		else:
			katana_sprite.position = Vector2(facing * 9, 2)
			katana_sprite.rotation = deg_to_rad(-85) * facing
			if slash_fx != null:
				slash_fx.stop()
	# Blade-wave charge tell: the 1→3 coloured wave pips in front of the fighter.
	_update_charge_pips(t)
	# Above-head indicators are refreshed in _process (every rendered frame, after all
	# physics mutations), so HP / stash / katana counts can't lag behind a hit, catch,
	# pickup or stomp that another node applied this frame.

# Refresh the above-head HP / stash / katana icons every rendered frame. Done in _process
# (not _physics_process) so the counts reflect the latest values even when another node
# (a shuriken catch/pickup, the opponent's stomp/katana) changed them this physics step.
func _process(_delta: float) -> void:
	if GameState.is_round_active():
		_motion_clock += _delta
	_update_hp_indicator()
	_update_stash_indicator()
	_update_katana_indicator()
	_update_guard_indicator()

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

# Guard meter bar: width tracks remaining guard, cyan when usable and red while broken/refilling.
func _update_guard_indicator() -> void:
	if guard_bar_fill == null:
		return
	guard_bar_bg.visible = alive
	guard_bar_fill.visible = alive
	if not alive:
		return
	var frac: float = clampf(guard_meter / GUARD_MAX_S, 0.0, 1.0)
	guard_bar_fill.size.x = GUARD_BAR_W * frac
	var on_cooldown: bool = Time.get_ticks_msec() / 1000.0 < guard_cooldown_until
	guard_bar_fill.color = Color(0.9, 0.35, 0.3, 0.95) if on_cooldown else Color(0.4, 0.8, 1.0, 0.95)
