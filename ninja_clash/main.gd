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
# Per-level backdrops live at res://sprites/levels/<slug>/background.png, set via each map's
# "background" field (Maps). Absent file → gradient sky fallback.
const PLATFORM_SRC_Y_WALKABLE := 395.0   # measured: top of opaque stone in platform.png (1536×1024)
const PLATFORM_VISUAL_OVERHANG := 1.4    # sprite visual width = collision width × this

const STAGE_DURATIONS: Array = [2.0, 0.8, 0.8, 0.8, 0.7]   # stage 0 = "ROUND N" banner (held 2.0 s); rest = dramatic 3/2/1/FIGHT count
const STAGE_TEXTS: Array = ["", "3", "2", "1", "FIGHT!"]
const STAGE_SOUNDS: Array = ["", "countdown", "countdown", "countdown", "round_start"]
# Premium stone sprites for stages 1-4 (3 / 2 / 1 / FIGHT). Stage 0 ("ROUND N") stays as text.
const STAGE_TEXTURES: Array = [
	null,
	preload("res://sprites/countdown/countdown_3_premium_native.png"),
	preload("res://sprites/countdown/countdown_2_premium_native.png"),
	preload("res://sprites/countdown/countdown_1_premium_native.png"),
	preload("res://sprites/countdown/fight_premium_native.png"),
]
# "ROUND N" indicator (stage 0): a ROUND wordmark + per-digit sprites, composed for any N.
const ROUND_WORD_TEX := preload("res://sprites/round-counter/round_word_native.png")
const DIGIT_TEXS: Array = [
	preload("res://sprites/round-counter/digit_0_native.png"),
	preload("res://sprites/round-counter/digit_1_native.png"),
	preload("res://sprites/round-counter/digit_2_native.png"),
	preload("res://sprites/round-counter/digit_3_native.png"),
	preload("res://sprites/round-counter/digit_4_native.png"),
	preload("res://sprites/round-counter/digit_5_native.png"),
	preload("res://sprites/round-counter/digit_6_native.png"),
	preload("res://sprites/round-counter/digit_7_native.png"),
	preload("res://sprites/round-counter/digit_8_native.png"),
	preload("res://sprites/round-counter/digit_9_native.png"),
]
const ROUND_GAP_WORD := 24.0    # px between "ROUND" and the number
const ROUND_GAP_DIGIT := 4.0    # px between digits

# Round-winner indicator (shown at ROUND_END): "P<N>" (color-tinted) + "WINS".
const WINS_TEX := preload("res://sprites/player-win/wins_native.png")
const PLAYER_TEXS: Array = [
	null,   # index 0 unused — slots are 1-4
	preload("res://sprites/player-win/p1_native.png"),
	preload("res://sprites/player-win/p2_native.png"),
	preload("res://sprites/player-win/p3_native.png"),
	preload("res://sprites/player-win/p4_native.png"),
]

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
var match_setup_screen: Control
var map_select_screen: Control
var match_end_screen: Control
var hud: Control
var mode_select_screen: Control
var banner_label: Label
var countdown_sprite: Sprite2D   # 3 / 2 / 1 / FIGHT premium stone sprites during the countdown
var round_display: Node2D        # composed "ROUND N" (wordmark + digit sprites) at countdown stage 0
var win_display: Node2D          # composed "P<N> WINS" shown at ROUND_END for the round's winner
var mode_label: Label   # small "P1 vs AI · CHUNIN" tag shown during a match

