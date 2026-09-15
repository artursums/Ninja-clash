extends Control
## Optional field manual with explicit tab and Start focus for every input device.

signal closed
const UI := preload("res://menu_ui.gd")
const Guide := preload("res://controller_guide.gd")
const TAB_TITLES := ["KEYBOARD", "NUMPAD", "PLAYSTATION", "XBOX"]
const KEY_ROWS := [
	["A / D", "4 / 6", "MOVE", "Run left and right"],
	["W / S", "8 / 5", "AIM", "Aim throws and dashes"],
	["SPACE", "0", "JUMP", "Jump, or kick off a wall"],
	["SHIFT", "+", "DASH", "Dodge and catch blades"],
	["L", "1", "SHURIKEN", "Hold to aim, release to throw"],
	["K", "2", "KATANA", "Strike nearby opponents"],
	["J", "3", "GUARD", "Hold to block from the front"],
	["P", "7", "SKIN", "Change costume before a fight"],
]
var tab := 0
var start_button: Button
var tab_buttons: Array[Button] = []
var focus_start := false
var _content: Control
var _tip: Label
var _input_lockout_until := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.035, 0.07, 0.94))
	UI.panel(self, Rect2(24, 16, 752, 418), UI.EDGE)
	UI.label(self, "HOW TO PLAY", Rect2(44, 28, 500, 34), 30, UI.GOLD)
	UI.label(self, "FIELD MANUAL", Rect2(590, 33, 165, 24), 14, UI.MUTED, true)
	for i in TAB_TITLES.size():
		var button := UI.button(self, TAB_TITLES[i], Rect2(42 + i * 181, 78, 173, 32), _select_tab.bind(i), 16)
		_prepare_focus(button)
		tab_buttons.append(button)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_tip = UI.label(self, "", Rect2(46, 362, 708, 22), 13, UI.MUTED, true)
	start_button = UI.button(self, "START", Rect2(302, 392, 196, 32), _close, 20)
	_prepare_focus(start_button)
	start_button.mouse_entered.connect(func() -> void: _focus(true))
	GameState.state_changed.connect(func(state: int) -> void:
		if state != GameState.State.MATCH_INTRO:
			hide())

func _prepare_focus(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	# Navigation is shared across all pads, independently of Godot's default ui_* bindings.
	for direction in ["left", "right", "top", "bottom", "next", "previous"]:
		button.set("focus_neighbor_" + direction if direction in ["left", "right", "top", "bottom"] else "focus_" + direction, NodePath("."))

func open() -> void:
	tab = 0
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var name := Input.get_joy_name(pads[0]).to_lower()
		var sony := ["playstation", "dualsense", "dualshock", "sony", "ps5", "ps4", "054c"].any(func(part: String) -> bool: return part in name)
		tab = 2 if sony else 3
	show()
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.35
	_select_tab(tab)

func _select_tab(index: int) -> void:
	tab = posmod(index, TAB_TITLES.size())
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if tab >= 2:
		var guide := Guide.new()
		_content.add_child(guide)
		guide.configure(tab == 2)
		_tip.text = "Recover fallen shurikens. The throw button also changes your skin in menus."
	else:
		_build_keyboard()
		_tip.text = "Arrow keys also work for P1." if tab == 0 else "Use a full-size keyboard with Num Lock enabled."
	_focus(false)

func _build_keyboard() -> void:
	for i in KEY_ROWS.size():
		var row: Array = KEY_ROWS[i]
		var x := 44 + (i / 4) * 366
		var y := 130 + (i % 4) * 54
		UI.panel(_content, Rect2(x, y, 86, 37), UI.EDGE)
		UI.label(_content, row[tab], Rect2(x, y, 86, 37), 17, UI.GOLD, true)
		UI.label(_content, row[2], Rect2(x + 98, y - 1, 232, 22), 18)
		UI.label(_content, row[3], Rect2(x + 98, y + 22, 232, 22), 13, UI.MUTED)

func _focus(on_start: bool) -> void:
	focus_start = on_start
	for i in tab_buttons.size():
		UI.select(tab_buttons[i], i == tab, UI.MUTED if focus_start else UI.GOLD)
	UI.select(start_button, focus_start)
	if visible:
		(start_button if focus_start else tab_buttons[tab]).grab_focus()

func _close() -> void:
	if not visible or Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	hide()
	Audio.play("confirm")
	closed.emit()

func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if UI.nav("aim_down"):
		_focus(true)
	elif UI.nav("aim_up"):
		_focus(false)
	elif not focus_start and (UI.nav("left") or UI.nav("right")):
		_select_tab(tab + (1 if UI.nav("right") else -1))
	elif (focus_start and UI.confirm()) or Input.is_action_just_pressed("menu_pause") or Input.is_action_just_pressed("menu_cancel"):
		_close()
