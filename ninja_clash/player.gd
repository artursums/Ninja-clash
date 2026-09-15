## Fighter simulation: movement, combat and loadout state. Presentation reads this state.

extends CharacterBody2D

const Perks := preload("res://perk_rules.gd")

var presentation := preload("res://fighter_presentation.gd").new(self)

var perk_kind: int = Perks.Kind.NONE
var perk_charges := 0
var perk_icon_anchor := Vector2.ZERO
var reverse_left := 0.0
var teleport_revision := 0

const Parry := preload("res://katana_parry.gd")

const Arena := preload("res://arena_rules.gd")

const TUNING_PATH := "res://player_tuning.tres"
var tuning: PlayerTuning = null
const BOT_TUNING_PATH := "res://bot_tuning.tres"
var bot_tuning: BotTuning = null

var MAX_HSPEED := 200.38
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
var SLIDE_MAX_UP_SPEED := 282.8427124746191
var SLIDE_COOLDOWN_S := 0.417
var SLIDE_AIR_REFRESH_S := 0.5
var WALL_JUMP_VSTRENGTH := 540.0
var WALL_JUMP_HKICK := 200.0
var WALL_JUMP_LOCK_S := 0.10
const PLAYER_W := 20.0
const PLAYER_H := 32.0

var MAX_HP := 5
var MAX_KATANA := 3
var HURT_IFRAME_S := 0.35
var KATANA_SWING_DURATION_S := 0.32
var KATANA_COOLDOWN_S := 0.2
var KATANA_HIT_START_S := 0.05
var KATANA_HIT_END_S := 0.22
var KATANA_RANGE := 30.0
var KATANA_HALF_H := 18.0

const KATANA_HIT_BODY_FRAC := 0.6
var KATANA_VISUAL_SCALE := 1.0
var KATANA_HIT_KNOCKBACK := 150.0
var KATANA_HIT_POP := 70.0
var KATANA_HIT_RECOIL_S := 0.10

var BLADE_WAVE_CHARGE_TIME_S := 3.0
var BLADE_WAVE_SPEED := 340.0
var BLADE_WAVE_DAMAGE := 1
var BLADE_WAVE_LIFETIME_S := 2.5

var BLOCK_RECOIL_SPEED := 155.0
var BLOCK_RECOIL_POP := 55.0
var BLOCK_RECOIL_S := 0.12
var SHIELD_BUMP_SPEED := 175.0
var SHIELD_BUMP_POP := 45.0
var SHIELD_BUMP_S := 0.14
var SHIELD_BUMP_RANGE := 24.0
var SHIELD_BUMP_VRANGE := 28.0

var GUARD_MAX_S := 4.0
var GUARD_COOLDOWN_S := 5.0

var slot: int = 1
var spawn_pos: Vector2 = Vector2.ZERO

var facing: int = 1
var stash: int = 3
var hp: int = 5
var katana_charges: int = 3
var alive: bool = true
var is_iframe: bool = false
var is_sliding: bool = false
var is_wall_grabbing: bool = false
var is_swinging: bool = false
var is_defending: bool = false
var is_aiming: bool = false
var aim_dir: Vector2 = Vector2.RIGHT
var _aim_locked_dir: Vector2 = Vector2.ZERO
var swing_start_t: float = -999.0
var katana_cooldown_until: float = -999.0
var swing_hit_done: bool = false
var katana_charging: bool = false
var katana_charge_ready: bool = false
var katana_press_t: float = -999.0
var hurt_iframe_until: float = 0.0
var jumps_remaining: int = 1
var iframe_t_end: float = 0.0
var slide_t_end: float = 0.0
var slide_dir: Vector2 = Vector2.ZERO
var slide_charged: bool = true
var slide_cooldown_until: float = 0.0
var air_dash_penalty: bool = false
var wall_jump_lock_until: float = -999.0
var stomp_cooldown_until: float = -999.0
var stomp_bounce_lock_until: float = -999.0
var clash_recoil_until: float = 0.0
var hit_recoil_until: float = 0.0
var shield_bump_until: float = 0.0
var guard_meter: float = 4.0
var guard_cooldown_until: float = 0.0
var frozen_until: float = 0.0
var throw_anim_until: float = 0.0
var death_time: float = -1.0
var death_spin_dir: int = 0
var _first_tick_done: bool = false