var _in_countdown: bool = false
var _countdown_stage: int = 0
var _countdown_stage_until: float = 0.0
var _round_end_until: float = 0.0
var _round_winner_slot: int = 0   # survivor of the round (last ninja standing), 0 = draw
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
	_add_key("p2_defend",   KEY_J)         # hold to guard — katana up, blocks front hits
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
	# Pause — Esc on the keyboard, Start on any pad. Opens the pause overlay during a round.
	_add_key("menu_pause", KEY_ESCAPE)
	_add_pad_button("menu_pause", JOY_BUTTON_START, -1)
	# Fight Setup — Tab on the keyboard, Select/Share (Back) on any pad. Opens the variants screen
	# from clan select. device -1 = all connected gamepads.
	_add_key("menu_setup", KEY_TAB)
	_add_pad_button("menu_setup", JOY_BUTTON_BACK, -1)
	# Skin cycle in clan select — Square (▢) on each pad; keyboard P for the keyboard player (P2).
	_add_pad_button("p1_skin", JOY_BUTTON_X, 0)
	_add_pad_button("p2_skin", JOY_BUTTON_X, 1)
	_add_key("p2_skin", KEY_P)

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
	# L2 = defend (hold the katana up to guard); R2 = slide/dash. Direction comes from the stick.
	_add_pad_axis(prefix + "_defend", JOY_AXIS_TRIGGER_LEFT,  1.0, device)  # L2 — guard
	_add_pad_axis(prefix + "_slide",  JOY_AXIS_TRIGGER_RIGHT, 1.0, device)  # R2 — dash/dodge

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

	# Players — created to match the mode's fighter count (2 duel · 4 free-for-all).
	_ensure_player_count(GameState.num_players())

# Spawn position for a fighter slot. The free-for-all needs four; the map provides two,
# so slots 3-4 use the upper-side platforms.
#
# Each slot maps to its OWN point by index — never modulo-wrapped. A modulo wrap would silently
# put two different slots on the same point if a slot index ever exceeded the point count (e.g. a
# stray higher-slot fighter after an FFA→duel switch), so two fighters would spawn on top of each
# other. Instead, if there is no dedicated point for a slot, fall back to a spread position so no
# two fighters can ever coincide.
const FFA_SPAWNS: Array = [Vector2(230, 340), Vector2(570, 340), Vector2(220, 170), Vector2(580, 170)]

func _player_spawn(slot: int) -> Vector2:
	var pts: Array = FFA_SPAWNS if GameState.num_players() >= 4 else spawn_points
	var idx: int = slot - 1
	if idx >= 0 and idx < pts.size():
		return pts[idx]
	# More fighters than defined spawn points — spread them out so no two ever share a spot.
	push_warning("Spawn: slot %d has no dedicated spawn (only %d points); using spread fallback" % [slot, pts.size()])
	return Vector2(110.0 + idx * 190.0, 340.0)

func _make_player(slot: int) -> CharacterBody2D:
	var p: CharacterBody2D = CharacterBody2D.new()
	p.set_script(load("res://player.gd"))
	p.slot = slot
	p.facing = 1 if slot <= 2 else -1
	p.position = _player_spawn(slot)
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
	return p

# Create or free player nodes so the arena holds exactly `n` fighters.
func _ensure_player_count(n: int) -> void:
	while players.size() < n:
		players.append(_make_player(players.size() + 1))
	while players.size() > n:
		var p = players.pop_back()
		p.queue_free()

func _build_overlays() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)

	var TitleScript: Script = load("res://title_screen.gd")
	title_screen = Control.new()
	title_screen.set_script(TitleScript)
	canvas.add_child(title_screen)

	var ModeSelScript: Script = load("res://mode_select.gd")
	mode_select_screen = Control.new()
	mode_select_screen.set_script(ModeSelScript)
	canvas.add_child(mode_select_screen)

	var ClanSelScript: Script = load("res://clan_select.gd")
	clan_select_screen = Control.new()
	clan_select_screen.set_script(ClanSelScript)
	canvas.add_child(clan_select_screen)

	var MatchSetupScript: Script = load("res://match_setup.gd")
	match_setup_screen = Control.new()
	match_setup_screen.set_script(MatchSetupScript)
	canvas.add_child(match_setup_screen)

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

	# Countdown sprite (3 / 2 / 1 / FIGHT). Centered over the upper-middle of the arena, like the
	# old text banner. Native res at scale 1.0; the pop animation scales it transiently.
	countdown_sprite = Sprite2D.new()
	countdown_sprite.position = Vector2(400, 175)
	countdown_sprite.visible = false
	canvas.add_child(countdown_sprite)

	# "ROUND N" composite (wordmark + digits), centered at the same spot as the countdown numbers.
	round_display = Node2D.new()
	round_display.position = Vector2(400, 175)
	round_display.visible = false
	canvas.add_child(round_display)

	# "P<N> WINS" composite, shown at the end of each round.
	win_display = Node2D.new()
	win_display.position = Vector2(400, 175)
	win_display.visible = false
	canvas.add_child(win_display)

	# Pause overlay — on its own top CanvasLayer so it draws above the HUD/arena, and
	# PROCESS_MODE_ALWAYS (set in pause_menu.gd) so it keeps running while the tree is paused.
	var pause_layer: CanvasLayer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var pause_menu: Control = Control.new()
	pause_menu.set_script(load("res://pause_menu.gd"))
	pause_layer.add_child(pause_menu)

	# Match mode tag (top-right) — e.g. "P1 vs AI · CHUNIN". Shown only during a match.
	mode_label = Label.new()
	mode_label.position = Vector2(540, 6)
	mode_label.size = Vector2(254, 18)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label.add_theme_font_size_override("font_size", 11)
	mode_label.add_theme_color_override("font_color", Color("8a8ea8"))
	mode_label.visible = false
	canvas.add_child(mode_label)

