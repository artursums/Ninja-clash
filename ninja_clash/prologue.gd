extends Control

const UI = preload("res://menu_ui.gd")
const Ambience = preload("res://title_ambience.gd")
const STANDARDS = preload("res://sprites/menu/clan_standards.webp")
const CHAPTERS := [
	{"title": "THE OATH", "text": "Long ago, four ninja clans\nguarded one valley.\n\nShadow. Storm. Frost. Fire.\nTogether, they kept the peace.", "duration": 8.0},
	{"title": "THE SILENCE", "text": "Then the sacred bell fell silent.\nEach clan blamed another.\n\nBy dawn, their ancient oath\nwas broken.", "duration": 8.0},
	{"title": "THE CHALLENGE", "text": "To spare the valley a war,\neach clan sent a champion.\n\nTheir blades would settle\nwhat words could not.", "duration": 9.0},
]

var chapter := -1
var _elapsed := 0.0
var _finished := false
var _lockout := 0.0
var _gate: Control
var _story: Control
var _copy: Control
var _ambience: Control
var _heading: Label
var _body: Label
var _number: Label
var _invitation_hint: Label
var _begin_button: Button
var _progress: ColorRect
var _art: TextureRect
var _caption: Label
var _fade: ColorRect
var _entrance: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var background := UI.image(self, UI.BACKGROUND, Rect2(0, 0, 800, 450))
	background.stretch_mode = TextureRect.STRETCH_SCALE
	_ambience = Ambience.new()
	add_child(_ambience)
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, 0.72))
	UI.fill(self, Rect2(0, 0, 800, 28), UI.INK)
	UI.fill(self, Rect2(0, 422, 800, 28), UI.INK)
	_gate = _layer()
	UI.label(_gate, "A   S H I N O B I   C H R O N I C L E", Rect2(90, 66, 620, 24), 16, UI.GOLD, true)
	UI.label(_gate, "FOUR CLANS", Rect2(90, 106, 620, 68), 58, UI.IVORY, true)
	UI.fill(_gate, Rect2(330, 194, 140, 2), UI.GOLD)
	UI.label(_gate, "One valley. One broken oath.", Rect2(90, 216, 620, 36), 24, UI.IVORY, true)
	_invitation_hint = UI.label(_gate, "Every legend begins with a challenge.", Rect2(90, 258, 620, 28), 18, UI.MUTED, true)
	_begin_button = UI.button(_gate, "BEGIN", Rect2(280, 321, 240, 42), _begin, 23)
	UI.label(_gate, "CLICK OR PRESS ENTER", Rect2(90, 378, 620, 22), 14, UI.MUTED, true)
	_story = _layer()
	_copy = _layer(_story)
	_number = UI.label(_copy, "", Rect2(48, 66, 390, 24), 16, UI.GOLD)
	_heading = UI.label(_copy, "", Rect2(46, 102, 440, 54), 38)
	UI.fill(_copy, Rect2(48, 175, 70, 2), UI.GOLD)
	_body = UI.label(_copy, "", Rect2(48, 190, 430, 153), 23)
	_art = UI.image(_copy, STANDARDS, Rect2(493, 90, 266, 234))
	_caption = UI.label(_copy, "", Rect2(472, 334, 304, 25), 14, UI.GOLD, true)
	UI.button(_story, "CONTINUE  >", Rect2(48, 380, 180, 30), _advance, 16)
	UI.label(_story, "ENTER", Rect2(242, 380, 90, 30), 14, UI.MUTED)
	UI.button(_story, "SKIP INTRO  /  ESC", Rect2(570, 380, 182, 30), _finish, 14)
	UI.fill(_story, Rect2(48, 365, 704, 1), UI.EDGE)
	_progress = UI.fill(_story, Rect2(48, 365, 0, 1), UI.GOLD)
	_story.hide()
	_fade = UI.fill(self, Rect2(0, 0, 800, 450), UI.INK)
	_fade.modulate.a = 0.0
	if Net.pending_invitation() != "":
		_invitation_hint.text = "A rival has challenged your clan."
		_begin_button.text = "ENTER ROOM"

func _layer(parent: Node = null) -> Control:
	var layer := Control.new()
	layer.size = Vector2(800, 450)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(layer)
	return layer

func _begin() -> void:
	if chapter >= 0 or _finished or not visible:
		return
	Audio.play_music(Audio.MENU_MUSIC_PATH)
	if Net.pending_invitation() != "":
		_finish()
		return
	_gate.hide()
	_story.show()
	_show_chapter(0)

func _show_chapter(index: int) -> void:
	chapter = index
	_elapsed = 0.0
	_lockout = 0.3
	_number.text = "CHRONICLE   /   0%d" % (index + 1)
	_heading.text = CHAPTERS[index].title
	_body.text = CHAPTERS[index].text
	_caption.text = ["SHADOW  /  STORM  /  FROST  /  FIRE", "FOUR CLANS. A SHATTERED ALLIANCE.", "CHOOSE YOUR CLAN. FIGHT FOR ITS FUTURE."][index]
	_art.modulate = [Color.WHITE, Color(0.6, 0.55, 0.72), Color(1.0, 0.8, 0.65)][index]
	if _entrance and _entrance.is_valid():
		_entrance.kill()
	_copy.modulate.a = 0.0
	_copy.position.y = 8.0
	_entrance = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_entrance.tween_property(_copy, "modulate:a", 1.0, 0.7)
	_entrance.tween_property(_copy, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _advance() -> void:
	if not visible or _finished or chapter < 0 or _lockout > 0.0:
		return
	if chapter + 1 == CHAPTERS.size():
		_finish()
	else:
		_show_chapter(chapter + 1)

func _finish() -> void:
	if not visible or _finished:
		return
	_finished = true
	var transition := create_tween().set_ignore_time_scale(true)
	transition.tween_property(_fade, "modulate:a", 1.0, 0.35)
	await transition.finished
	GameState.change_state(GameState.State.ONLINE_MENU if Net.pending_invitation() != "" else GameState.State.TITLE)

func _input(event: InputEvent) -> void:
	if not visible or _finished:
		return
	var confirm: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	var cancel: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed and (chapter >= 0 or not OS.has_feature("web")):
		confirm = event.button_index == JOY_BUTTON_A
		cancel = event.button_index == JOY_BUTTON_B
	if not confirm and not cancel:
		return
	get_viewport().set_input_as_handled()
	if chapter < 0:
		_begin()
	elif cancel:
		_finish()
	else:
		_advance()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if chapter < 0:
			_begin()
		else:
			_advance()

func _process(delta: float) -> void:
	if not visible or _finished:
		return
	var step := minf(delta, 0.1)
	_ambience.advance(step)
	_lockout = maxf(0.0, _lockout - step)
	if chapter >= 0:
		_elapsed += step
		_progress.size.x = 704.0 * clampf(_elapsed / float(CHAPTERS[chapter].duration), 0.0, 1.0)
		if _elapsed >= float(CHAPTERS[chapter].duration):
			_advance()
