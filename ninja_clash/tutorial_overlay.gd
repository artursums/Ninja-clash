# HOW TO PLAY overlay — shown over the loaded arena at MATCH_INTRO (round 1 only, before the
# countdown starts). Three tabs cover every input variant: the WASD keyboard scheme (P1), the
# numpad scheme (P2, same-computer second player) and gamepads (DualSense / Xbox — positional
# buttons, so one tab covers both). Every bound action is listed with a short explanation.
#
#   ◄ / ► (any player's left/right)         — switch tab
#   ✕ / Space / Enter / numpad-Enter / Esc  — close → main.gd starts the countdown
#
# Can be turned off with the TUTORIAL toggle in OPTIONS (title screen) or Pause ▸ Settings;
# the choice persists via SettingsStore. main.gd connects `closed` to _start_countdown().
extends Control

signal closed

const COL_SEL := Color("d4a830")     # gold — active tab / action names
const COL_DIM := Color("a8a498")     # muted — descriptions, inactive tabs
const COL_HEAD := Color("f0eee8")    # near-white — key chips
const COL_PANEL := Color("1a1726")   # dark panel (matches title-screen overlays)
const COL_CHIP := Color("2a2438")    # key-chip plate

const TAB_TITLES: Array = ["KEYBOARD — P1", "NUMPAD — P2", "GAMEPAD"]

# Rows per tab: [key, action, description]. Kept complete — every bound button appears,
# including the ones easy to forget (guard, dash button, skin cycle, fight setup).
const TAB_ROWS: Array = [
	[   # KEYBOARD — P1 (the solo / testing player)
		["A / D", "MOVE", "Run left / right"],
		["W / S", "AIM", "Aim throws and dashes up / down"],
		["SPACE", "JUMP", "Jump — press on a wall to wall-jump"],
		["W W / A A / S S / D D", "DASH", "Double-tap a direction — i-frame burst, catches shurikens"],
		["LEFT SHIFT", "DASH", "Same dash on a single button"],
		["L  (hold)", "SHURIKEN", "Hold to aim (reticle), release to throw — tap = quick-draw"],
		["K", "KATANA", "Melee slash — blades that meet CLASH and deflect"],
		["J  (hold)", "GUARD", "Block hits from the front — drains the guard meter"],
		["ENTER", "CONFIRM", "Lock in / confirm in menus"],
		["P", "SKIN", "Cycle your skin on the clan-select screen"],
		["TAB", "FIGHT SETUP", "Open match variants from clan select"],
		["ESC", "PAUSE / BACK", "Pause the round — back out of menus"],
	],
	[   # NUMPAD — P2 (second player on the same keyboard)
		["4 / 6", "MOVE", "Run left / right"],
		["8 / 5", "AIM", "Aim throws and dashes up / down"],
		["0", "JUMP", "Jump — press on a wall to wall-jump"],
		["8 8 / 4 4 / 5 5 / 6 6", "DASH", "Double-tap a direction — i-frame burst, catches shurikens"],
		["+", "DASH", "Same dash on a single button"],
		["1  (hold)", "SHURIKEN", "Hold to aim (reticle), release to throw — tap = quick-draw"],
		["2", "KATANA", "Melee slash — blades that meet CLASH and deflect"],
		["3  (hold)", "GUARD", "Block hits from the front — drains the guard meter"],
		["NUMPAD ENTER", "CONFIRM", "Lock in / confirm in menus"],
		["7", "SKIN", "Cycle your skin on the clan-select screen"],
		["", "", ""],
		["NUM LOCK", "REQUIRED", "Numpad keys only register while NUM LOCK is ON"],
	],
	[   # GAMEPAD — DualSense / Xbox (positional layout: ✕=A, ◯=B, ▢=X, △=Y)
		["STICK / D-PAD", "MOVE + AIM", "Run and aim throws / dashes (8-way)"],
		["✕ / A", "JUMP", "Jump — press on a wall to wall-jump · confirm in menus"],
		["▢ / X  (hold)", "SHURIKEN", "Hold to aim (reticle), release to throw — tap = quick-draw"],
		["△ / Y", "KATANA", "Melee slash — blades that meet CLASH and deflect"],
		["◯/B · L1/LB · R1/RB", "DASH", "I-frame burst toward your aim — catches shurikens"],
		["R2 / RT", "DASH", "Same dash on the trigger"],
		["L2 / LT  (hold)", "GUARD", "Block hits from the front — drains the guard meter"],
		["▢ / X", "SKIN", "Cycle your skin on the clan-select screen"],
		["SHARE / VIEW", "FIGHT SETUP", "Open match variants from clan select"],
		["OPTIONS / MENU", "PAUSE", "Pause the round"],
		["", "", ""],
		["2–4 PADS", "COUCH PLAY", "1st pad = P1, 2nd = P2 … hot-plug any time"],
	],
]

# Shared ground rules shown under every tab — the mechanics no button list explains.
const FOOT_TIPS := "Shurikens stick where they land — walk over one to pick it back up.  Land feet-first on a head for a stomp kill."

