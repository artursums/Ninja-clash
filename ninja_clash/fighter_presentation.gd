## Animation, indicators and effects for an injected fighter; never resolves combat.

extends RefCounted

var actor: CharacterBody2D
var _reticle: Node2D = null
var _charge_pips: Array = []
var _motion_clock := 0.0
var _was_on_floor: bool = false
var _next_run_dust_t: float = 0.0
const BLADE_WAVE_TELL_SHEET := "res://sprites/fx/katana_slash_5frame_native_400x80.png"
const CHARGE_PIP_COLORS := [
	Color(0.45, 0.75, 1.0),
	Color(1.0, 0.82, 0.25),
	Color(1.0, 0.30, 0.18),
]
const DUST_FEET_OFFSET := 16.0
const DUST_BODY_HALF := 11.0
const DUST_SCALE := 0.7
const RUN_DUST_INTERVAL_S := 0.16
const RUN_DUST_MIN_HSPEED := 40.0
const FighterArt := preload("res://fighter_art.gd")
const Perks := preload("res://perk_rules.gd")

func _init(fighter: CharacterBody2D) -> void:
	actor = fighter

func advance(delta: float) -> void:
	if GameState.is_round_active():
		_motion_clock += delta
	update_hp_indicator()
	update_stash_indicator()
	update_katana_indicator()
	update_guard_indicator()

func hide_reticle() -> void:
	if _reticle != null:
		_reticle.hide()

func ensure_reticle() -> void:
	if _reticle != null:
		return
	_reticle = Node2D.new()
	_reticle.z_index = 70
	_reticle.visible = false
	actor.add_child(_reticle)
	var col: Color = Color(GameState.get_clan(actor.slot).color)

	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-4, -5), Vector2(8, 0), Vector2(-4, 5), Vector2(0, 0)])
	var outline := Polygon2D.new()
	outline.polygon = pts
	outline.color = Color(0.04, 0.03, 0.07, 0.85)
	outline.scale = Vector2(1.35, 1.35)
	_reticle.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(col.r, col.g, col.b, 0.95)
	_reticle.add_child(fill)

func update_aim_reticle() -> void:
	if not actor.is_aiming:
		if _reticle != null:
			_reticle.visible = false
		return
	ensure_reticle()

	var dir: Vector2 = actor._aim_locked_dir
	if dir == Vector2.ZERO:
		dir = actor.aim_dir.normalized() if actor.aim_dir != Vector2.ZERO else Vector2(actor.facing, 0)
	_reticle.position = dir * actor.RETICLE_DIST
	_reticle.rotation = dir.angle()
	_reticle.visible = true

func ensure_slash_fx() -> void:
	if actor.slash_fx != null and is_instance_valid(actor.slash_fx):
		return
	actor.slash_fx = load("res://slash_fx.gd").new()
	actor.add_child(actor.slash_fx)
	var clan: Dictionary = GameState.get_clan(actor.slot)
	actor.slash_fx.set_tint(clan.get("secondary", Color(0.7, 0.9, 1.0)))

func ensure_charge_pips() -> void:
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
			pip.frame = 2
		pip.centered = true
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pip.z_index = 56
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		pip.material = mat
		pip.visible = false
		actor.add_child(pip)
		_charge_pips.append(pip)

func update_charge_pips(t: float) -> void:
	if not actor.katana_charging or not actor.alive or not GameState.is_round_active():
		hide_charge_pips()
		return
	ensure_charge_pips()
	var progress: float = clampf((t - actor.katana_press_t) / maxf(actor.BLADE_WAVE_CHARGE_TIME_S, 0.001), 0.0, 1.0)
	var shown: int = 1
	if actor.katana_charge_ready:
		shown = 3
	elif progress >= 0.5:
		shown = 2
	for i in _charge_pips.size():
		var pip: Sprite2D = _charge_pips[i]
		if i < shown:
			var s: float = 0.42
			if i == 2 and actor.katana_charge_ready:
				s *= 0.9 + 0.16 * sin(t * 22.0)
			pip.visible = true
			pip.position = Vector2(actor.facing * (13.0 + i * 11.0), -2.0)
			pip.scale = Vector2(actor.facing * s, s)
			pip.modulate = CHARGE_PIP_COLORS[i]
		else:
			pip.visible = false