var net_target_pos: Vector2 = Vector2.ZERO
var net_has_target: bool = false
const PUPPET_SNAP_DIST := 90.0
const PUPPET_BLEND := 0.35

const BotLogic := preload("res://bot_logic.gd")

const BotBrain := preload("res://bot_brain.gd")
var is_bot := false
var bot_difficulty := 1
var _bot_held: Dictionary = {}
var _bot_pressed: Dictionary = {}
var _bot_throw_dir := Vector2.RIGHT
var _bot_brain: RefCounted

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

var visual: Sprite2D = null

var stash_icons: Array = []
var heart_icons: Array = []
var katana_icons: Array = []
var guard_bar_bg: ColorRect = null
var guard_bar_fill: ColorRect = null
const GUARD_BAR_W := 26.0
var katana_sprite: Sprite2D = null
var slash_fx: Node2D = null

signal stash_changed(slot: int, new_count: int)

var _spawn_collision_layer: int = 1
var _corpse_settled: bool = false

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
	add_child(preload("res://perk_badge.gd").new())
	_apply_tuning()
	_spawn_collision_layer = collision_layer
	var prefix = "p%d" % slot
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

	stash_changed.connect(func(_s: int, _n: int): presentation.update_stash_indicator())
	print("[PLAYER ", slot, "] _ready. visual=", visual != null)

