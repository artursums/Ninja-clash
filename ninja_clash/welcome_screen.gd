extends Control
## A short, skippable title reveal. Navigation belongs to the parent screen controller.

signal completed

const UI := preload("res://menu_ui.gd")
const Ambience := preload("res://title_ambience.gd")
const HOLD_SECONDS := 2.4

var _finished := false
var _ambience: Control
var _content: Control
var _fade: ColorRect
var _reveal: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	UI.image(self, UI.BACKGROUND, Rect2(0, 0, 800, 450)).stretch_mode = TextureRect.STRETCH_SCALE
	_ambience = Ambience.new()
	add_child(_ambience)
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, 0.72))
	_content = Control.new()
	_content.size = Vector2(800, 450)
	_content.pivot_offset = _content.size / 2
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var greeting := UI.label(_content, "WELCOME TO", Rect2(90, 127, 620, 30), 22, UI.GOLD, true)
	var title := UI.label(_content, "FOUR CLANS", Rect2(70, 169, 660, 76), 62, UI.IVORY, true)
	var subtitle := UI.label(_content, "SHINOBI ARENA", Rect2(90, 262, 620, 28), 20, UI.MUTED, true)
	var line := UI.fill(_content, Rect2(332, 251, 136, 2), UI.GOLD)
	line.pivot_offset = Vector2(68, 1)
	_fade = UI.fill(self, Rect2(0, 0, 800, 450), UI.INK)
	_fade.modulate.a = 0
	for part in [greeting, title, subtitle]:
		part.modulate.a = 0
	line.scale.x = 0
	_content.scale = Vector2(0.97, 0.97)
	_reveal = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_reveal.tween_property(greeting, "modulate:a", 1.0, 0.5)
	_reveal.tween_property(title, "modulate:a", 1.0, 0.7).set_delay(0.3)
	_reveal.tween_property(subtitle, "modulate:a", 1.0, 0.5).set_delay(0.65)
	_reveal.tween_property(line, "scale:x", 1.0, 0.65).set_delay(0.3)
	_reveal.tween_property(_content, "scale", Vector2.ONE, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reveal.chain().tween_interval(HOLD_SECONDS)
	_reveal.chain().tween_callback(finish)

func finish() -> void:
	if _finished or not visible:
		return
	_finished = true
	if _reveal and _reveal.is_valid():
		_reveal.kill()
	var transition := create_tween().set_ignore_time_scale(true)
	transition.tween_property(_fade, "modulate:a", 1.0, 0.3)
	transition.tween_callback(func() -> void: completed.emit())

func _input(event: InputEvent) -> void:
	if not visible or _finished:
		return
	var skip: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]
	if event is InputEventJoypadButton and event.pressed:
		skip = event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]
	if event is InputEventMouseButton:
		skip = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if skip:
		get_viewport().set_input_as_handled()
		Audio.play_music(Audio.MENU_MUSIC_PATH)
		finish()

func _process(delta: float) -> void:
	if visible and not _finished:
		_ambience.advance(minf(delta, 0.1))
