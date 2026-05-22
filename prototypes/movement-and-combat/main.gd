# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Main orchestrator. Reacts to GameState transitions; loads themed maps with
# gradient sky + procedural background decorations + foreground props.

extends Node2D

const MAP_W := 800
const MAP_H := 450
const PLAYER_W := 20.0
const PLAYER_H := 32.0
const BG_IMAGE_PATH := "res://sprites/level-1.png"
const PLATFORM_SRC_Y_WALKABLE := 395.0   # measured: top of opaque stone in platform.png (1536×1024)
const PLATFORM_VISUAL_OVERHANG := 1.4    # sprite visual width = collision width × this

const STAGE_DURATIONS: Array = [0.6, 0.35, 0.35, 0.35, 0.5]
const STAGE_TEXTS: Array = ["", "3", "2", "1", "FIGHT!"]
const STAGE_SOUNDS: Array = ["", "countdown", "countdown", "countdown", "round_start"]

var arena_root: Node2D
var sky_bg_solid: ColorRect
var sky_rect: TextureRect
var bg_decorations: Node2D
var fg_decorations: Node2D
var current_map_nodes: Array = []
var players: Array = []
var spawn_points: Array = [Vector2(120, 380), Vector2(680, 380)]

var canvas: CanvasLayer
var title_screen: Control
var clan_select_screen: Control
var map_select_screen: Control
var match_end_screen: Control
var hud: Control
var banner_label: Label

var _in_countdown: bool = false
var _countdown_stage: int = 0
var _countdown_stage_until: float = 0.0
var _round_end_until: float = 0.0
var _current_loaded_map: int = -1
var _clash_freeze_until: float = 0.0   # real-time end of the active clash hitstop (0 = none)

func _ready() -> void:
	print("[MAIN] _ready()")
	_setup_input_map()
	_build_arena()
	_build_overlays()
	GameState.state_changed.connect(_on_state_changed)
	Combat.kill_logged.connect(_on_kill_logged)
	Combat.clash_occurred.connect(_on_clash)
	GameState.change_state(GameState.State.TITLE)
	print("[MAIN] _ready() complete")

func _setup_input_map() -> void:
	# P1 — DualSense only (no keyboard binds; gamepad added by _add_pad below).
	# P2 — keyboard: WASD move/aim, Space jump, L throw, K katana, Right Shift dodge.
	#      Dash is double-tap A/D (P2-only, handled in player.gd).
	_add_key("p2_left",     KEY_A)
	_add_key("p2_right",    KEY_D)
	_add_key("p2_aim_up",   KEY_W)         # aims throw upward
	_add_key("p2_aim_down", KEY_S)         # aims throw downward + menu "back"
	_add_key("p2_jump",     KEY_SPACE)
	_add_key("p2_throw",    KEY_L)
	_add_key("p2_katana",   KEY_K)
	_add_key("p2_dodge",    KEY_SHIFT, KEY_LOCATION_RIGHT)
	# Gamepad — TowerFall-on-PlayStation layout, appended to the keyboard binds.
	# First connected pad → P1, second → P2 (a single DualSense drives P1).
	_add_pad(1, 0)
	_add_pad(2, 1)
	# Global menu input — works from ANY keyboard or controller on every non-gameplay
	# screen (TowerFall-style). device -1 = all connected gamepads.
	_add_key("menu_cancel", KEY_ESCAPE)
	_add_pad_button("menu_cancel", JOY_BUTTON_B, -1)   # Circle ◯ — back / cancel
	_add_key("menu_random", KEY_X)
	_add_pad_button("menu_random", JOY_BUTTON_Y, -1)   # Triangle △ — random map