# Guests interpolate host state; only the host and offline simulation resolve combat.
func _physics_process(delta: float) -> void:
	if not _first_tick_done:
		_first_tick_done = true
		print("[PLAYER ", slot, "] first tick. pos=", position, " on_floor=", is_on_floor())

	if Net.is_client():
		_puppet_tick(delta)
		return

	if not alive:
		_hide_reticle()
		is_swinging = false
		is_defending = false
		if _corpse_settled:
			velocity = Vector2.ZERO
			presentation.update_visual()
			return
		velocity.y += GRAVITY * delta
		if velocity.y > PLAYER_TERMINAL_FALL_SPEED:
			velocity.y = PLAYER_TERMINAL_FALL_SPEED
		velocity.x = move_toward(velocity.x, 0.0, 220.0 * delta)
		move_and_slide()
		if is_on_floor():
			_corpse_settled = true
			velocity = Vector2.ZERO
		_check_screen_wrap()
		presentation.update_visual()
		return

	if not GameState.is_round_active():
		_hide_reticle()
		is_swinging = false
		is_defending = false
		velocity.x = 0.0

		velocity.y = min(velocity.y + 600.0 * delta, 400.0)
		move_and_slide()

		if GameState.current_state == GameState.State.MATCH_INTRO and spawn_pos != Vector2.ZERO:
			position.x = spawn_pos.x
		presentation.update_visual()
		return
	var t: float = Time.get_ticks_msec() / 1000.0

	reverse_left = maxf(0, reverse_left - delta)

	if t < frozen_until:
		presentation.update_visual()
		return

	if is_iframe and t >= iframe_t_end:
		is_iframe = false
	if is_sliding and t >= slide_t_end:
		is_sliding = false

	if is_bot:
		_bot_think(t)

	if is_bot:
		if _pressed(input_throw) and available_shurikens() > 0:
			_throw_shuriken(_throw_aim())
	else:
		if not is_aiming and _pressed(input_throw) and available_shurikens() > 0 and not _held(input_defend):
			is_aiming = true
			aim_dir = _throw_aim()
			_relock_aim()
		if is_aiming:
			if _held(input_throw):
				var new_aim: Vector2 = _throw_aim()
				if new_aim != aim_dir:
					aim_dir = new_aim
					_relock_aim()

			else:

				is_aiming = false
				if available_shurikens() > 0:
					_throw_shuriken(aim_dir)
	presentation.update_aim_reticle()

	var move: float = 0.0
	if _held(input_left):
		move -= 1.0
	if _held(input_right):
		move += 1.0

	move = movement_axis(move)

	var on_floor_now := is_on_floor()
	var on_wall_now := is_on_wall() and not on_floor_now
	var wall_normal: Vector2 = get_wall_normal() if on_wall_now else Vector2.ZERO

	if on_floor_now:
		jumps_remaining = 1

	if not is_sliding:
		if on_floor_now and air_dash_penalty:
			slide_charged = true
			slide_cooldown_until = 0.0
			air_dash_penalty = false
		elif on_floor_now or on_wall_now:
			if air_dash_penalty:
				slide_cooldown_until = maxf(slide_cooldown_until, t + SLIDE_AIR_REFRESH_S)
				air_dash_penalty = false
			if t >= slide_cooldown_until:
				slide_charged = true

	is_wall_grabbing = false
	if on_wall_now and move != 0.0:
		if sign(move) == -sign(wall_normal.x):
			is_wall_grabbing = true

	if move != 0.0 and not is_sliding:
		facing = int(sign(move))

	is_defending = _held(input_defend) and not is_swinging and not is_sliding \
		and not is_aiming and not is_wall_grabbing \
		and guard_meter > 0.0 and t >= guard_cooldown_until

	if is_defending:
		guard_meter = maxf(0.0, guard_meter - delta)
		if guard_meter <= 0.0:
			guard_cooldown_until = t + GUARD_COOLDOWN_S
			Audio.play("hit")
	elif t < guard_cooldown_until:
		guard_meter = GUARD_MAX_S * clampf(1.0 - (guard_cooldown_until - t) / GUARD_COOLDOWN_S, 0.0, 1.0)

	if is_sliding:

		velocity = _dash_velocity()
	elif t < clash_recoil_until:
		pass
	elif t < hit_recoil_until:
		pass
	elif t < shield_bump_until:
		pass
	elif t < stomp_bounce_lock_until:
		pass
	elif is_defending:
		velocity.x = move * MAX_HSPEED
	elif t < wall_jump_lock_until:
		pass
	else:
		velocity.x = move * MAX_HSPEED

	if not is_sliding:
		velocity.y += GRAVITY * delta

		if velocity.y > PLAYER_TERMINAL_FALL_SPEED:
			velocity.y = PLAYER_TERMINAL_FALL_SPEED

	if is_wall_grabbing and velocity.y > Combat.wall_grab_fall_speed:
		velocity.y = Combat.wall_grab_fall_speed

	if _pressed(input_jump):
		if on_wall_now and not on_floor_now:
			velocity.y = -WALL_JUMP_VSTRENGTH
			velocity.x = wall_normal.x * WALL_JUMP_HKICK
			facing = int(sign(wall_normal.x))
			wall_jump_lock_until = t + WALL_JUMP_LOCK_S
			is_wall_grabbing = false
			jumps_remaining = 0

			presentation.spawn_dust(Vector2(global_position.x, global_position.y + PLAYER_H / 2.0), "jump", -signf(wall_normal.x))
		elif jumps_remaining > 0:
			velocity.y = -JUMP_STRENGTH
			jumps_remaining -= 1

			presentation.spawn_dust(Vector2(global_position.x, global_position.y + PLAYER_H / 2.0), "jump", -float(facing))

	var dash_requested: bool = not is_defending and (_pressed(input_slide) or _pressed(input_dodge))

	if dash_requested and not is_sliding and not is_defending and slide_charged:
		slide_charged = false
		slide_cooldown_until = t + SLIDE_COOLDOWN_S
		air_dash_penalty = not (on_floor_now or on_wall_now)
		var dash_direction := _aim_direction()
		if _held(input_left) or _held(input_right):
			dash_direction.x = movement_axis(dash_direction.x)
		_start_slide(dash_direction, t)

	if MatchConfig.blade_wave_enabled:
		_update_katana_charge_input(t)
	elif _pressed(input_katana) and not is_swinging and not is_defending and katana_charges > 0 and t >= katana_cooldown_until:
		_start_swing(t)
	if is_swinging:
		_process_swing(t)
		if t - swing_start_t >= KATANA_SWING_DURATION_S:
			is_swinging = false

	_check_shield_bump(t)

	var was_falling: bool = velocity.y > 50.0
	move_and_slide()
	if was_falling:
		_check_headstomp()
	presentation.update_movement_dust(t, was_falling)
	_check_screen_wrap()
	presentation.update_visual()