const ROW_COUNT := 12
const ROW_H := 23.0
const ROWS_TOP := 118.0
const PANEL_X := 40.0
const PANEL_W := 720.0
const CHIP_X := 60.0
const CHIP_W := 168.0
const NAME_X := 240.0
const NAME_W := 116.0
const DESC_X := 362.0
const DESC_W := 380.0

var tab: int = 0
var _input_lockout_until: float = 0.0

var _tab_labels: Array = []     # 3 Label — tab headers
var _chips: Array = []          # ROW_COUNT ColorRect — key-chip plates
var _chip_labels: Array = []    # ROW_COUNT Label — key text
var _name_labels: Array = []    # ROW_COUNT Label — action name
var _desc_labels: Array = []    # ROW_COUNT Label — description


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	# Safety: any state change away from MATCH_INTRO closes the overlay without starting a countdown.
	GameState.state_changed.connect(func(s: int):
		if visible and s != GameState.State.MATCH_INTRO:
			visible = false)


func open() -> void:
	tab = 0
	visible = true
	# Long enough that the map-select confirm press can never leak through and skip the tutorial.
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.35
	_refresh()


func _close() -> void:
	visible = false
	Audio.play("confirm")
	closed.emit()


func _build() -> void:
	# Dim the loaded arena behind — the match is visible, just held back.
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.02, 0.02, 0.07, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := ColorRect.new()
	panel.color = COL_PANEL
	panel.position = Vector2(PANEL_X, 14.0)
	panel.size = Vector2(PANEL_W, 422.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var border := ColorRect.new()
	border.color = Color("3a3450")
	border.position = Vector2(PANEL_X, 11.0)
	border.size = Vector2(PANEL_W, 3.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	var head := _label(0.0, 24.0, 800.0, 32.0, 28, COL_SEL)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.text = "HOW TO PLAY"

	# Tab row — "◄  TAB1   TAB2   TAB3  ►" (arrows hint the switch input).
	var tab_w: float = 200.0
	var tabs_total: float = TAB_TITLES.size() * tab_w
	var tabs_x: float = (800.0 - tabs_total) / 2.0
	for i in TAB_TITLES.size():
		var tl := _label(tabs_x + i * tab_w, 68.0, tab_w, 22.0, 15, COL_DIM)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tab_labels.append(tl)
	var arr_l := _label(tabs_x - 26.0, 68.0, 22.0, 22.0, 15, COL_SEL)
	arr_l.text = "◄"
	var arr_r := _label(tabs_x + tabs_total + 4.0, 68.0, 22.0, 22.0, 15, COL_SEL)
	arr_r.text = "►"

	# Binding rows: [key chip][ACTION][description].
	for i in ROW_COUNT:
		var y: float = ROWS_TOP + i * ROW_H
		var chip := ColorRect.new()
		chip.color = COL_CHIP
		chip.position = Vector2(CHIP_X, y + 1.0)
		chip.size = Vector2(CHIP_W, ROW_H - 4.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
		_chips.append(chip)
		var cl := _label(CHIP_X, y, CHIP_W, ROW_H, 12, COL_HEAD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chip_labels.append(cl)
		_name_labels.append(_label(NAME_X, y, NAME_W, ROW_H, 13, COL_SEL))
		_desc_labels.append(_label(DESC_X, y, DESC_W, ROW_H, 12, COL_DIM))

	# Shared mechanics tips + the close / disable hints.
	var tips := _label(PANEL_X, 398.0, PANEL_W, 16.0, 11, COL_DIM)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips.text = FOOT_TIPS
	var hint := _label(PANEL_X, 416.0, PANEL_W, 18.0, 13, COL_SEL)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "✕ / SPACE / ENTER — START      ◄ ► — SWITCH TAB      turn off: OPTIONS ▸ TUTORIAL"


func _label(x: float, y: float, w: float, h: float, font_size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, h)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl


func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if _nav("left"):
		tab = (tab + TAB_TITLES.size() - 1) % TAB_TITLES.size()
		Audio.play("click")
		_refresh()
	elif _nav("right"):
		tab = (tab + 1) % TAB_TITLES.size()
		Audio.play("click")
		_refresh()
	elif _nav("jump") or _nav("confirm") or Input.is_action_just_pressed("menu_cancel"):
		_close()


func _nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)


func _refresh() -> void:
	for i in TAB_TITLES.size():
		var sel: bool = (i == tab)
		_tab_labels[i].text = ("[ %s ]" % TAB_TITLES[i]) if sel else String(TAB_TITLES[i])
		_tab_labels[i].add_theme_color_override("font_color", COL_SEL if sel else COL_DIM)
	var rows: Array = TAB_ROWS[tab]
	for i in ROW_COUNT:
		var row: Array = rows[i] if i < rows.size() else ["", "", ""]
		var blank: bool = String(row[0]) == "" and String(row[1]) == ""
		_chips[i].visible = not blank
		_chip_labels[i].text = String(row[0])
		_name_labels[i].text = String(row[1])
		_desc_labels[i].text = String(row[2])