# Bind one gamepad (device index) to a player's actions, mirroring TowerFall's
# PlayStation scheme. Godot uses position-based face-button names, so on a
# DualSense: JOY_BUTTON_A=Cross ✕, B=Circle ◯, X=Square ▢, Y=Triangle △.
func _add_pad(player: int, device: int) -> void:
	var prefix: String = "p%d" % player
	# Move / aim — D-pad and the left analog stick.
	_add_pad_button(prefix + "_left",     JOY_BUTTON_DPAD_LEFT,  device)
	_add_pad_axis(  prefix + "_left",     JOY_AXIS_LEFT_X, -1.0, device)
	_add_pad_button(prefix + "_right",    JOY_BUTTON_DPAD_RIGHT, device)
	_add_pad_axis(  prefix + "_right",    JOY_AXIS_LEFT_X,  1.0, device)
	_add_pad_button(prefix + "_aim_up",   JOY_BUTTON_DPAD_UP,    device)
	_add_pad_axis(  prefix + "_aim_up",   JOY_AXIS_LEFT_Y, -1.0, device)
	_add_pad_button(prefix + "_aim_down", JOY_BUTTON_DPAD_DOWN,  device)
	_add_pad_axis(  prefix + "_aim_down", JOY_AXIS_LEFT_Y,  1.0, device)
	# Actions — faithful to TowerFall on PlayStation.
	_add_pad_button(prefix + "_jump",   JOY_BUTTON_A, device)              # Cross ✕  — jump / menu confirm
	_add_pad_button(prefix + "_throw",  JOY_BUTTON_X, device)              # Square ▢ — throw shuriken (TowerFall "shoot")
	_add_pad_button(prefix + "_dodge",  JOY_BUTTON_B, device)              # Circle ◯ — dodge
	_add_pad_button(prefix + "_dodge",  JOY_BUTTON_LEFT_SHOULDER,  device) # L1       — dodge (TowerFall shoulder dodge)
	_add_pad_button(prefix + "_dodge",  JOY_BUTTON_RIGHT_SHOULDER, device) # R1       — dodge
	_add_pad_button(prefix + "_katana", JOY_BUTTON_Y, device)              # Triangle △ — katana melee (no TowerFall equivalent)
	# Slide/dash — L2 and R2 are one action; direction comes from the stick. Gamepad only.
	_add_pad_axis(prefix + "_slide", JOY_AXIS_TRIGGER_LEFT,  1.0, device)  # L2
	_add_pad_axis(prefix + "_slide", JOY_AXIS_TRIGGER_RIGHT, 1.0, device)  # R2

func _add_key(action_name: String, key: int, location: int = 0) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for prev in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, prev)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	if location != 0:
		ev.location = location
	InputMap.action_add_event(action_name, ev)

