# Main menu / title screen.
#
# Premium pixel-art menu composed from sprites/menu/: a 4-layer parallax backdrop
# (sky → mountains → pagoda → foreground), the FOUR CLANS stone wordmark with
# crossed katanas + a "shinobi arena" wooden sign, and four wooden buttons.
#
# Navigation matches the rest of the menus (mode_select / pause_menu):
#   aim_up / aim_down (either pad or keyboard) — move the cursor
#   p1_jump / p2_jump (Cross / Space)          — confirm
#   menu_cancel (Circle / Esc)                 — back out of an overlay
#
# Buttons:
#   START   → MODE_SELECT (normal match-setup flow)
#   OPTIONS → settings overlay (Master / Music / SFX volume + Fullscreen), bound to Settings
#   CREDITS → credits overlay
#   QUIT    → exit the game

extends Control

# --- Menu sprites (native res; scaled up to the 800×450 viewport) ---
const TEX_SKY := preload("res://sprites/menu/bg_sky_native.png")
const TEX_MOUNTAINS := preload("res://sprites/menu/bg_mountains_native.png")
const TEX_PAGODA := preload("res://sprites/menu/bg_pagoda_native.png")
const TEX_FOREGROUND := preload("res://sprites/menu/bg_foreground_native.png")
const TEX_TITLE := preload("res://sprites/menu/title_four_clans_native.png")
const TEX_KATANAS := preload("res://sprites/menu/title_katanas_native.png")
const TEX_SUBTITLE := preload("res://sprites/menu/title_subtitle_native.png")

# Button textures: [normal, hover, pressed] per slug.
const BTN_TEX := {
	"start":   ["res://sprites/menu/button_start_normal_native.png",
				"res://sprites/menu/button_start_hover_native.png",
				"res://sprites/menu/button_start_pressed_native.png"],
	"online":  ["res://sprites/menu/button_online_normal_native.png",
				"res://sprites/menu/button_online_hover_native.png",
				"res://sprites/menu/button_online_pressed_native.png"],
	"options": ["res://sprites/menu/button_options_normal_native.png",
				"res://sprites/menu/button_options_hover_native.png",
				"res://sprites/menu/button_options_pressed_native.png"],
	"credits": ["res://sprites/menu/button_credits_normal_native.png",
				"res://sprites/menu/button_credits_hover_native.png",
				"res://sprites/menu/button_credits_pressed_native.png"],
	"quit":    ["res://sprites/menu/button_quit_normal_native.png",
				"res://sprites/menu/button_quit_hover_native.png",
				"res://sprites/menu/button_quit_pressed_native.png"],
}
const BUTTON_SLUGS: Array = ["start", "online", "options", "credits", "quit"]

# native bg is 480×270 → viewport is 800×450, a uniform 5/3 scale.
const S := 800.0 / 480.0          # 1.6667 — native-bg → viewport scale
const TITLE_SCALE := 0.72 * S     # ≈1.2  — title downscaled a touch so the layout breathes
const KATANA_SCALE := 0.756 * S   # ≈1.26 — katanas sweep a little wider than the title
const SUB_SCALE := S              # ≈1.667
const BTN_SCALE := S              # ≈1.667
const TITLE_TOP := 18.0           # 0.04 × 450
const BTN_TOP := 158.0            # first button top (5 buttons since ONLINE joined the stack)
const BTN_STEP := 46.0            # vertical step (planks overlap, TowerFall-chunky)
const PRESS_FLASH_S := 0.12       # how long the "pressed" sprite shows before the action fires

# Overlay sub-states.
const OVERLAY_NONE := 0
const OVERLAY_OPTIONS := 1
const OVERLAY_CREDITS := 2

const OPT_ROWS: Array = ["MASTER", "MUSIC", "SFX", "FULLSCREEN", "TUTORIAL", "BACK"]
const VOL_STEP := 0.1
const BAR_SEGMENTS := 10

const COL_SEL := Color("d4a830")   # gold — selected
const COL_DIM := Color("a8a498")   # muted — unselected
const COL_HEAD := Color("f0eee8")  # near-white — headers