func _update_mode_label() -> void:
	if mode_label == null:
		return
	var names: Array = ["P1 vs P2", "P1 vs AI", "AI vs AI", "P1 vs 3 · FFA"]
	var txt: String = names[GameState.game_mode]
	if GameState.game_mode != GameState.Mode.HUMAN_VS_HUMAN:
		txt += "  ·  " + GameState.DIFFICULTY_NAMES[GameState.ai_difficulty]
	mode_label.text = txt

func _on_state_changed(s: int) -> void:
	# Safety: never carry a clash freeze across a state change (e.g. ESC mid-clash).
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	_clash_freeze_until = 0.0
	var S = GameState.State
	title_screen.visible = (s == S.TITLE)
	mode_select_screen.visible = (s == S.MODE_SELECT)
	clan_select_screen.visible = (s == S.CLAN_SELECT)
	match_setup_screen.visible = (s == S.MATCH_SETUP)
	map_select_screen.visible = (s == S.MAP_SELECT)
	match_end_screen.visible = (s == S.MATCH_END)
	arena_root.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END or s == S.MATCH_END)
	hud.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END)
	mode_label.visible = (s == S.MATCH_INTRO or s == S.ROUND or s == S.ROUND_END)
	win_display.visible = false   # only _enter_round_end re-shows it (for the round's winner)
	if mode_label.visible:
		_update_mode_label()

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
	_ensure_player_count(GameState.num_players())
	for p in players:
		var clan = GameState.get_clan(p.slot)
		var sprite: Sprite2D = p.get_node("Visual")
		var sprite_name: String = clan.get("sprite", "cyan")
		# Pose sheet (5 frames) + optional idle sheet (6 frames), resolved for this slot's skin.
		var skin_idx: int = GameState.skin_index(p.slot)
		var pose_path: String = GameState.skin_pose_path(sprite_name, skin_idx)
		var idle_path: String = GameState.skin_idle_path(sprite_name, skin_idx)
		if ResourceLoader.exists(pose_path):
			p.pose_texture = load(pose_path)
		# Costume/elemental skins ship no idle sheet → null so player.gd uses the pose idle frame.
		p.idle_texture = load(idle_path) if idle_path != "" and ResourceLoader.exists(idle_path) else null
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

		# Above-head indicators: hearts (closest), stash, katana charges (highest).
		# Free EVERY prior indicator row, renaming first so the deferred queue_free can't
		# leave a name collision: add_child auto-renames a new "Indicators" to "Indicators2"
		# while the old one lingers, so next round get_node_or_null("Indicators") misses it
		# and it's never freed — an orphan row whose icons are never updated again, leaving
		# frozen hearts hovering over a dead/respawned ninja. Rename + free all of them.
		for child in p.get_children():
			if String(child.name).begins_with("Indicators"):
				child.name = "_old_indicators"
				child.queue_free()
		var ind_root: Node2D = Node2D.new()
		ind_root.name = "Indicators"
		# Above-head HUD info must read over the arena: platforms/walls sit at z 0, so lift the whole
		# indicator group well above them (and the decorations) so hearts/stash/katana/guard never
		# hide behind a platform that overlaps the head.
		ind_root.z_index = 100
		p.add_child(ind_root)
		var cc: Color = clan.color
		# Row lengths follow the active match variants: hearts = max HP, the shuriken row spans the
		# catch cap (hidden entirely when shurikens are off), katana marks = the granted charge count
		# (0 when the katana is off). _make_icon_row(0) yields an empty row the updaters skip.
		var stash_row: int = MatchConfig.STASH_CAP if MatchConfig.shurikens_enabled else 0
		var katana_row: int = MatchConfig.effective_katana_charges()
		p.heart_icons  = _make_icon_row(ind_root, MatchConfig.max_hp, "res://sprites/heart.svg",    -1, 1, 0.5, 7.0, -26.0, Color(0.95, 0.25, 0.30, 1.0))
		p.stash_icons  = _make_icon_row(ind_root, stash_row, "res://sprites/shuriken.svg", -1, 1, 0.5, 6.5, -36.0, Color(cc.r, cc.g, cc.b, 1.0))
		p.katana_icons = _make_icon_row(ind_root, katana_row, kat_path,                      1, 6, 0.42, 11.0, -45.0, Color(0.85, 0.88, 0.95, 1.0))
		# Guard meter bar (track + depleting fill), highest of the above-head indicators.
		var gb_bg: ColorRect = ColorRect.new()
		gb_bg.color = Color(0.0, 0.0, 0.0, 0.55)
		gb_bg.size = Vector2(26.0, 4.0)
		gb_bg.position = Vector2(-13.0, -56.0)
		gb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind_root.add_child(gb_bg)
		var gb_fill: ColorRect = ColorRect.new()
		gb_fill.color = Color(0.4, 0.8, 1.0, 0.95)
		gb_fill.size = Vector2(26.0, 4.0)
		gb_fill.position = Vector2(-13.0, -56.0)
		gb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind_root.add_child(gb_fill)
		p.guard_bar_bg = gb_bg
		p.guard_bar_fill = gb_fill
		p.respawn(_player_spawn(p.slot))
		p.is_bot = GameState.slot_is_bot(p.slot)
		p.bot_difficulty = GameState.ai_difficulty
	# De-overlap AT SPAWN TIME (not only at the round-start transition) so two fighters can never
	# even appear stacked during the countdown — covers any rare upstream corruption immediately.
	_separate_overlapping_spawns()
	_start_countdown()

