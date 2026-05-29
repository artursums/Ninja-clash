# In-match pause overlay. Freezes the tree (get_tree().paused) during a ROUND and shows a menu:
#   PAUSED  → Resume · Restart Match · Settings · Quit to Menu
#   SETTINGS → Master / Music / SFX volume sliders + Back
#
# Runs with PROCESS_MODE_ALWAYS so it keeps processing input while everything else is frozen.
# All pause input lives here (main.gd no longer quits to title on Esc during a round).
#
# Visuals are the sprites/menu/ pause kit: a starfield backdrop, a bamboo scroll panel
# (9-patched so it stretches to a portrait scroll), wooden button plates with overlaid text,
# a pointer cursor, and a segmented volume bar (track + filled/empty segments).
extends Control

const PAGE_MENU := 0
const PAGE_SETTINGS := 1

const MENU_ITEMS: Array = ["RESUME", "RESTART MATCH", "SETTINGS", "QUIT TO MENU"]
const SETTINGS_NAMES: Array = ["MASTER", "MUSIC", "SFX"]   # rows 0-2; row 3 = BACK
const VOL_STEP := 0.1
const ROW_COUNT := 4

const COL_SEL := Color("d4a830")    # highlighted row (matches the menu accent)
const COL_DIM := Color("f0eee8")    # idle button text — cream, readable on the wood plate

const MENU := "res://sprites/menu/"
const SEG_COUNT := 10
const PLATE_W := 300.0
const PLATE_H := 46.0
const PLATE_STEP := 62.0
const PLATE_TOP := 126.0
const PLATE_CX := (800.0 - PLATE_W) / 2.0   # 250
const SCROLL_POS := Vector2(190, 18)
const SCROLL_SIZE := Vector2(420, 414)

var _paused: bool = false
var _page: int = PAGE_MENU
var _menu_cursor: int = 0
var _settings_cursor: int = 0
var _input_lockout_until: float = 0.0