var cursor: int = 0
var _buttons: Array = []           # TextureRect per button, in BUTTON_SLUGS order
var _input_lockout_until: float = 0.0
var _press_until: float = 0.0
var _press_action: int = -1

var _overlay: int = OVERLAY_NONE
var _options_panel: Control = null
var _credits_panel: Control = null
var _opt_rows: Array = []          # Label per OPT_ROWS entry
var _options_cursor: int = 0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _on_visibility_changed() -> void:
	if visible:
		# Returning from a match (or first boot): reset to START, drop any overlay,
		# and lock input briefly so the press that brought us here can't leak through.
		cursor = 0
		_press_until = 0.0
		_press_action = -1
		_set_overlay(OVERLAY_NONE)
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()


# --- Build -----------------------------------------------------------------

func _build() -> void:
	_add_layer(TEX_SKY)
	_add_layer(TEX_MOUNTAINS)
	_add_layer(TEX_PAGODA)
	_add_layer(TEX_FOREGROUND)

	# Crossed katanas sweep BEHIND the wordmark, centred on the title's midline.
	var katanas := _add_sprite(TEX_KATANAS, KATANA_SCALE)
	var kw := TEX_KATANAS.get_width() * KATANA_SCALE
	var kh := TEX_KATANAS.get_height() * KATANA_SCALE
	var title_h := TEX_TITLE.get_height() * TITLE_SCALE
	katanas.position = Vector2((800.0 - kw) / 2.0, TITLE_TOP + title_h / 2.0 - kh / 2.0)

	# FOUR CLANS stone wordmark.
	var title := _add_sprite(TEX_TITLE, TITLE_SCALE)
	var tw := TEX_TITLE.get_width() * TITLE_SCALE
	title.position = Vector2((800.0 - tw) / 2.0, TITLE_TOP)

	# "shinobi arena" wooden sign, tucked under the wordmark.
	var sub := _add_sprite(TEX_SUBTITLE, SUB_SCALE)
	var sw := TEX_SUBTITLE.get_width() * SUB_SCALE
	sub.position = Vector2((800.0 - sw) / 2.0, TITLE_TOP + title_h - 10.0)

	# Four stacked wooden buttons.
	var bw := 188.0 * BTN_SCALE
	var bx := (800.0 - bw) / 2.0
	for i in BUTTON_SLUGS.size():
		var slug: String = BUTTON_SLUGS[i]
		var btn := TextureRect.new()
		btn.texture = load(BTN_TEX[slug][0])
		btn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.scale = Vector2(BTN_SCALE, BTN_SCALE)
		btn.size = Vector2(load(BTN_TEX[slug][0]).get_size())
		btn.position = Vector2(bx, BTN_TOP + i * BTN_STEP)
		add_child(btn)
		_buttons.append(btn)

	# Navigation hint — the landing screen teaches its own controls (every overlay already does).
	var nav_hint := Label.new()
	nav_hint.text = "W/S · ↕ — SELECT      ENTER / SPACE / ✕ — CONFIRM"
	nav_hint.position = Vector2(0, 430)
	nav_hint.size = Vector2(800, 18)
	nav_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_hint.add_theme_font_size_override("font_size", 12)
	nav_hint.add_theme_color_override("font_color", COL_DIM)
	nav_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav_hint)

	_build_options_panel()
	_build_credits_panel()


# Full-screen parallax layer.
func _add_layer(tex: Texture2D) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


# A pixel sprite drawn at native size × `scale`, top-left anchored.
func _add_sprite(tex: Texture2D, sprite_scale: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(tex.get_size())
	tr.scale = Vector2(sprite_scale, sprite_scale)
	add_child(tr)
	return tr


func _build_options_panel() -> void:
	_options_panel = _make_overlay_panel(460.0, 300.0, "OPTIONS")
	var box: VBoxContainer = _options_panel.get_node("Box")
	for i in OPT_ROWS.size():
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 22)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(row)
		_opt_rows.append(row)
	var hint := Label.new()
	hint.text = "↑/↓ select    ←/→ adjust    ✕ confirm    ◯ / Esc back"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COL_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_options_panel.visible = false