# Append a gamepad button to an existing action (does not clear keyboard binds).
func _add_pad_button(action_name: String, button: int, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	InputMap.action_add_event(action_name, ev)

# Append an analog-stick direction to an action. axis_value sign selects the
# half-axis (-1.0 = up/left, 1.0 = down/right); the action's deadzone gates it.
func _add_pad_axis(action_name: String, axis: int, axis_value: float, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	ev.device = device
	InputMap.action_add_event(action_name, ev)

func _build_arena() -> void:
	arena_root = Node2D.new()
	arena_root.name = "ArenaRoot"
	add_child(arena_root)

	# Solid color behind the sky image (fills letterbox when bg keeps aspect ratio)
	sky_bg_solid = ColorRect.new()
	sky_bg_solid.position = Vector2.ZERO
	sky_bg_solid.size = Vector2(MAP_W, MAP_H)
	sky_bg_solid.color = Color("0a081a")
	sky_bg_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_bg_solid.z_index = -15
	arena_root.add_child(sky_bg_solid)

	# Sky background image (TextureRect at z=-10).
	# Sized 640×450 (positioned x=80) so it fills the gap between walls with 6 px overlap
	# onto each wall — no visible black strips. KEEP_ASPECT_COVERED keeps moon round,
	# crops only ~6% of source vertically (decorative cherry-canopy top + cliff base).
	sky_rect = TextureRect.new()
	sky_rect.position = Vector2(80, 0)
	sky_rect.size = Vector2(640, 450)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky_rect.z_index = -10
	arena_root.add_child(sky_rect)

	# Background decorations (behind walls)
	var DecoScript: Script = load("res://decorations.gd")
	bg_decorations = Node2D.new()
	bg_decorations.set_script(DecoScript)
	bg_decorations.z_index = -5
	arena_root.add_child(bg_decorations)

	# Foreground decorations (in front of bg, behind walls)
	fg_decorations = Node2D.new()
	fg_decorations.set_script(DecoScript)
	fg_decorations.z_index = -2
	arena_root.add_child(fg_decorations)

	# Players (spawned once, respawned per round)
	var PlayerScript: Script = load("res://player.gd")
	for slot in [1, 2]:
		var p = CharacterBody2D.new()
		p.set_script(PlayerScript)
		p.slot = slot
		p.facing = 1 if slot == 1 else -1
		p.position = spawn_points[slot - 1]
		var col: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(PLAYER_W, PLAYER_H)
		col.shape = rect
		p.add_child(col)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Visual"
		sprite.centered = true
		# 5-frame horizontal sprite sheet (idle/walk1/walk2/jump/attack)
		sprite.hframes = 5
		sprite.vframes = 1
		sprite.frame = 0
		# Pixel-perfect: nearest filter, integer 2x scale (16x16 → 32x32)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		# Offset.y=3 (×2 scale = 6px display) aligns feet with hitbox bottom
		sprite.offset = Vector2(0.0, 3.0)
		# Default texture — replaced per-clan in _enter_match_intro
		sprite.texture = load("res://sprites/ninjas/ninja_cyan_native_80x16.png")
		p.add_child(sprite)
		arena_root.add_child(p)
		players.append(p)
		print("[MAIN] Pre-spawned player slot=", slot)

func _build_overlays() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)

	var TitleScript: Script = load("res://title_screen.gd")
	title_screen = Control.new()
	title_screen.set_script(TitleScript)
	canvas.add_child(title_screen)

	var ClanSelScript: Script = load("res://clan_select.gd")
	clan_select_screen = Control.new()
	clan_select_screen.set_script(ClanSelScript)
	canvas.add_child(clan_select_screen)

	var MapSelScript: Script = load("res://map_select.gd")
	map_select_screen = Control.new()
	map_select_screen.set_script(MapSelScript)
	canvas.add_child(map_select_screen)

	var MatchEndScript: Script = load("res://match_end.gd")
	match_end_screen = Control.new()
	match_end_screen.set_script(MatchEndScript)
	canvas.add_child(match_end_screen)

	var HudScript: Script = load("res://hud.gd")
	hud = Control.new()
	hud.set_script(HudScript)
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	canvas.add_child(hud)

	banner_label = Label.new()
	banner_label.position = Vector2(0, 130)
	banner_label.size = Vector2(800, 90)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 64)
	banner_label.add_theme_color_override("font_color", Color("f0eee8"))
	banner_label.text = ""
	canvas.add_child(banner_label)

func _on_state_changed(s: int) -> void:
	# Safety: never carry a clash freeze across a state change (e.g. ESC mid-clash).
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	_clash_freeze_until = 0.0
	var S = GameState.State
	title_screen.visible = (s == S.TITLE)
	clan_select_screen.visible = (s == S.CLAN_SELECT)
	map_select_screen.visible = (s == S.MAP_SELECT)
	match_end_screen.visible = (s == S.MATCH_END)
	arena_root.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END or s == S.MATCH_END)
	hud.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END)

	if s == S.MATCH_INTRO:
		_enter_match_intro()
	elif s == S.ROUND:
		_enter_round()
	elif s == S.ROUND_END:
		_enter_round_end()
	elif s == S.TITLE:
		banner_label.text = ""
		_clear_shurikens()