func _puppet_tick(delta: float) -> void:
	if not alive:
		_hide_reticle()
		if net_has_target:
			position = net_target_pos
		presentation.update_visual()
		return
	if not is_sliding:
		velocity.y += GRAVITY * delta
		velocity.y = minf(velocity.y, PLAYER_TERMINAL_FALL_SPEED)
	move_and_slide()
	if net_has_target:
		if position.distance_to(net_target_pos) > PUPPET_SNAP_DIST:
			position = net_target_pos
		else:
			position = position.lerp(net_target_pos, PUPPET_BLEND)
	_check_screen_wrap()
	presentation.update_aim_reticle()
	presentation.update_visual()

func _start_slide(dir: Vector2, t: float) -> void:
	is_sliding = true
	slide_dir = dir
	is_iframe = true
	iframe_t_end = t + Combat.dodge_iframe_duration_s
	if dir.x != 0.0:
		facing = int(sign(dir.x))
	slide_t_end = t + SLIDE_DURATION_S
	velocity = _dash_velocity()
	Audio.play("dodge")

func _dash_velocity() -> Vector2:
	var v: Vector2 = slide_dir * SLIDE_SPEED
	if v.y < -SLIDE_MAX_UP_SPEED:
		v.y = -SLIDE_MAX_UP_SPEED
	return v

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
		return Vector2(hx, vy)
	if vy != 0:
		return Vector2(0, vy)
	return Vector2(facing, 0)

const AIM_SNAP_HALF_ANGLE_DEG := 26.0
const AIM_SNAP_RANGE := 640.0

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
		if not _has_clear_shot(p):
			continue
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		return base_dir
	return (best.global_position - global_position).normalized()

func _has_clear_shot(target: Node2D) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, target.global_position)
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or not (hit.collider is StaticBody2D)

func _relock_aim() -> void:
	var d: Vector2 = aim_dir
	if d == Vector2.ZERO:
		d = Vector2(facing, 0)
	_aim_locked_dir = _aim_assist_dir(d.normalized())

const RETICLE_DIST := 24.0

func _hide_reticle() -> void:
	is_aiming = false
	presentation.hide_reticle()

func _held(action: String) -> bool:
	if is_bot:
		return _bot_held.get(action, false)
	return PlayerInput.held(action)

func _pressed(action: String) -> bool:
	if is_bot:
		return _bot_pressed.get(action, false)
	return PlayerInput.pressed(action)

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
	return BotLogic.should_stomp(available_shurikens(), katana_charges, scavengeable)

func _start_swing(t: float) -> void:
	Combat.record(slot, "strikes")
	is_swinging = true
	swing_start_t = t
	swing_hit_done = false
	katana_cooldown_until = t + KATANA_SWING_DURATION_S + KATANA_COOLDOWN_S
	Audio.play("dodge")

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
			Audio.play("dodge")
		return

	if katana_charge_ready:
		_fire_blade_wave(t)
	elif t >= katana_cooldown_until:
		_start_swing(t)
	katana_charging = false
	katana_charge_ready = false

func _fire_blade_wave(t: float) -> void:
	if katana_charges <= 0:
		return
	Combat.record(slot, "strikes")
	var dir: Vector2 = _throw_aim().normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)
	if dir.x != 0.0:
		facing = int(signf(dir.x))
	katana_charges -= 1
	presentation.update_katana_indicator()
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
	presentation.hide_charge_pips()

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

	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		if _box_hits_body(p.global_position, hb_center, hb_half) and _is_clashing_with(p):
			swing_hit_done = true
			Combat.register_clash(self, p)
			return

	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive:
			continue
		if not _box_hits_body(p.global_position, hb_center, hb_half):
			continue
		var impact: Vector2 = Vector2(facing * 220.0, -80.0)
		if p.is_guarding_against(impact):

			swing_hit_done = true
			p._on_block(impact)
			apply_block_recoil()
			presentation.spawn_clash_burst((global_position + p.global_position) * 0.5)
		elif katana_charges > 0 and p.take_damage(1, impact, slot):
			katana_charges -= 1
			presentation.update_katana_indicator()
			swing_hit_done = true
			presentation.spawn_strike_flash(p.global_position)
			if p.alive and p.has_method("apply_hit_recoil"):
				p.apply_hit_recoil(facing)
		break

func _point_in_box(point: Vector2, center: Vector2, half: Vector2) -> bool:
	return absf(point.x - center.x) <= half.x and absf(point.y - center.y) <= half.y

