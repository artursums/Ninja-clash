extends Control

const UI = preload("res://menu_ui.gd")

const PAGE_MENU := 0
const PAGE_SETTINGS := 1

const MENU_ITEMS: Array = ["RESUME", "RESTART MATCH", "SETTINGS", "QUIT TO MENU"]
const SETTINGS_NAMES: Array = ["MASTER", "MUSIC", "SFX"]   # rows 0-2; row 3 = TUTORIAL, row 4 = BACK
const VOL_STEP := 0.1
const ROW_COUNT := 4        # menu page rows (and the plates both pages share)
const SET_ROW_COUNT := 5    # settings page rows: 3 volumes + TUTORIAL + BACK
const TUT_ROW := 3          # settings row index of the TUTORIAL toggle

const COL_SEL := UI.GOLD    # highlighted row (matches the menu accent)
const COL_DIM := UI.IVORY

const SEG_COUNT := 10
const PLATE_W := 300.0
const PLATE_H := 46.0
const PLATE_STEP := 52.0
const PLATE_TOP := 110.0
const PLATE_CX := (800.0 - PLATE_W) / 2.0   # 250

var _paused: bool = false
var _page: int = PAGE_MENU
var _menu_cursor: int = 0
var _settings_cursor: int = 0
var _input_lockout_until: float = 0.0

var _hdr_paused: Label
var _hdr_settings: Label
var _plates: Array[Button] = []
var _menu_labels: Array = []   # 4 Label — menu page item text
var _set_names: Array = []     # 3 Label — MASTER/MUSIC/SFX
var _bars: Array = []
var _pcts: Array = []          # 3 Label — "80%"
var _tut_label: Label          # settings row 3 — "TUTORIAL      ◄ ON ►"
var _back_label: Label
var _cursor: Label


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
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.02, 0.025, 0.06, 0.88))
	UI.panel(self, Rect2(200, 30, 400, 388), UI.GOLD)
	_hdr_paused = UI.label(self, "PAUSED", Rect2(200, 49, 400, 40), 34, UI.GOLD, true)
	_hdr_settings = UI.label(self, "SETTINGS", Rect2(200, 49, 400, 40), 34, UI.GOLD, true)
	for i in SET_ROW_COUNT:
		var plate := UI.button(self, "", Rect2(PLATE_CX, PLATE_TOP + i * PLATE_STEP, PLATE_W, PLATE_H), _mouse_activate.bind(i))
		plate.mouse_entered.connect(_mouse_hover.bind(i))
		_plates.append(plate)
		if i < ROW_COUNT:
			_menu_labels.append(UI.label(self, MENU_ITEMS[i], Rect2(PLATE_CX, PLATE_TOP + i * PLATE_STEP, PLATE_W, PLATE_H), 22, UI.IVORY, true))
	for i in 3:
		var y := PLATE_TOP + i * PLATE_STEP
		_set_names.append(UI.label(self, SETTINGS_NAMES[i], Rect2(PLATE_CX + 12, y, 90, PLATE_H), 18))
		var segs: Array = []
		var track := UI.fill(self, Rect2(PLATE_CX + 131, y + 16, 100, 14), UI.INK)
		for j in SEG_COUNT:
			segs.append(UI.fill(self, Rect2(PLATE_CX + 133 + j * 10, y + 18, 7, 10), UI.GOLD))
		var minus := UI.button(_plates[i], "-", Rect2(101, 9, 26, 28), _adjust_volume.bind(i, -0.1), 18)
		var plus := UI.button(_plates[i], "+", Rect2(235, 9, 26, 28), _adjust_volume.bind(i, 0.1), 18)
		_bars.append({"track": track, "segs": segs, "minus": minus, "plus": plus})
		_pcts.append(UI.label(self, "", Rect2(PLATE_CX + 263, y, 36, PLATE_H), 12))
	_tut_label = UI.label(self, "", Rect2(PLATE_CX, PLATE_TOP + 3 * PLATE_STEP, PLATE_W, PLATE_H), 18, UI.IVORY, true)
	_back_label = UI.label(self, "BACK", Rect2(PLATE_CX, PLATE_TOP + 4 * PLATE_STEP, PLATE_W, PLATE_H), 22, UI.IVORY, true)
	_cursor = UI.label(self, ">", Rect2(0, 0, 28, 32), 24, UI.GOLD)
	UI.label(self, "ESC / START  RESUME    LEFT/RIGHT  ADJUST", Rect2(210, 383, 380, 24), 14, UI.MUTED, true)

func _mouse_hover(row: int) -> void:
	if _page == PAGE_MENU:
		_menu_cursor = mini(row, ROW_COUNT - 1)
	else:
		_settings_cursor = row
	_refresh()

func _mouse_activate(row: int) -> void:
	if _page == PAGE_MENU:
		match row:
			0: _resume()
			1: _restart()
			2: _enter_settings()
			3: _quit_to_menu()
	elif row == TUT_ROW:
		Settings.set_show_tutorial(not Settings.show_tutorial)
		_refresh()
	elif row == SET_ROW_COUNT - 1:
		_page = PAGE_MENU
		_refresh()