func _enter_match_intro() -> void:
	_clear_shurikens()
	if _current_loaded_map != GameState.selected_map_index:
		_load_map(GameState.selected_map_index)
	for p in players:
		var clan = GameState.get_clan(p.slot)
		var sprite: Sprite2D = p.get_node("Visual")
		var sprite_name: String = clan.get("sprite", "cyan")
		# Load both pose sheet (5 frames) and idle animation sheet (6 frames)
		var pose_path: String = "res://sprites/ninjas/ninja_%s_native_80x16.png" % sprite_name
		var idle_path: String = "res://sprites/ninjas/ninja_%s_idle_6frame_native_96x16.png" % sprite_name
		if ResourceLoader.exists(pose_path):
			p.pose_texture = load(pose_path)
		if ResourceLoader.exists(idle_path):
			p.idle_texture = load(idle_path)
		# Start in pose mode (idle mode kicks in via _update_visual when truly idle)
		sprite.texture = p.pose_texture
		sprite.hframes = 5
		sprite.frame = 0
		p.current_visual_mode = "pose"
		sprite.modulate = Color.WHITE
		var kat_path: String = "res://sprites/katanas/katana_v2/katana_%s_v2_6frame_native_192x16.png" % sprite_name
		# Katana swing visual (child "Katana", hidden until a swing)
		var old_kat: Node = p.get_node_or_null("Katana")
		if old_kat != null:
			old_kat.queue_free()
		var kat: Sprite2D = Sprite2D.new()
		kat.name = "Katana"
		if ResourceLoader.exists(kat_path):
			kat.texture = load(kat_path)
		kat.hframes = 6
		kat.frame = 2
		kat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		kat.scale = Vector2(1.5, 1.5)
		kat.visible = false
		p.add_child(kat)
		p.katana_sprite = kat

		# Above-head indicators: hearts (closest), stash, katana charges (highest)
		var old_ind: Node = p.get_node_or_null("Indicators")
		if old_ind != null:
			old_ind.queue_free()
		var ind_root: Node2D = Node2D.new()
		ind_root.name = "Indicators"
		p.add_child(ind_root)
		var cc: Color = clan.color
		p.heart_icons  = _make_icon_row(ind_root, 5, "res://sprites/heart.svg",    -1, 1, 0.5, 7.0, -26.0, Color(0.95, 0.25, 0.30, 1.0))
		p.stash_icons  = _make_icon_row(ind_root, 5, "res://sprites/shuriken.svg", -1, 1, 0.5, 6.5, -36.0, Color(cc.r, cc.g, cc.b, 1.0))
		p.katana_icons = _make_icon_row(ind_root, 3, kat_path,                      1, 6, 0.42, 11.0, -45.0, Color(0.85, 0.88, 0.95, 1.0))
		p.respawn(spawn_points[p.slot - 1])
	if hud != null and hud.has_method("show_map_banner"):
		hud.show_map_banner(Maps.get_map(GameState.selected_map_index).name)
	_start_countdown()

func _enter_round() -> void:
	_in_countdown = false
	banner_label.text = ""

func _enter_round_end() -> void:
	_round_end_until = Time.get_ticks_msec() / 1000.0 + 1.6
	var winner_slot: int = GameState.last_kill_killer
	var clan: Dictionary = GameState.get_clan(winner_slot)
	banner_label.text = "%s WINS ROUND" % clan.name
	banner_label.add_theme_color_override("font_color", clan.color)

func _start_countdown() -> void:
	_in_countdown = true
	_countdown_stage = 0
	_advance_countdown_stage()

func _advance_countdown_stage() -> void:
	if _countdown_stage == 0:
		banner_label.text = "ROUND %d" % GameState.current_round
		banner_label.add_theme_color_override("font_color", Color("f0eee8"))
	else:
		banner_label.text = STAGE_TEXTS[_countdown_stage]
		var clr: Color = Color("d4a830") if _countdown_stage < 4 else Color("e05030")
		banner_label.add_theme_color_override("font_color", clr)
		var snd: String = STAGE_SOUNDS[_countdown_stage]
		if snd != "":
			Audio.play(snd)
	_countdown_stage_until = Time.get_ticks_msec() / 1000.0 + STAGE_DURATIONS[_countdown_stage]