func _box_hits_body(body_center: Vector2, hb_center: Vector2, hb_half: Vector2) -> bool:
	return absf(hb_center.x - body_center.x) <= hb_half.x + PLAYER_W * 0.5 * KATANA_HIT_BODY_FRAC \
		and absf(hb_center.y - body_center.y) <= hb_half.y + PLAYER_H * 0.5 * KATANA_HIT_BODY_FRAC

func _is_clashing_with(other) -> bool:
	if not other.is_swinging or other.swing_hit_done:
		return false
	var ohb_center: Vector2 = other.global_position + Vector2(other.facing * KATANA_RANGE * 0.5, 0.0)
	var ohb_half: Vector2 = Vector2(KATANA_RANGE * 0.5 + 4.0, KATANA_HALF_H)
	return _box_hits_body(global_position, ohb_center, ohb_half)

func apply_clash_recoil(dir_x: int) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	swing_hit_done = true
	velocity.x = float(dir_x) * Combat.clash_recoil_speed
	velocity.y = -Combat.clash_recoil_up
	clash_recoil_until = t + Combat.clash_freeze_duration_s + Combat.clash_recoil_duration_s

func apply_hit_recoil(push_dir: int) -> void:
	velocity.x = float(push_dir) * KATANA_HIT_KNOCKBACK
	velocity.y = minf(velocity.y, -KATANA_HIT_POP)
	hit_recoil_until = Time.get_ticks_msec() / 1000.0 + KATANA_HIT_RECOIL_S

func is_guarding_against(impact_velocity: Vector2) -> bool:
	return _blocks_incoming(impact_velocity)

func apply_block_recoil() -> void:
	velocity.x = float(-facing) * BLOCK_RECOIL_SPEED
	velocity.y = minf(velocity.y, -BLOCK_RECOIL_POP)
	hit_recoil_until = Time.get_ticks_msec() / 1000.0 + BLOCK_RECOIL_S

func _check_shield_bump(t: float) -> void:
	if not is_defending or not alive or t < shield_bump_until:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not p.alive or not p.is_defending or slot >= p.slot:
			continue
		var dx: float = p.global_position.x - global_position.x
		if absf(dx) > SHIELD_BUMP_RANGE or absf(p.global_position.y - global_position.y) > SHIELD_BUMP_VRANGE:
			continue
		var dir: int = 1 if dx >= 0.0 else -1
		apply_shield_bump(-dir, t)
		p.apply_shield_bump(dir, t)
		presentation.spawn_clash_burst((global_position + p.global_position) * 0.5)
		Audio.play("block")
		return

func apply_shield_bump(dir_x: int, t: float) -> void:
	velocity.x = float(dir_x) * SHIELD_BUMP_SPEED
	velocity.y = minf(velocity.y, -SHIELD_BUMP_POP)
	shield_bump_until = t + SHIELD_BUMP_S
	facing = -dir_x

func _throw_shuriken(aim: Vector2) -> void:
	if available_shurikens() == 0:
		return
	var ShurikenScript: Script = load("res://shuriken.gd")
	var s = Area2D.new()
	s.set_script(ShurikenScript)
	s.thrower_slot = slot
	s.perk_kind = consume_perk()
	var v: float = Combat.shuriken_throw_velocity
	var spawn_offset: Vector2
	var vel: Vector2
	if aim.x != 0.0 and aim.y != 0.0:

		var dir: Vector2 = aim.normalized()
		vel = dir * v
		spawn_offset = dir * 18.0
		facing = int(signf(aim.x))
	elif aim.y != 0.0:

		var sgn: float = signf(aim.y)
		spawn_offset = Vector2(0.0, sgn * 22.0)
		vel = Vector2(0.0, sgn * v)
	else:

		var hdir: int = int(signf(aim.x)) if aim.x != 0.0 else facing
		spawn_offset = Vector2(hdir * 16.0, -4.0)
		vel = Vector2(hdir * v, -30.0)
		facing = hdir

	if not is_bot and _aim_locked_dir != Vector2.ZERO and not _aim_locked_dir.is_equal_approx(aim.normalized()):
		vel = _aim_locked_dir * v
		spawn_offset = _aim_locked_dir * 16.0
		if _aim_locked_dir.x != 0.0:
			facing = int(signf(_aim_locked_dir.x))
	s.position = global_position + spawn_offset

	if vel.x == 0.0 and vel.y > 0.0:
		vel.y = DOWN_THROW_SPEED
		s.max_fall = DOWN_THROW_SPEED

		if not is_on_floor():
			velocity.y = minf(velocity.y, -SHURIKEN_THROW_RECOIL)
	s.velocity_v = vel
	s.throw_time = Time.get_ticks_msec() / 1000.0
	get_parent().add_child(s)
	Combat.record(slot, "throws")
	# Special ammunition is independent of the ordinary stash.
	if s.perk_kind == Perks.Kind.NONE and not MatchConfig.infinite_shurikens:
		stash -= 1
		stash_changed.emit(slot, stash)
	Audio.play("throw")
	throw_anim_until = Time.get_ticks_msec() / 1000.0 + 0.22

