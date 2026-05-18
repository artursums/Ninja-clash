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

func _ready() -> void:
	print("[MAIN] _ready()")
	_setup_input_map()
	_build_arena()
	_build_overlays()
	GameState.state_changed.connect(_on_state_changed)
	Combat.kill_logged.connect(_on_kill_logged)
	GameState.change_state(GameState.State.TITLE)
	print("[MAIN] _ready() complete")

func _setup_input_map() -> void:
	_add_key("p1_left",  KEY_A)
	_add_key("p1_right", KEY_D)
	_add_key("p1_jump",  KEY_W)
	_add_key("p1_crouch",KEY_S)
	_add_key("p1_throw", KEY_SPACE)
	_add_key("p1_dodge", KEY_SHIFT, KEY_LOCATION_LEFT)
	_add_key("p2_left",  KEY_LEFT)
	_add_key("p2_right", KEY_RIGHT)
	_add_key("p2_jump",  KEY_UP)
	_add_key("p2_crouch",KEY_DOWN)
	_add_key("p2_throw", KEY_ENTER)
	_add_key("p2_dodge", KEY_SHIFT, KEY_LOCATION_RIGHT)

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

	# Sky background image (TextureRect at z=-10) — preserves aspect ratio
	sky_rect = TextureRect.new()
	sky_rect.position = Vector2.ZERO
	sky_rect.size = Vector2(MAP_W, MAP_H)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
		var path: String = "res://sprites/ninjas/ninja_%s_native_80x16.png" % sprite_name
		if ResourceLoader.exists(path):
			sprite.texture = load(path)
		# Sprite already has clan-specific colors baked in — no tint
		sprite.modulate = Color.WHITE
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

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
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