func _on_kill_logged(_killer: int, _victim: int) -> void:
	if GameState.current_state == GameState.State.ROUND:
		GameState.change_state(GameState.State.ROUND_END)

# Two katanas met. Action-movie beat: arc lightning between the blades, freeze the
# whole scene for a moment (real-time hitstop), then let it resume with both fighters
# recoiling a hair apart. Driven entirely off real time so the freeze is solid.
func _on_clash(a: Node, b: Node, midpoint: Vector2) -> void:
	# Lightning between the blades — 5-frame clash FX, plays through the freeze.
	_spawn_fx("res://sprites/fx/clash_lightning_5frame_native_160x32.png", 5, midpoint, 12.0, 2.0)
	# Push each fighter away from the other (small, very slight).
	var dir_a: int = 1 if a.global_position.x >= b.global_position.x else -1
	if a.has_method("apply_clash_recoil"):
		a.apply_clash_recoil(dir_a)
	if b.has_method("apply_clash_recoil"):
		b.apply_clash_recoil(-dir_a)
	# Freeze the scene. Real-time clock restores it in _process (which runs even at scale 0).
	Engine.time_scale = 0.0
	_clash_freeze_until = Time.get_ticks_msec() / 1000.0 + Combat.clash_freeze_duration_s
	Audio.play("hit")   # placeholder clash clang

# Spawn a one-shot strip animation (fx_anim.gd) at a world position, above the action.
func _spawn_fx(tex_path: String, frame_count: int, pos: Vector2, fps: float, scale: float) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = frame_count
	fx.fps = fps
	fx.texture = load(tex_path)
	fx.position = pos
	fx.scale = Vector2(scale, scale)
	fx.z_index = 60
	arena_root.add_child(fx)

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	# End the clash hitstop on real time (Engine.time_scale==0 still ticks _process).
	if _clash_freeze_until > 0.0 and t >= _clash_freeze_until:
		_clash_freeze_until = 0.0
		Engine.time_scale = 1.0
	if _in_countdown and t >= _countdown_stage_until:
		_countdown_stage += 1
		if _countdown_stage >= STAGE_DURATIONS.size():
			_in_countdown = false
			banner_label.text = ""
			GameState.change_state(GameState.State.ROUND)
		else:
			_advance_countdown_stage()
	if GameState.current_state == GameState.State.ROUND_END:
		if t >= _round_end_until:
			GameState.advance_round_or_end_match()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var s = GameState.current_state
		var S = GameState.State
		if event.keycode == KEY_ESCAPE:
			if s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END:
				print("[MAIN] ESC during match -> TITLE")
				GameState.change_state(S.TITLE)
				get_viewport().set_input_as_handled()

# === Map load + cleanup ===

func _load_map(index: int) -> void:
	_current_loaded_map = index
	for n in current_map_nodes:
		if is_instance_valid(n):
			n.queue_free()
	current_map_nodes.clear()

	var data: Dictionary = Maps.get_map(index)
	spawn_points = data.spawn_points.duplicate()

	# Sky: use background.png if present, else gradient fallback
	var using_image: bool = _apply_sky_background(data.get("sky_top", data.bg_color), data.get("sky_bot", data.bg_color))

	# Background decorations — skip when a real image is the backdrop (would clash)
	bg_decorations.commands = [] if using_image else data.get("bg_decorations", [])
	bg_decorations.queue_redraw()

	# Foreground decorations
	fg_decorations.commands = data.get("fg_decorations", [])
	fg_decorations.queue_redraw()

	# Walls (with edge highlight, unless transparent_platforms=true; sprite if provided)
	var edge_col: Color = data.get("wall_edge_color", data.wall_color)
	var transparent: bool = data.get("transparent_platforms", false)
	for w in data.walls:
		var sprite_path: String = w.get("sprite", "")
		var sprite_region: Rect2 = w.get("sprite_region", Rect2())
		var sprite_mode: String = w.get("sprite_mode", "platform")
		var body := _make_wall(w.center, w.size, data.wall_color, edge_col, transparent, sprite_path, sprite_region, sprite_mode)
		current_map_nodes.append(body)

	print("[MAIN] Loaded map %d: %s" % [index, data.name])

