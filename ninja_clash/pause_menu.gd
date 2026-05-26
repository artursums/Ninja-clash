# PROTOTYPE-derived — production overlay.
#
# In-match pause overlay. Freezes the tree (get_tree().paused) during a ROUND and shows a menu:
#   PAUSED  → Resume · Restart Match · Settings · Quit to Menu
#   SETTINGS → Master / Music / SFX volume sliders + Back
#
# Runs with PROCESS_MODE_ALWAYS so it keeps processing input while everything else is frozen.
# All pause input lives here (main.gd no longer quits to title on Esc during a round).
extends Control

const PAGE_MENU := 0
const PAGE_SETTINGS := 1

const MENU_ITEMS: Array = ["RESUME", "RESTART MATCH", "SETTINGS", "QUIT TO MENU"]
const SETTINGS_NAMES: Array = ["MASTER", "MUSIC", "SFX"]   # rows 0-2; row 3 = BACK
const VOL_STEP := 0.1
const ROW_COUNT := 4

const COL_SEL := Color("d4a830")    # highlighted row (matches the menu accent)
const COL_DIM := Color("8a8ea8")
const COL_TITLE := Color("f0eee8")
const COL_HINT := Color("6a6e88")

var _paused: bool = false
var _page: int = PAGE_MENU
var _menu_cursor: int = 0
var _settings_cursor: int = 0
var _input_lockout_until: float = 0.0

var _bg: ColorRect
var _title: Label
var _rows: Array = []
var _hint: Label


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
	_bg = ColorRect.new()
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.color = Color(0.04, 0.04, 0.07, 0.82)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_title = Label.new()
	_title.position = Vector2(0, 86)
	_title.size = Vector2(800, 70)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_color_override("font_color", COL_TITLE)
	add_child(_title)

	var y: float = 178.0
	for i in ROW_COUNT:
		var row: Label = Label.new()
		row.position = Vector2(0, y + i * 46.0)
		row.size = Vector2(800, 36)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 26)
		add_child(row)
		_rows.append(row)

	_hint = Label.new()
	_hint.position = Vector2(0, 408)
	_hint.size = Vector2(800, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", COL_HINT)
	add_child(_hint)


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
	elif _settings_cursor < SETTINGS_NAMES.size() and (_nav("left") or _nav("right")):
		var delta: float = VOL_STEP if _nav("right") else -VOL_STEP
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
	if _page == PAGE_MENU:
		_title.text = "PAUSED"
		for i in ROW_COUNT:
			var sel: bool = (i == _menu_cursor)
			_rows[i].text = ("▶  " if sel else "    ") + String(MENU_ITEMS[i])
			_rows[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
		_hint.text = "↑/↓ select     ✕ / Space confirm     ◯ / Esc back     Start resume"
	else:
		_title.text = "SETTINGS"
		var vols: Array = [Settings.master_volume, Settings.music_volume, Settings.sfx_volume]
		for i in ROW_COUNT:
			var sel: bool = (i == _settings_cursor)
			var prefix: String = "▶  " if sel else "    "
			if i < SETTINGS_NAMES.size():
				var arrows_l: String = "◄ " if sel else "  "
				var arrows_r: String = " ►" if sel else "  "
				_rows[i].text = "%s%-7s%s%s%s" % [prefix, String(SETTINGS_NAMES[i]), arrows_l, _vol_bar(vols[i]), arrows_r]
			else:
				_rows[i].text = prefix + "BACK"
			_rows[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
		_hint.text = "↑/↓ select     ←/→ adjust     ◯ / Esc back     Start resume"


# Text slider: "[||||||....]  60%". Uses only base-font glyphs so it renders everywhere.
func _vol_bar(v: float) -> String:
	var clamped: float = clampf(v, 0.0, 1.0)
	var filled: int = int(round(clamped * 10.0))
	var bar: String = ""
	for i in 10:
		bar += "|" if i < filled else "."
	return "[%s] %3d%%" % [bar, int(round(clamped * 100.0))]