func _try_katana_parry(shuriken, t: float) -> bool:
	if not alive or not is_swinging or shuriken.stuck or shuriken.consumed or shuriken.puppet or (shuriken.thrower_slot == slot and not shuriken.can_hit_owner()):
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
	presentation.spawn_strike_flash(shuriken.global_position)
	return true

func hit_by_shuriken(shuriken) -> bool:
	if _try_katana_parry(shuriken, Time.get_ticks_msec() / 1000.0):
		return false
	if not alive:
		return false

	if shuriken.ricocheted:
		if stash < 5:
			stash += 1
			stash_changed.emit(slot, stash)
			Audio.play("catch")
			return true
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	if shuriken.thrower_slot == slot and (t - shuriken.throw_time) < Combat.self_hit_immunity_s:
		return false
	if is_iframe:

		if stash < 5:
			stash += 1
			stash_changed.emit(slot, stash)
			Audio.play("catch")
			return true
		else:
			shuriken.velocity_v = -shuriken.velocity_v
			shuriken.stuck = false
			return false

	if shuriken.thrower_slot == slot and not shuriken.can_hit_owner():
		if velocity.y > 0.0 and not shuriken.stuck and shuriken.global_position.y >= global_position.y:
			velocity.y = -SHURIKEN_POGO_BOUNCE
			Audio.play("dodge")
		return false
	if t < hurt_iframe_until:
		return false
	if _blocks_incoming(shuriken.velocity_v):

		shuriken.deflect(slot, facing)
		_on_block(shuriken.velocity_v)
		return false

	if shuriken.perk_kind == Perks.Kind.SWAP:
		for other in get_tree().get_nodes_in_group("players"):
			if other.slot == shuriken.thrower_slot and other.alive:
				swap_with(other)
				break
		return true
	var damaged := take_damage(1, shuriken.velocity_v, shuriken.thrower_slot)
	if damaged and alive and shuriken.perk_kind == Perks.Kind.MISDIRECTION and reverse_left <= 0:
		reverse_left = Perks.REVERSE_SECONDS
	return true

func _blocks_incoming(impact_velocity: Vector2) -> bool:
	if not is_defending:
		return false
	var hx: float = signf(impact_velocity.x)
	return hx != 0.0 and int(hx) == -facing

func _on_block(_impact_velocity: Vector2) -> void:
	Combat.record(slot, "blocks")
	Audio.play("block")
	presentation.spawn_strike_flash(global_position + Vector2(facing * 12.0, -2.0))

func take_damage(amount: int, impact_velocity: Vector2, killer_slot: int = 0) -> bool:
	if not alive:
		return false
	if _blocks_incoming(impact_velocity):
		_on_block(impact_velocity)
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

		if impact_velocity.length_squared() > 1.0:
			velocity += impact_velocity.normalized() * 130.0
			velocity.y -= 50.0
	presentation.update_hp_indicator()
	return true

func hit_by_stomp(stomper) -> bool:
	if not alive:
		return false
	var t: float = Time.get_ticks_msec() / 1000.0
	if not is_iframe and t >= hurt_iframe_until:
		take_damage(1, Vector2(0.0, 400.0), stomper.slot)
	else:
		Audio.play("dodge")
	return true