func _enter_round() -> void:
	_in_countdown = false
	banner_label.text = ""

# Safety net (runs the instant a round begins): if any two fighters are dangerously close, snap
# EVERY fighter back to its canonical spawn point. Normally a no-op — fighters start on opposite
# pads ~340 px apart — so this only fires if something upstream left two of them stacked, which
# guarantees a round can never visibly begin with two ninjas on the same spot.
func _separate_overlapping_spawns() -> void:
	var too_close: bool = false
	for i in players.size():
		for j in range(i + 1, players.size()):
			if players[i].position.distance_to(players[j].position) < 120.0:
				too_close = true
	if not too_close:
		return
	# Log the actual layout so a rare LIVE occurrence is captured with exact numbers, then snap
	# every fighter to its canonical spawn. (Normally never fires — respawn already separates them.)
	var report: String = ""
	for p in players:
		report += " slot%d=(%.0f,%.0f)" % [p.slot, p.position.x, p.position.y]
	push_warning("Spawn safety net FIRED (round %d):%s — re-placing at canonical spawns" % [GameState.current_round, report])
	print("[SPAWN-FIX] round %d overlap detected:%s" % [GameState.current_round, report])
	for p in players:
		p.position = _player_spawn(p.slot)
		p.velocity = Vector2.ZERO

func _enter_round_end() -> void:
	_round_end_until = Time.get_ticks_msec() / 1000.0 + 1.6
	var winner_slot: int = _round_winner_slot if _round_winner_slot > 0 else GameState.last_kill_killer
	if winner_slot > 0:
		_show_round_winner(winner_slot)   # "P<N> WINS" sprite composite
	# else: a draw (double-KO) → show nothing