func _build_credits_panel() -> void:
	_credits_panel = _make_overlay_panel(520.0, 320.0, "CREDITS")
	var box: VBoxContainer = _credits_panel.get_node("Box")
	var lines: Array = [
		"FOUR CLANS — Shinobi Arena",
		"",
		"Game Design & Programming",
		"   Four Clans Team",
		"",
		"Engine          Godot 4.6",
		"Art             Pixel-art sprite suite",
		"",
		"Thanks for playing!",
	]
	for l in lines:
		var lab := Label.new()
		lab.text = String(l)
		lab.add_theme_font_size_override("font_size", 18)
		lab.add_theme_color_override("font_color", COL_HEAD if l == lines[0] else COL_DIM)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lab)
	var hint := Label.new()
	hint.text = "◯ / Esc / ✕  back"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COL_SEL)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_credits_panel.visible = false


# A centred dark panel with a dimmed full-screen backdrop and a title label.
# Returns the panel Control; its "Box" child (VBoxContainer) holds the content.
func _make_overlay_panel(w: float, h: float, header: String) -> Control:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.04, 0.04, 0.10, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var panel := ColorRect.new()
	panel.color = Color("1a1726")
	panel.size = Vector2(w, h)
	panel.position = Vector2((800.0 - w) / 2.0, (450.0 - h) / 2.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var border := ColorRect.new()
	border.color = Color("3a3450")
	border.size = Vector2(w, 3)
	border.position = panel.position + Vector2(0, -3)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border)

	var head := Label.new()
	head.text = header
	head.position = Vector2((800.0 - w) / 2.0, (450.0 - h) / 2.0 + 14.0)
	head.size = Vector2(w, 34)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", COL_SEL)
	root.add_child(head)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.position = Vector2((800.0 - w) / 2.0 + 24.0, (450.0 - h) / 2.0 + 64.0)
	box.size = Vector2(w - 48.0, h - 80.0)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	add_child(root)
	return root


# --- Input -----------------------------------------------------------------

func _nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


func _confirm() -> bool:
	return Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
		or Input.is_action_just_pressed("p1_confirm") or Input.is_action_just_pressed("p2_confirm")


func _process(_delta: float) -> void:
	if not visible:
		return
	var t: float = Time.get_ticks_msec() / 1000.0

	# A button is mid press-flash: when it ends, fire the action.
	if _press_until > 0.0:
		if t >= _press_until:
			var act: int = _press_action
			_press_until = 0.0
			_press_action = -1
			_refresh()
			_do_action(act)
		return

	if t < _input_lockout_until:
		return

	match _overlay:
		OVERLAY_OPTIONS:
			_process_options()
		OVERLAY_CREDITS:
			_process_credits()
		_:
			_process_main_menu(t)


func _process_main_menu(t: float) -> void:
	if _nav("aim_up"):
		cursor = (cursor + BUTTON_SLUGS.size() - 1) % BUTTON_SLUGS.size()
		Audio.play("click")
		_refresh()
	elif _nav("aim_down"):
		cursor = (cursor + 1) % BUTTON_SLUGS.size()
		Audio.play("click")
		_refresh()
	elif _confirm():
		Audio.play("confirm")
		_press_action = cursor
		_press_until = t + PRESS_FLASH_S
		_refresh()   # show the pressed sprite during the flash


func _do_action(action: int) -> void:
	match action:
		0:
			GameState.change_state(GameState.State.MODE_SELECT)
		1:
			GameState.change_state(GameState.State.ONLINE_MENU)
		2:
			_set_overlay(OVERLAY_OPTIONS)
		3:
			_set_overlay(OVERLAY_CREDITS)
		4:
			get_tree().quit()