func hide_charge_pips() -> void:
	for pip in _charge_pips:
		pip.visible = false

func update_visual() -> void:
	if actor.visual == null:
		return
	var t: float = Time.get_ticks_msec() / 1000.0

	if not actor.alive:
		var t_since_death: float = max(0.0, t - actor.death_time)
		actor.visual.frame = FighterArt.frame_for("fall", 0.8)
		actor.visual.rotation = clampf(actor.death_spin_dir * t_since_death * actor.DEATH_TOPPLE_RATE, -PI * 0.5, PI * 0.5)

		var alpha: float = clamp(1.0 - t_since_death * 0.5, 0.35, 1.0)
		actor.visual.modulate = Color(0.6, 0.35, 0.40, alpha)
		actor.visual.flip_h = false
		if actor.katana_sprite != null:
			actor.katana_sprite.visible = false
		if actor.slash_fx != null:
			actor.slash_fx.stop()
		hide_charge_pips()

		update_hp_indicator()
		update_stash_indicator()
		update_katana_indicator()
		return
	var animation := "idle"
	var phase := fposmod(_motion_clock * 0.8, 1.0)
	if actor.is_swinging:
		animation = "swing"
		phase = clampf((t - actor.swing_start_t) / actor.KATANA_SWING_DURATION_S, 0, 1)
	elif actor.is_sliding or actor.is_iframe:
		animation = "dodge"
		phase = fposmod(_motion_clock * 3.4, 1)
	elif t < actor.throw_anim_until:
		animation = "throw"
		phase = 0.25 + 0.75 * (1.0 - clampf((actor.throw_anim_until - t) / 0.22, 0, 1))
	elif actor.is_aiming:
		animation = "throw"
		phase = 0.0
	elif actor.is_defending or actor.katana_charging:
		if actor.is_defending and actor.is_on_floor() and absf(actor.velocity.x) > 15:
			animation = "guard_run"
			phase = fposmod(_motion_clock * 1.5, 1.0)
		else:
			animation = "swing"
			phase = 0.0
	elif actor.is_wall_grabbing:
		animation = "wall"
		phase = fposmod(_motion_clock, 1)
	elif not actor.is_on_floor():
		animation = "rise" if actor.velocity.y < -20 else "fall"
		phase = clampf(1.0 - absf(actor.velocity.y) / 480.0, 0, 0.99) if animation == "rise" else clampf(actor.velocity.y / 320.0, 0, 0.99)
	elif absf(actor.velocity.x) > 15 and not actor.is_defending:
		animation = "run"
		phase = fposmod(_motion_clock * 1.5, 1.0)
	actor.visual.frame = FighterArt.frame_for(animation, phase)

	if t < actor.hurt_iframe_until:
		var hblink: bool = (int(t * 16.0) % 2 == 0)
		actor.visual.modulate = Color(2.0, 0.55, 0.55, 1.0) if hblink else Color.WHITE
	else:
		actor.visual.modulate = Color.WHITE
	actor.visual.rotation = 0.0
	actor.visual.flip_h = actor.facing < 0
	if actor.katana_sprite != null:
		actor.katana_sprite.visible = actor.is_swinging or actor.is_defending or actor.katana_charging
		actor.katana_sprite.offset = Vector2(13, 0)
		actor.katana_sprite.scale = Vector2(actor.facing, 1)
		if actor.is_swinging:
			var progress := clampf((t - actor.swing_start_t) / actor.KATANA_SWING_DURATION_S, 0, 1)
			var hand := FighterArt.sword_hand(progress)
			actor.katana_sprite.position = Vector2(hand.x * actor.facing, hand.y)
			actor.katana_sprite.rotation = FighterArt.sword_angle(progress) * actor.facing
			ensure_slash_fx()
			actor.slash_fx.play(progress, actor.facing)
		else:
			actor.katana_sprite.position = Vector2(actor.facing * 9, 2)
			actor.katana_sprite.rotation = deg_to_rad(-85) * actor.facing
			if actor.slash_fx != null:
				actor.slash_fx.stop()

	update_charge_pips(t)