func _start_countdown() -> void:
	_in_countdown = true
	_countdown_stage = 0
	_advance_countdown_stage()

func _advance_countdown_stage() -> void:
	if _countdown_stage == 0:
		# "ROUND N" — premium ROUND wordmark + digit sprites (composed for the current round).
		countdown_sprite.visible = false
		_show_round_number(GameState.current_round)
		round_display.visible = true
		_pop_node(round_display, 1.25)
	else:
		# 3 / 2 / 1 / FIGHT — premium stone sprites.
		round_display.visible = false
		countdown_sprite.texture = STAGE_TEXTURES[_countdown_stage]
		countdown_sprite.visible = true
		_pop_node(countdown_sprite, 2.0 if _countdown_stage >= 4 else 1.5)   # FIGHT pops hardest
		var snd: String = STAGE_SOUNDS[_countdown_stage]
		if snd != "":
			Audio.play(snd)
	_countdown_stage_until = Time.get_ticks_msec() / 1000.0 + STAGE_DURATIONS[_countdown_stage]

# Build the "ROUND N" composite under round_display: the wordmark then each digit, laid out
# left-to-right and centered on round_display's origin (so the pop scales around the centre).
func _show_round_number(n: int) -> void:
	for c in round_display.get_children():
		c.free()
	var digits: String = str(maxi(n, 0))
	var total: float = float(ROUND_WORD_TEX.get_width()) + ROUND_GAP_WORD
	for ch in digits:
		total += float(DIGIT_TEXS[int(ch)].get_width()) + ROUND_GAP_DIGIT
	total -= ROUND_GAP_DIGIT   # no trailing gap
	var x: float = -total * 0.5
	x = _place_glyph(round_display, ROUND_WORD_TEX, x) + ROUND_GAP_WORD
	for ch in digits:
		x = _place_glyph(round_display, DIGIT_TEXS[int(ch)], x) + ROUND_GAP_DIGIT

# Build "P<N> WINS" under win_display for the round's winner, centered on its origin.
func _show_round_winner(slot: int) -> void:
	for c in win_display.get_children():
		c.free()
	if slot < 1 or slot >= PLAYER_TEXS.size() or PLAYER_TEXS[slot] == null:
		win_display.visible = false
		return
	var p_tex: Texture2D = PLAYER_TEXS[slot]
	var total: float = float(p_tex.get_width()) + ROUND_GAP_WORD + float(WINS_TEX.get_width())
	var x: float = -total * 0.5
	x = _place_glyph(win_display, p_tex, x) + ROUND_GAP_WORD
	_place_glyph(win_display, WINS_TEX, x)
	win_display.visible = true
	_pop_node(win_display, 1.4)

# Add one glyph to `parent` (top-left at x, vertically centered on y=0); return its right edge.
func _place_glyph(parent: Node2D, tex: Texture2D, x: float) -> float:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x, -tex.get_height() * 0.5)
	parent.add_child(s)
	return x + tex.get_width()

# Punch-in for a Node2D (countdown sprite or the ROUND composite): scale `from` → 1.0 + fade.
# modulate cascades to children, so the whole ROUND composite fades together.
func _pop_node(node: Node2D, from: float) -> void:
	node.scale = Vector2(from, from)
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.14)

func _on_kill_logged(_killer: int, _victim: int) -> void:
	if GameState.current_state != GameState.State.ROUND:
		return
	# Last ninja standing: the round ends only when one (or none) remain alive.
	var alive_count: int = 0
	_round_winner_slot = 0
	for p in players:
		if p.alive:
			alive_count += 1
			_round_winner_slot = p.slot
	if alive_count <= 1:
		if alive_count == 1:
			Combat.award_survivor(_round_winner_slot)
		else:
			_round_winner_slot = 0   # double-KO — no winner this round
		GameState.change_state(GameState.State.ROUND_END)

