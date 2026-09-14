extends Control

const UI := preload("res://menu_ui.gd")
const Roster := preload("res://online_roster.gd")
const NAME_HINT := "Required · up to 16 characters · this session only"
signal accepted(display_name: String)
signal cancelled
var field: LineEdit
var continue_button: Button
var back_button: Button
var hint: Label
var _lockout := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, 0.96))
	UI.panel(self, Rect2(170, 100, 460, 252), UI.GOLD)
	UI.label(self, "WHAT'S YOUR NAME?", Rect2(194, 120, 412, 36), 30, UI.IVORY, true)
	UI.label(self, "Your friends will see this in the lobby and match.", Rect2(190, 160, 420, 24), 16, UI.MUTED, true)
	field = LineEdit.new()
	field.position = Vector2(210, 198)
	field.size = Vector2(380, 44)
	field.placeholder_text = "Player name"
	field.max_length = Roster.MAX_NAME_LENGTH
	field.add_theme_font_override("font", UI.FONT)
	field.add_theme_font_size_override("font_size", 24)
	add_child(field)
	hint = UI.label(self, NAME_HINT, Rect2(192, 248, 416, 24), 15, UI.MUTED, true)
	back_button = UI.button(self, "BACK", Rect2(210, 288, 140, 44), func(): cancelled.emit())
	back_button.focus_mode = Control.FOCUS_ALL
	continue_button = UI.button(self, "CONTINUE", Rect2(366, 288, 224, 44), _submit)
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.disabled = true
	field.text_changed.connect(func(value: String):
		continue_button.disabled = Roster.clean_name(value) == ""
		hint.text = NAME_HINT)
	field.text_submitted.connect(func(_value: String): _submit())
	visibility_changed.connect(func():
		if visible:
			_lockout = Time.get_ticks_msec() / 1000.0 + 0.2
			field.text = ""
			hint.text = NAME_HINT
			continue_button.disabled = true
			field.grab_focus.call_deferred())

func _submit() -> void:
	var value := Roster.clean_name(field.text)
	if value == "":
		hint.text = "Please enter your name to continue."
		field.grab_focus()
		return
	accepted.emit(value)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Handle pad focus once per frame, without also triggering built-in UI actions.
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("menu_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or Time.get_ticks_msec() / 1000.0 < _lockout:
		return
	if UI.pad_nav("aim_up"):
		field.grab_focus()
	elif UI.pad_nav("aim_down"):
		(back_button if continue_button.disabled else continue_button).grab_focus()
	elif UI.pad_nav("left") and not field.has_focus():
		back_button.grab_focus()
	elif UI.pad_nav("right") and not field.has_focus() and not continue_button.disabled:
		continue_button.grab_focus()
	elif UI.pad_nav("jump"):
		if back_button.has_focus():
			cancelled.emit()
		else:
			_submit()