func _apply_sky_background(top_color: Color, bottom_color: Color) -> bool:
	# Update letterbox fallback color to match map theme
	if sky_bg_solid:
		sky_bg_solid.color = top_color
	# Prefer real background image if user supplied one
	if ResourceLoader.exists(BG_IMAGE_PATH):
		var img: Resource = load(BG_IMAGE_PATH)
		if img != null and img is Texture2D:
			sky_rect.texture = img
			return true
	# Fallback: procedural gradient
	var grad := Gradient.new()
	grad.colors = PackedColorArray([top_color, bottom_color])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = MAP_W
	tex.height = MAP_H
	sky_rect.texture = tex
	return false

# Build a horizontal row of small icons centered on x=0 at the given y (relative to player).
# frame=-1 means single-frame texture; hframes>1 selects a frame from a sprite sheet.
func _make_icon_row(parent: Node2D, count: int, tex_path: String, frame: int, hframes: int,
		scale: float, spacing: float, y: float, mod_color: Color) -> Array:
	var icons: Array = []
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	for i in count:
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = tex
		if hframes > 1:
			icon.hframes = hframes
			icon.frame = frame
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.scale = Vector2(scale, scale)
		icon.position = Vector2((i - (count - 1) * 0.5) * spacing, y)
		icon.modulate = mod_color
		parent.add_child(icon)
		icons.append(icon)
	return icons

func _make_wall(center: Vector2, size: Vector2, fill_color: Color, edge_color: Color, transparent: bool = false, sprite_path: String = "", sprite_region: Rect2 = Rect2(), sprite_mode: String = "platform") -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	# Priority 1: sprite-based wall/platform
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(sprite_path)
		sprite.centered = true
		var src_w: float
		var src_h: float
		if sprite_region.size.x > 0:
			sprite.region_enabled = true
			sprite.region_rect = sprite_region
			src_w = sprite_region.size.x
			src_h = sprite_region.size.y
		else:
			src_w = float(sprite.texture.get_width())
			src_h = float(sprite.texture.get_height())
		if sprite_mode == "fill":
			# Full-screen vertical wall: scale uniformly so visual height = 450 (screen)
			# Centered on body, which is assumed at world y=225 (screen center).
			var s: float = 450.0 / src_h
			sprite.scale = Vector2(s, s)
			sprite.position = Vector2.ZERO
		else:  # "platform" mode (default)
			var s: float = (size.x * PLATFORM_VISUAL_OVERHANG) / src_w
			sprite.scale = Vector2(s, s)
			sprite.position = Vector2(0.0, -size.y / 2.0 + s * (src_h / 2.0 - PLATFORM_SRC_Y_WALKABLE))
		body.add_child(sprite)
	# Priority 2: legacy solid color rendering (unused when sprite or transparent)
	elif not transparent:
		var vis: ColorRect = ColorRect.new()
		vis.size = size
		vis.position = -size / 2.0
		vis.color = fill_color
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(vis)
		var edge_top: ColorRect = ColorRect.new()
		edge_top.size = Vector2(size.x, 2.0)
		edge_top.position = Vector2(-size.x / 2.0, -size.y / 2.0)
		edge_top.color = edge_color
		edge_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(edge_top)
		var edge_bot: ColorRect = ColorRect.new()
		edge_bot.size = Vector2(size.x, 1.5)
		edge_bot.position = Vector2(-size.x / 2.0, size.y / 2.0 - 1.5)
		edge_bot.color = Color(fill_color).darkened(0.4)
		edge_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(edge_bot)
	# Priority 3: transparent collision-only (no visuals at all)
	arena_root.add_child(body)
	return body

func _clear_shurikens() -> void:
	for child in arena_root.get_children():
		if child is Area2D:
			child.queue_free()