func update_stash_indicator() -> void:
	if actor.stash_icons.is_empty():
		return
	var count := clampi(actor.stash, 0, actor.stash_icons.size())
	var special: bool = actor.perk_kind != Perks.Kind.NONE
	var normal_width := (count-1)*6.5+6 if count > 0 else 0.0
	var special_width := 20.0 if special and count > 0 else 16.0 if special else 0.0
	var left := -(normal_width+special_width)*0.5
	if actor.is_inside_tree():
		actor.perk_icon_anchor = actor.to_local(actor.stash_icons[0].get_parent().to_global(Vector2(left+8, actor.stash_icons[0].position.y)))
	for i in actor.stash_icons.size():
		actor.stash_icons[i].position.x = left+special_width+3+i*6.5
		actor.stash_icons[i].modulate = Color("d6dfe5") if actor.alive and i < count else Color.TRANSPARENT

func update_hp_indicator() -> void:
	if actor.heart_icons.is_empty():
		return
	for i in actor.heart_icons.size():
		actor.heart_icons[i].modulate.a = 1.0 if (actor.alive and i < actor.hp) else 0.0

func update_katana_indicator() -> void:
	if actor.katana_icons.is_empty():
		return
	for i in actor.katana_icons.size():
		actor.katana_icons[i].modulate.a = 1.0 if (actor.alive and i < actor.katana_charges) else 0.0

func update_guard_indicator() -> void:
	if actor.guard_bar_fill == null:
		return
	actor.guard_bar_bg.visible = actor.alive
	actor.guard_bar_fill.visible = actor.alive
	if not actor.alive:
		return
	var frac: float = clampf(actor.guard_meter / actor.GUARD_MAX_S, 0.0, 1.0)
	actor.guard_bar_fill.size.x = actor.GUARD_BAR_W * frac
	var on_cooldown: bool = Time.get_ticks_msec() / 1000.0 < actor.guard_cooldown_until
	actor.guard_bar_fill.color = Color(0.9, 0.35, 0.3, 0.95) if on_cooldown else Color(0.4, 0.8, 1.0, 0.95)

func spawn_clash_burst(pos: Vector2) -> void:
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
	actor.get_parent().add_child(fx)
	Net.relay_strip_fx(path, 5, 20.0, pos, fx.scale, 55)

func spawn_strike_flash(pos: Vector2) -> void:
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
	actor.get_parent().add_child(fx)
	Net.relay_strip_fx(path, 4, 22.0, pos, fx.scale, 50)

func spawn_dust(foot_pos: Vector2, kind: String, side: float) -> void:

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
		foot_pos.y + half_h - info[5] * s)
	fx.scale = Vector2(dir * s, s)
	fx.z_index = 1
	actor.get_parent().add_child(fx)
	Net.relay_strip_fx(info[0], info[1], info[2], fx.position, fx.scale, 1)

func update_movement_dust(t: float, was_falling: bool) -> void:
	var on_floor_now: bool = actor.is_on_floor()
	if actor.alive:
		var foot: Vector2 = Vector2(actor.global_position.x, actor.global_position.y + DUST_FEET_OFFSET)
		if on_floor_now and not _was_on_floor and was_falling:

			spawn_dust(foot, "land", -1.0)
			spawn_dust(foot, "land", 1.0)
		elif on_floor_now and not actor.is_sliding and absf(actor.velocity.x) > RUN_DUST_MIN_HSPEED:
			if t >= _next_run_dust_t:
				_next_run_dust_t = t + RUN_DUST_INTERVAL_S
				spawn_dust(foot, "run", -signf(actor.velocity.x))
	_was_on_floor = on_floor_now