# --- Open / close ---------------------------------------------------------

func _open() -> void:
	_paused = true
	_page = PAGE_MENU
	_menu_cursor = 0
	visible = true
	# Online the match keeps running (a real pause would freeze the opponent's game too) —
	# instead this machine's gameplay input is muted so menu keys can't steer the fighter.
	if Net.is_online():
		PlayerInput.suppress_local = true
	else:
		get_tree().paused = true
	_lockout()
	Audio.play("confirm")
	_refresh()


func _resume() -> void:
	Audio.play("click")
	_close()


func _restart() -> void:
	if Net.is_client():
		return   # only the host may restart an online match (row shown dimmed)
	Audio.play("confirm")
	_close()
	GameState.start_new_match()   # round 1, same mode/clans/map; emits MATCH_INTRO


func _quit_to_menu() -> void:
	Audio.play("click")
	_close()
	if Net.is_online():
		Net.leave("")   # ends the session for both sides
		GameState.change_state(GameState.State.ONLINE_MENU)
	else:
		GameState.change_state(GameState.State.TITLE)


func _close() -> void:
	_paused = false
	visible = false
	get_tree().paused = false
	PlayerInput.suppress_local = false


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
	return Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
		or Input.is_action_just_pressed("p1_confirm") or Input.is_action_just_pressed("p2_confirm")


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
		_settings_cursor = (_settings_cursor + SET_ROW_COUNT - 1) % SET_ROW_COUNT
		Audio.play("click")
		_refresh()
	elif _nav("aim_down"):
		_settings_cursor = (_settings_cursor + 1) % SET_ROW_COUNT
		Audio.play("click")
		_refresh()
	elif _settings_cursor < SETTINGS_NAMES.size():
		# Resolve the direction once instead of re-querying Input three times per frame.
		var nav_left: bool = _nav("left")
		var nav_right: bool = _nav("right")
		if nav_left or nav_right:
			var delta: float = VOL_STEP if nav_right else -VOL_STEP
			_adjust_volume(_settings_cursor, delta)
	elif _settings_cursor == TUT_ROW:
		if _nav("left") or _nav("right") or _confirm_pressed():
			Settings.set_show_tutorial(not Settings.show_tutorial)
			Audio.play("click")
			_refresh()
	elif _confirm_pressed() and _settings_cursor == SET_ROW_COUNT - 1:   # BACK
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

	# Plate 4 (the settings page's BACK row) exists only on the settings page.
	for i in SET_ROW_COUNT:
		var sel: bool = (i == cursor_row)
		_plates[i].visible = (i < ROW_COUNT) or not menu_page
		UI.select(_plates[i], sel)
		_plates[i].disabled = menu_page and i == 1 and Net.is_client()

	# Menu page: centred item labels. Settings page: hide them.
	for i in ROW_COUNT:
		_menu_labels[i].visible = menu_page
		if menu_page:
			var sel: bool = (i == _menu_cursor)
			_menu_labels[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
	# Online guest: RESTART belongs to the host — show that row disabled.
	if menu_page:
		_menu_labels[1].modulate.a = 0.4 if Net.is_client() else 1.0

	# Settings widgets.
	var vols: Array = [Settings.master_volume, Settings.music_volume, Settings.sfx_volume]
	for i in SETTINGS_NAMES.size():
		var sel: bool = (not menu_page and i == _settings_cursor)
		_set_names[i].visible = not menu_page
		_pcts[i].visible = not menu_page
		_bars[i]["track"].visible = not menu_page
		_bars[i]["minus"].visible = not menu_page
		_bars[i]["plus"].visible = not menu_page
		var segs: Array = _bars[i]["segs"]
		var filled: int = clampi(int(round(float(vols[i]) * SEG_COUNT)), 0, SEG_COUNT)
		for s in SEG_COUNT:
			segs[s].visible = not menu_page
			segs[s].color = UI.GOLD if s < filled else UI.EDGE
		if not menu_page:
			_set_names[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
			_pcts[i].text = "%d%%" % int(round(float(vols[i]) * 100.0))
			_pcts[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)

	# TUTORIAL toggle row (settings page only).
	_tut_label.visible = not menu_page
	if not menu_page:
		var tut_sel: bool = (_settings_cursor == TUT_ROW)
		_tut_label.text = "TUTORIAL          ◄ %s ►" % ("ON" if Settings.show_tutorial else "OFF")
		_tut_label.add_theme_color_override("font_color", COL_SEL if tut_sel else COL_DIM)

	_back_label.visible = not menu_page
	if not menu_page:
		_back_label.add_theme_color_override("font_color", COL_SEL if _settings_cursor == SET_ROW_COUNT - 1 else COL_DIM)

	# Pointer cursor beside the active row.
	var plate_y: float = PLATE_TOP + cursor_row * PLATE_STEP
	_cursor.position = Vector2(PLATE_CX - 28.0 - 10.0, plate_y + (PLATE_H - 32.0) / 2.0)