var _hdr_paused: TextureRect
var _hdr_settings: TextureRect
var _plates: Array = []        # 4 TextureRect button plates (shared by both pages)
var _menu_labels: Array = []   # 4 Label — menu page item text
var _set_names: Array = []     # 3 Label — MASTER/MUSIC/SFX
var _bars: Array = []          # 3 Dictionaries { "segs": Array[TextureRect] }
var _pcts: Array = []          # 3 Label — "80%"
var _back_label: Label
var _cursor: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep ticking while the tree is paused
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	# Any state change (restart, quit, or anything else) cleanly closes the overlay + unpauses.
	GameState.state_changed.connect(_on_state_changed)


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = load(MENU + "pause_backdrop_native.png")
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var scroll := NinePatchRect.new()
	scroll.texture = load(MENU + "pause_scroll_panel_native.png")
	scroll.patch_margin_left = 26
	scroll.patch_margin_right = 26
	scroll.patch_margin_top = 70
	scroll.patch_margin_bottom = 70
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.position = SCROLL_POS
	scroll.size = SCROLL_SIZE
	add_child(scroll)

	_hdr_paused = _tex_native(load(MENU + "pause_header_paused_native.png"))
	_hdr_paused.position = Vector2((800.0 - _hdr_paused.size.x) / 2.0, 44.0)
	_hdr_settings = _tex_native(load(MENU + "pause_header_settings_native.png"))
	_hdr_settings.position = Vector2((800.0 - _hdr_settings.size.x) / 2.0, 44.0)

	for i in ROW_COUNT:
		var plate := _tex_sized(load(MENU + "pause_button_normal_native.png"),
				PLATE_CX, PLATE_TOP + i * PLATE_STEP, PLATE_W, PLATE_H)
		_plates.append(plate)

		var lbl := _label(PLATE_CX, PLATE_TOP + i * PLATE_STEP, PLATE_W, PLATE_H, 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = String(MENU_ITEMS[i])
		_menu_labels.append(lbl)

	# Settings widgets (rows 0-2 = volume; row 3 reuses plate 3 as BACK).
	for i in SETTINGS_NAMES.size():
		var plate_y: float = PLATE_TOP + i * PLATE_STEP
		var name_lbl := _label(PLATE_CX + 16.0, plate_y, 80.0, PLATE_H, 18)
		name_lbl.text = String(SETTINGS_NAMES[i])
		_set_names.append(name_lbl)

		# Segmented bar: track recess + 10 segments laid over it.
		var track := _tex_sized(load(MENU + "pause_volume_track_native.png"),
				PLATE_CX + 96.0, plate_y + (PLATE_H - 26.0) / 2.0, 188.0, 26.0)
		var segs: Array = []
		for s in SEG_COUNT:
			var seg := _tex_sized(load(MENU + "pause_volume_segment_empty_native.png"),
					PLATE_CX + 104.0 + s * 17.0, plate_y + (PLATE_H - 15.0) / 2.0, 15.0, 15.0)
			segs.append(seg)
		_bars.append({"track": track, "segs": segs})

		var pct := _label(PLATE_CX + PLATE_W + 6.0, plate_y, 46.0, PLATE_H, 13)
		_pcts.append(pct)

	_back_label = _label(PLATE_CX, PLATE_TOP + 3 * PLATE_STEP, PLATE_W, PLATE_H, 22)
	_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_label.text = "BACK"

	_cursor = _tex_sized(load(MENU + "pause_cursor_native.png"), 0, 0, 28, 32)


# --- Node helpers ---------------------------------------------------------

func _tex_sized(tex: Texture2D, x: float, y: float, w: float, h: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = Vector2(x, y)
	tr.size = Vector2(w, h)
	add_child(tr)
	return tr

func _tex_native(tex: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(tex.get_size())
	add_child(tr)
	return tr

func _label(x: float, y: float, w: float, h: float, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, h)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl


# --- Open / close ---------------------------------------------------------

func _open() -> void:
	_paused = true
	_page = PAGE_MENU
	_menu_cursor = 0
	visible = true
	get_tree().paused = true
	_lockout()
	Audio.play("confirm")
	_refresh()


func _resume() -> void:
	Audio.play("click")
	_close()


func _restart() -> void:
	Audio.play("confirm")
	_close()
	GameState.start_new_match()   # round 1, same mode/clans/map; emits MATCH_INTRO


func _quit_to_menu() -> void:
	Audio.play("click")
	_close()
	GameState.change_state(GameState.State.TITLE)


func _close() -> void:
	_paused = false
	visible = false
	get_tree().paused = false


func _on_state_changed(_s: int) -> void:
	# Safety net: a state change must never leave us paused or showing.
	if _paused or visible:
		_close()


func _lockout() -> void:
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.18


# --- Input ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _paused:
		# Only a live round is pausable (countdown/round-end are brief transitions).
		if GameState.current_state == GameState.State.ROUND and Input.is_action_just_pressed("menu_pause"):
			_open()
		return

	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return

	# Start (menu_pause) backs all the way out and resumes from any page.
	if Input.is_action_just_pressed("menu_pause"):
		_resume()
		return

	if _page == PAGE_MENU:
		_process_menu()
	else:
		_process_settings()


# Navigation works from any pad (p1/p2 D-pad + sticks) or the keyboard.
func _nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


func _confirm_pressed() -> bool:
	return Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump")


func _process_menu() -> void:
	if Input.is_action_just_pressed("menu_cancel"):
		_resume()
		return
	if _nav("aim_up"):
		_menu_cursor = (_menu_cursor + ROW_COUNT - 1) % ROW_COUNT
		Audio.play("click")
		_refresh()
	elif _nav("aim_down"):
		_menu_cursor = (_menu_cursor + 1) % ROW_COUNT
		Audio.play("click")
		_refresh()
	elif _confirm_pressed():
		match _menu_cursor:
			0: _resume()
			1: _restart()
			2: _enter_settings()
			3: _quit_to_menu()


func _enter_settings() -> void:
	_page = PAGE_SETTINGS
	_settings_cursor = 0
	Audio.play("confirm")
	_lockout()
	_refresh()


func _process_settings() -> void:
	if Input.is_action_just_pressed("menu_cancel"):
		_page = PAGE_MENU
		Audio.play("click")
		_lockout()
		_refresh()
		return
	if _nav("aim_up"):
		_settings_cursor = (_settings_cursor + ROW_COUNT - 1) % ROW_COUNT
		Audio.play("click")
		_refresh()
	elif _nav("aim_down"):
		_settings_cursor = (_settings_cursor + 1) % ROW_COUNT
		Audio.play("click")
		_refresh()
	elif _settings_cursor < SETTINGS_NAMES.size():
		# Resolve the direction once instead of re-querying Input three times per frame.
		var nav_left: bool = _nav("left")
		var nav_right: bool = _nav("right")
		if nav_left or nav_right:
			var delta: float = VOL_STEP if nav_right else -VOL_STEP
			_adjust_volume(_settings_cursor, delta)
	elif _confirm_pressed() and _settings_cursor == ROW_COUNT - 1:   # BACK
		_page = PAGE_MENU
		Audio.play("click")
		_lockout()
		_refresh()


func _adjust_volume(row: int, delta: float) -> void:
	match row:
		0: Settings.set_master_volume(Settings.master_volume + delta)
		1: Settings.set_music_volume(Settings.music_volume + delta)
		2: Settings.set_sfx_volume(Settings.sfx_volume + delta)
	Audio.play("click")   # audible feedback — also lets you hear the SFX-volume change
	_refresh()


# --- Rendering ------------------------------------------------------------

func _refresh() -> void:
	var menu_page: bool = (_page == PAGE_MENU)
	var cursor_row: int = _menu_cursor if menu_page else _settings_cursor

	_hdr_paused.visible = menu_page
	_hdr_settings.visible = not menu_page

	for i in ROW_COUNT:
		var sel: bool = (i == cursor_row)
		_plates[i].texture = load(MENU + "pause_button_%s_native.png" % ("hover" if sel else "normal"))

	# Menu page: centred item labels. Settings page: hide them.
	for i in ROW_COUNT:
		_menu_labels[i].visible = menu_page
		if menu_page:
			var sel: bool = (i == _menu_cursor)
			_menu_labels[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)

	# Settings widgets.
	var vols: Array = [Settings.master_volume, Settings.music_volume, Settings.sfx_volume]
	for i in SETTINGS_NAMES.size():
		var sel: bool = (not menu_page and i == _settings_cursor)
		_set_names[i].visible = not menu_page
		_pcts[i].visible = not menu_page
		_bars[i]["track"].visible = not menu_page
		var segs: Array = _bars[i]["segs"]
		var filled: int = clampi(int(round(float(vols[i]) * SEG_COUNT)), 0, SEG_COUNT)
		for s in SEG_COUNT:
			segs[s].visible = not menu_page
			segs[s].texture = load(MENU + "pause_volume_segment_%s_native.png" % ("filled" if s < filled else "empty"))
		if not menu_page:
			_set_names[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
			_pcts[i].text = "%d%%" % int(round(float(vols[i]) * 100.0))
			_pcts[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)

	_back_label.visible = not menu_page
	if not menu_page:
		_back_label.add_theme_color_override("font_color", COL_SEL if _settings_cursor == ROW_COUNT - 1 else COL_DIM)

	# Pointer cursor beside the active row.
	var plate_y: float = PLATE_TOP + cursor_row * PLATE_STEP
	_cursor.position = Vector2(PLATE_CX - 28.0 - 10.0, plate_y + (PLATE_H - 32.0) / 2.0)