func _process_options() -> void:
	if Input.is_action_just_pressed("menu_cancel"):
		Audio.play("click")
		_set_overlay(OVERLAY_NONE)
		return
	if _nav("aim_up"):
		_options_cursor = (_options_cursor + OPT_ROWS.size() - 1) % OPT_ROWS.size()
		Audio.play("click")
		_refresh_options()
	elif _nav("aim_down"):
		_options_cursor = (_options_cursor + 1) % OPT_ROWS.size()
		Audio.play("click")
		_refresh_options()
	elif _nav("left") or _nav("right"):
		var right: bool = _nav("right")
		if _options_cursor < 3:
			var delta: float = VOL_STEP if right else -VOL_STEP
			_adjust_volume(_options_cursor, delta)
		elif _options_cursor == 3 or _options_cursor == 4:
			_flip_toggle(_options_cursor)
	elif _confirm():
		if _options_cursor == 3 or _options_cursor == 4:
			_flip_toggle(_options_cursor)
		elif _options_cursor == OPT_ROWS.size() - 1:   # BACK
			Audio.play("click")
			_set_overlay(OVERLAY_NONE)


# Row 3 = FULLSCREEN, row 4 = TUTORIAL (the HOW TO PLAY overlay before each match).
func _flip_toggle(row: int) -> void:
	if row == 3:
		Settings.set_fullscreen(not Settings.fullscreen)
	else:
		Settings.set_show_tutorial(not Settings.show_tutorial)
	Audio.play("click")
	_refresh_options()


func _process_credits() -> void:
	if Input.is_action_just_pressed("menu_cancel") or _confirm():
		Audio.play("click")
		_set_overlay(OVERLAY_NONE)


func _adjust_volume(row: int, delta: float) -> void:
	match row:
		0: Settings.set_master_volume(Settings.master_volume + delta)
		1: Settings.set_music_volume(Settings.music_volume + delta)
		2: Settings.set_sfx_volume(Settings.sfx_volume + delta)
	Audio.play("click")   # audible feedback — lets you hear an SFX-volume change
	_refresh_options()


# --- Rendering -------------------------------------------------------------

func _set_overlay(kind: int) -> void:
	_overlay = kind
	if _options_panel != null:
		_options_panel.visible = (kind == OVERLAY_OPTIONS)
	if _credits_panel != null:
		_credits_panel.visible = (kind == OVERLAY_CREDITS)
	if kind == OVERLAY_OPTIONS:
		_options_cursor = 0
		_refresh_options()
	# A short lockout so the opening/closing press doesn't immediately act again.
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.18


func _refresh() -> void:
	for i in _buttons.size():
		var slug: String = BUTTON_SLUGS[i]
		var state: int
		if _press_until > 0.0 and _press_action == i:
			state = 2   # pressed
		elif i == cursor:
			state = 1   # hover (= selected)
		else:
			state = 0   # normal
		_buttons[i].texture = load(BTN_TEX[slug][state])


func _refresh_options() -> void:
	var vols: Array = [Settings.master_volume, Settings.music_volume, Settings.sfx_volume]
	for i in OPT_ROWS.size():
		var sel: bool = (i == _options_cursor)
		var label: Label = _opt_rows[i]
		var text: String
		if i < 3:
			text = "%s   %s" % [_pad_name(String(OPT_ROWS[i])), _vol_bar(float(vols[i]))]
		elif i == 3:
			var on: String = "ON" if Settings.fullscreen else "OFF"
			text = "%s   ◄ %s ►" % [_pad_name("FULLSCREEN"), on]
		elif i == 4:
			var t_on: String = "ON" if Settings.show_tutorial else "OFF"
			text = "%s   ◄ %s ►" % [_pad_name("TUTORIAL"), t_on]
		else:
			text = "BACK"
		label.text = ("▶  " if sel else "    ") + text
		label.add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)


func _pad_name(name: String) -> String:
	return name + " ".repeat(maxi(0, 10 - name.length()))


func _vol_bar(v: float) -> String:
	var filled: int = clampi(int(round(v * BAR_SEGMENTS)), 0, BAR_SEGMENTS)
	return "◄ " + "▮".repeat(filled) + "▯".repeat(BAR_SEGMENTS - filled) + " ►"
