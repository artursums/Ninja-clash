## Keyboard layouts and hot-plugged controller assignment, scoped to the game scene.

extends Node

func _ready() -> void:
	preload("res://menu_ui.gd").setup_gamepad_actions()
	_add_key("p1_left",     KEY_A)
	_add_key("p1_right",    KEY_D)
	_add_key("p1_aim_up",   KEY_W)
	_add_key("p1_aim_down", KEY_S)
	_add_key("p1_jump",     KEY_SPACE)
	_add_key("p1_throw",    KEY_L)
	_add_key("p1_katana",   KEY_K)
	_add_key("p1_dodge",    KEY_SHIFT, KEY_LOCATION_LEFT)
	_add_key("p1_defend",   KEY_J)
	_add_key("p2_left",     KEY_KP_4)
	_add_key("p2_right",    KEY_KP_6)
	_add_key("p2_aim_up",   KEY_KP_8)
	_add_key("p2_aim_down", KEY_KP_5)
	_add_key("p2_jump",     KEY_KP_0)
	_add_key("p2_throw",    KEY_KP_1)
	_add_key("p2_katana",   KEY_KP_2)
	_add_key("p2_defend",   KEY_KP_3)
	_add_key("p2_dodge",    KEY_KP_ADD)
	_add_key("p1_skin",     KEY_P)
	_add_key("p2_skin",     KEY_KP_7)
	_append_key("p1_left",     KEY_LEFT)
	_append_key("p1_right",    KEY_RIGHT)
	_append_key("p1_aim_up",   KEY_UP)
	_append_key("p1_aim_down", KEY_DOWN)
	_rebind_gamepads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_add_key("menu_cancel", KEY_ESCAPE)
	_add_pad_button("menu_cancel", JOY_BUTTON_B, -1)
	_add_key("online_start", KEY_F)
	_add_pad_button("online_start", JOY_BUTTON_START, -1)
	_add_key("menu_random", KEY_X)
	_add_pad_button("menu_random", JOY_BUTTON_Y, -1)
	_add_key("menu_pause", KEY_ESCAPE)
	_add_pad_button("menu_pause", JOY_BUTTON_START, -1)
	_add_key("menu_setup", KEY_TAB)
	_add_pad_button("menu_setup", JOY_BUTTON_BACK, -1)
	_add_key("p1_confirm", KEY_ENTER)
	_add_key("p2_confirm", KEY_KP_ENTER)

func _add_pad(player: int, device: int) -> void:
	var prefix: String = "p%d" % player
	_add_pad_button(prefix + "_left",     JOY_BUTTON_DPAD_LEFT,  device)
	_add_pad_axis(  prefix + "_left",     JOY_AXIS_LEFT_X, -1.0, device)
	_add_pad_button(prefix + "_right",    JOY_BUTTON_DPAD_RIGHT, device)
	_add_pad_axis(  prefix + "_right",    JOY_AXIS_LEFT_X,  1.0, device)
	_add_pad_button(prefix + "_aim_up",   JOY_BUTTON_DPAD_UP,    device)
	_add_pad_axis(  prefix + "_aim_up",   JOY_AXIS_LEFT_Y, -1.0, device)
	_add_pad_button(prefix + "_aim_down", JOY_BUTTON_DPAD_DOWN,  device)
	_add_pad_axis(  prefix + "_aim_down", JOY_AXIS_LEFT_Y,  1.0, device)
	_add_pad_button(prefix + "_jump",   JOY_BUTTON_A, device)
	_add_pad_button(prefix + "_throw",  JOY_BUTTON_X, device)
	_add_pad_button(prefix + "_dodge",  JOY_BUTTON_B, device)
	_add_pad_button(prefix + "_dodge",  JOY_BUTTON_LEFT_SHOULDER,  device)
	_add_pad_button(prefix + "_dodge",  JOY_BUTTON_RIGHT_SHOULDER, device)
	_add_pad_button(prefix + "_katana", JOY_BUTTON_Y, device)
	_add_pad_axis(prefix + "_defend", JOY_AXIS_TRIGGER_LEFT,  1.0, device)
	_add_pad_axis(prefix + "_slide",  JOY_AXIS_TRIGGER_RIGHT, 1.0, device)

const PAD_ACTIONS := ["left", "right", "aim_up", "aim_down", "jump", "throw", "dodge", "katana", "defend", "slide", "skin"]

# Device IDs can change on reconnect. Preserve keyboard events while replacing pad events.
func _rebind_gamepads() -> void:
	var pads: Array = Input.get_connected_joypads()
	pads.sort()
	for player in [1, 2, 3, 4]:
		for action in PAD_ACTIONS:
			var name: String = "p%d_%s" % [player, action]
			if not InputMap.has_action(name):
				InputMap.add_action(name)
			_clear_pad_events(name)
	for i in mini(pads.size(), 4):
		_add_pad(i + 1, pads[i])
		_add_pad_button("p%d_skin" % (i + 1), JOY_BUTTON_X, pads[i])

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_rebind_gamepads()

func _clear_pad_events(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		return
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			InputMap.action_erase_event(action_name, ev)

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

func _append_key(action_name: String, key: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	InputMap.action_add_event(action_name, ev)

func _add_pad_button(action_name: String, button: int, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	InputMap.action_add_event(action_name, ev)

func _add_pad_axis(action_name: String, axis: int, axis_value: float, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	ev.device = device
	InputMap.action_add_event(action_name, ev)
