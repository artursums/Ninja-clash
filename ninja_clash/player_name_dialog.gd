extends Control

const UI := preload("res://menu_ui.gd")
const Roster := preload("res://online_roster.gd")
const Keyboard := preload("res://name_keyboard.gd")
const NAME_HINT := "Required · up to 16 characters · this session only"
signal accepted(display_name: String)
signal cancelled
var field: LineEdit
var continue_button: Button
var back_button: Button
var keyboard_button: Button
var keyboard: Control
var hint: Label
var _panel: Panel
var _title: Label
var _subtitle: Label
var _lockout := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, 0.96))
	_panel = UI.panel(self, Rect2(170, 100, 460, 292), UI.GOLD)
	_title = UI.label(self, "WHAT'S YOUR NAME?", Rect2(194, 120, 412, 36), 30, UI.IVORY, true)
	_subtitle = UI.label(self, "Your friends will see this in the lobby and match.", Rect2(190, 160, 420, 24), 16, UI.MUTED, true)
	field = LineEdit.new()
	field.placeholder_text = "Player name"
	field.max_length = Roster.MAX_NAME_LENGTH
	field.deselect_on_focus_loss_enabled = false
	field.add_theme_font_override("font", UI.FONT)
	field.add_theme_font_size_override("font_size", 24)
	add_child(field)
	hint = UI.label(self, NAME_HINT, Rect2(192, 248, 416, 24), 15, UI.MUTED, true)
	back_button = UI.button(self, "BACK", Rect2(210, 288, 140, 44), func(): cancelled.emit())
	continue_button = UI.button(self, "CONTINUE", Rect2(366, 288, 224, 44), _submit)
	keyboard_button = UI.button(self, "ON-SCREEN KEYBOARD", Rect2(210, 344, 380, 32), func(): _show_keyboard(not keyboard.visible), 17)
	for button in [back_button, continue_button, keyboard_button]:
		button.focus_mode = Control.FOCUS_ALL
	keyboard = Keyboard.new()
	add_child(keyboard)
	keyboard.hide()
	keyboard.typed.connect(_insert)
	keyboard.erase_requested.connect(_erase)
	field.text_changed.connect(func(_value: String): _refresh_name())
	field.text_submitted.connect(func(_value: String): _submit())
	visibility_changed.connect(_on_visibility_changed)
	_layout()
	_refresh_name()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_lockout = Time.get_ticks_msec() / 1000.0 + 0.2
		field.text = ""
		_refresh_name()
		keyboard.reset_case()
		_show_keyboard(not Input.get_connected_joypads().is_empty())

func _show_keyboard(show_keys: bool) -> void:
	keyboard.visible = show_keys
	_layout()
	if is_visible_in_tree():
		(keyboard.rows[1][0] if show_keys else field).grab_focus()

func _layout() -> void:
	var expanded: bool = keyboard.visible
	_panel.position = Vector2(130, 16) if expanded else Vector2(170, 100)
	_panel.size = Vector2(540, 418) if expanded else Vector2(460, 292)
	_title.position.y = 28 if expanded else 120
	_subtitle.position.y = 65 if expanded else 160
	field.position = Vector2(166, 96) if expanded else Vector2(210, 198)
	field.size = Vector2(468, 40) if expanded else Vector2(380, 44)
	hint.position.y = 138 if expanded else 248
	back_button.position = Vector2(166, 376) if expanded else Vector2(210, 288)
	back_button.size = Vector2(100, 36) if expanded else Vector2(140, 44)
	keyboard_button.position = Vector2(274, 376) if expanded else Vector2(210, 344)
	keyboard_button.size = Vector2(160, 36) if expanded else Vector2(380, 32)
	keyboard_button.text = "HIDE KEYBOARD" if expanded else "ON-SCREEN KEYBOARD"
	continue_button.position = Vector2(442, 376) if expanded else Vector2(366, 288)
	continue_button.size = Vector2(192, 36) if expanded else Vector2(224, 44)

func _refresh_name() -> void:
	continue_button.disabled = Roster.clean_name(field.text) == ""
	hint.text = NAME_HINT

func _delete_selection() -> bool:
	if not field.has_selection():
		return false
	var start := field.get_selection_from_column()
	field.delete_text(start, field.get_selection_to_column())
	field.caret_column = start
	field.deselect()
	return true

func _insert(value: String) -> void:
	_delete_selection()
	field.insert_text_at_caret(value)
	_refresh_name()
	Audio.play("click")

func _erase() -> void:
	if not _delete_selection() and field.caret_column > 0:
		var start := field.get_previous_composite_character_column(field.caret_column)
		field.delete_text(start, field.caret_column)
		field.caret_column = start
	_refresh_name()
	Audio.play("click")

func _submit() -> void:
	var value := Roster.clean_name(field.text)
	if value == "":
		hint.text = "Please enter your name to continue."
		(keyboard.rows[1][0] if keyboard.visible else field).grab_focus()
		return
	accepted.emit(value)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Consume native GUI handling so each pad press has exactly one effect.
		get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() / 1000.0 < _lockout:
		return
	if event.is_action_pressed("menu_cancel"):
		get_viewport().set_input_as_handled()
		if keyboard.visible:
			_show_keyboard(false)
		else:
			cancelled.emit()
	elif event is InputEventKey and event.pressed and not field.has_focus():
		if event.keycode == KEY_BACKSPACE:
			_erase()
			get_viewport().set_input_as_handled()
		elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed:
			field.grab_focus()

func _focus_rows() -> Array:
	var rows: Array = [[field]]
	if keyboard.visible:
		rows.append_array(keyboard.rows)
		rows.append([back_button, keyboard_button, continue_button])
	else:
		rows.append([back_button, continue_button])
		rows.append([keyboard_button])
	return rows.map(func(row: Array) -> Array:
		return row.filter(func(control: Control) -> bool: return not (control is Button and control.disabled)))

func _navigate(dx: int, dy: int) -> void:
	var rows := _focus_rows()
	var focus := get_viewport().gui_get_focus_owner()
	for i in rows.size():
		var column: int = rows[i].find(focus)
		if column < 0:
			continue
		if dx != 0:
			rows[i][posmod(column + dx, rows[i].size())].grab_focus()
		else:
			var next: Array = rows[posmod(i + dy, rows.size())]
			var x: float = focus.get_global_rect().get_center().x
			next.sort_custom(func(a: Control, b: Control) -> bool:
				return absf(a.get_global_rect().get_center().x - x) < absf(b.get_global_rect().get_center().x - x))
			next[0].grab_focus()
		return
	field.grab_focus()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or Time.get_ticks_msec() / 1000.0 < _lockout:
		return
	if UI.pad_nav("aim_up"):
		_navigate(0, -1)
	elif UI.pad_nav("aim_down"):
		_navigate(0, 1)
	elif UI.pad_nav("left"):
		_navigate(-1, 0)
	elif UI.pad_nav("right"):
		_navigate(1, 0)
	elif UI.pad_nav("skin") and keyboard.visible:
		_erase()
	elif Input.is_action_just_pressed("online_start"):
		_submit()
	elif UI.pad_nav("jump"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus == field:
			_show_keyboard(true)
		elif focus is Button and not focus.disabled:
			focus.pressed.emit()