# Two katanas met. Action-movie beat: arc lightning between the blades, freeze the
# whole scene for a moment (real-time hitstop), then let it resume with both fighters
# recoiling a hair apart. Driven entirely off real time so the freeze is solid.
func _on_clash(a: Node, b: Node, midpoint: Vector2) -> void:
	# Lightning between the blades — 5-frame clash FX, plays through the freeze.
	_spawn_fx("res://sprites/fx/clash_lightning_5frame_native_160x32.png", 5, midpoint, 12.0, 2.0)
	# Push each fighter away from the other and HITSTOP only those two — never a global
	# time-freeze — so the other players in a 4-player match keep playing while these two clash.
	var dir_a: int = 1 if a.global_position.x >= b.global_position.x else -1
	var until: float = Time.get_ticks_msec() / 1000.0 + Combat.clash_freeze_duration_s
	if a.has_method("apply_clash_recoil"):
		a.apply_clash_recoil(dir_a)
		a.frozen_until = until
	if b.has_method("apply_clash_recoil"):
		b.apply_clash_recoil(-dir_a)
		b.frozen_until = until
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
			countdown_sprite.visible = false
			round_display.visible = false
			_separate_overlapping_spawns()   # safety net: never begin a round with fighters stacked
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
		# Esc during a live ROUND opens the pause overlay (pause_menu.gd owns it, not handled here).
		# In the brief countdown / round-end transitions, Esc still bails to the title screen.
		if event.keycode == KEY_ESCAPE:
			if s == S.MATCH_INTRO or s == S.ROUND_END:
				print("[MAIN] ESC during transition -> TITLE")
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

	# Sky: use this level's background image if present, else gradient fallback
	var using_image: bool = _apply_sky_background(data.get("sky_top", data.bg_color), data.get("sky_bot", data.bg_color), data.get("background", ""))

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
		var walkable_y: float = w.get("sprite_walkable", -1.0)
		var body := _make_wall(w.center, w.size, data.wall_color, edge_col, transparent, sprite_path, sprite_region, sprite_mode, walkable_y)
		current_map_nodes.append(body)

	# Non-colliding scenery sprites (e.g. neon gate pillars, ladder tower) drawn behind the
	# platforms but in front of the sky image. Pure decoration — no collision, no gameplay.
	for d in data.get("deco_sprites", []):
		var deco := _make_deco(d)
		if deco != null:
			current_map_nodes.append(deco)

	print("[MAIN] Loaded map %d: %s" % [index, data.name])

func _make_deco(d: Dictionary) -> Sprite2D:
	var path: String = d.get("sprite", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var spr := Sprite2D.new()
	spr.texture = load(path)
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var region: Rect2 = d.get("sprite_region", Rect2())
	var src_h: float = spr.texture.get_height()
	if region.size.x > 0:
		spr.region_enabled = true
		spr.region_rect = region
		src_h = region.size.y
	# Scale uniformly so the on-screen height matches the requested value (preserves aspect).
	var screen_h: float = d.get("height", src_h)
	var s: float = screen_h / src_h
	spr.scale = Vector2(s, s)
	spr.position = d.get("center", Vector2.ZERO)
	spr.z_index = int(d.get("z", -5))
	spr.modulate = d.get("modulate", Color.WHITE)
	arena_root.add_child(spr)
	return spr

func _apply_sky_background(top_color: Color, bottom_color: Color, bg_path: String) -> bool:
	# Update letterbox fallback color to match map theme
	if sky_bg_solid:
		sky_bg_solid.color = top_color
	# Prefer this level's background image if one is present on disk
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var img: Resource = load(bg_path)
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

func _make_wall(center: Vector2, size: Vector2, fill_color: Color, edge_color: Color, transparent: bool = false, sprite_path: String = "", sprite_region: Rect2 = Rect2(), sprite_mode: String = "platform", walkable_y: float = -1.0) -> StaticBody2D:
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
			# walkable_y = source-pixel row of the deck top (within region). -1 → use the
			# platform.png default; component platforms each pass their own measured deck row.
			var wy: float = PLATFORM_SRC_Y_WALKABLE if walkable_y < 0.0 else walkable_y
			sprite.position = Vector2(0.0, -size.y / 2.0 + s * (src_h / 2.0 - wy))
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