func _check_headstomp() -> void:
	if not alive:
		return

	if is_bot and not _bot_should_stomp():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < stomp_cooldown_until:
		return
	for i in get_slide_collision_count():
		var coll: KinematicCollision2D = get_slide_collision(i)
		var other = coll.get_collider()
		if other == null or other == self:
			continue
		if not (other is CharacterBody2D) or not other.has_method("hit_by_stomp"):
			continue

		if coll.get_normal().y < -0.5:
			if other.hit_by_stomp(self):

				velocity.y = -STOMP_BOUNCE_STRENGTH
				var away: float = signf(global_position.x - other.global_position.x)
				if away == 0.0:
					away = float(facing)
				velocity.x = away * STOMP_BOUNCE_SIDEWAYS
				facing = int(away)
				stomp_bounce_lock_until = t + STOMP_BOUNCE_LOCK_S
				stomp_cooldown_until = t + STOMP_COOLDOWN_S
				break

func _die(impact_velocity: Vector2 = Vector2.ZERO, killer_slot: int = 0, credit_kill: bool = true) -> void:
	clear_perks()
	alive = false

	collision_layer = 0
	presentation.update_hp_indicator()

	if impact_velocity.length_squared() > 1.0:
		velocity = Vector2(signf(impact_velocity.x) * DEATH_KNOCKBACK, -30.0)
		death_spin_dir = -1 if impact_velocity.x < 0.0 else 1
	else:
		velocity = Vector2.ZERO
		death_spin_dir = 1
	death_time = Time.get_ticks_msec() / 1000.0
	stash_changed.emit(slot, stash)
	if credit_kill:
		Combat.on_kill(slot, killer_slot)

func respawn(at_pos: Vector2) -> void:
	clear_perks()
	alive = true
	collision_layer = _spawn_collision_layer
	_corpse_settled = false
	position = at_pos
	spawn_pos = at_pos
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
	if _bot_brain != null:
		_bot_brain.reset()
	_bot_held.clear()
	_bot_pressed.clear()

	stash = MatchConfig.effective_start_shurikens()
	hp = MatchConfig.max_hp

	if not MatchConfig.katana_enabled:
		katana_charges = 0
	elif MatchConfig.katana_recharge or GameState.current_round == 1:
		katana_charges = MatchConfig.katana_charges

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
	stash_changed.emit(slot, stash)
	presentation.update_hp_indicator()
	presentation.update_katana_indicator()

func _check_screen_wrap() -> void:
	position = Arena.wrap_position(position)

# Refresh indicators after all physics mutations, including hits from other nodes.
func _process(_delta: float) -> void:
	if Net.is_client() and GameState.is_round_active():
		reverse_left = maxf(0, reverse_left - _delta)
	presentation.advance(_delta)

func movement_axis(value: float) -> float:
	return -value if reverse_left > 0 else value

func grant_perk(kind: int) -> bool:
	if not alive or perk_kind != Perks.Kind.NONE or kind < 1 or kind >= Perks.CHARGES.size():
		return false
	perk_kind = kind
	perk_charges = Perks.CHARGES[kind]
	return true

func available_shurikens() -> int:
	return maxi(0, stash) + perk_charges

func consume_perk() -> int:
	var kind := perk_kind
	if perk_charges > 0:
		perk_charges -= 1
	if perk_charges == 0:
		perk_kind = Perks.Kind.NONE
	return kind

func clear_perks() -> void:
	perk_kind = Perks.Kind.NONE
	perk_charges = 0
	reverse_left = 0

func swap_with(other: CharacterBody2D) -> bool:
	if other == self or not alive or not other.alive:
		return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,32)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.exclude = [get_rid(),other.get_rid()]
	var bounds := Rect2(Vector2.ZERO,preload("res://arena_rules.gd").SIZE)
	for at: Vector2 in [global_position,other.global_position]:
		if not bounds.encloses(Rect2(at-Vector2(10,16),Vector2(20,32))):
			return false
		query.transform = Transform2D(0,at)
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			return false
	var previous := global_position
	global_position = other.global_position
	other.global_position = previous
	for p in [self,other]:
		p.velocity = Vector2.ZERO
		p.is_sliding = false
		p.is_wall_grabbing = false
		p.is_iframe = false
		p.wall_jump_lock_until = 0
		p.clash_recoil_until = 0
		p.hit_recoil_until = 0
		p.shield_bump_until = 0
		p.jumps_remaining = 0
		p.teleport_revision += 1
		if p._bot_brain != null:
			p._bot_brain.reset()
	Audio.play("dodge")
	return true
