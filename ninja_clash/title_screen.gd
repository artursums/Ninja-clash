extends Control

const UI = preload("res://menu_ui.gd")
const BUTTON_SLUGS := ["start", "online", "options", "credits", "quit"]
const BUTTON_NAMES := {"start": "LOCAL PLAY", "online": "ONLINE DUEL", "options": "OPTIONS", "credits": "CREDITS", "quit": "QUIT"}
const DESCRIPTIONS := {"start": "Couch rivals. Relentless bots. Four clans.", "online": "Challenge a friend over LAN or internet.", "options": "Make yourself at home.", "credits": "The people behind the arena.", "quit": "Until the next duel."}
const OPT_ROWS := ["MASTER", "MUSIC", "SFX", "FULLSCREEN", "TUTORIAL", "BACK"]
const OVERLAY_NONE := 0
const OVERLAY_OPTIONS := 1
const OVERLAY_CREDITS := 2

var cursor := 0
var _slugs: Array = []
var _buttons: Array[Button] = []
var _input_lockout_until := 0.0
var _overlay := OVERLAY_NONE
var _options_cursor := 0
var _options_panel: Control
var _credits_panel: Control
var _opt_rows: Array[Button] = []
var _opt_values: Array[Label] = []
var _description: Label
var _sparks: Array[ColorRect] = []
var _elapsed := 0.0
var _halves: Array[Control] = []
var _content: Control
var _intro: Tween
var _intro_active := false
var _intro_played := false

func _platform_slugs() -> Array:
	return ["start", "options", "credits"] if OS.has_feature("web") else BUTTON_SLUGS.duplicate()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if visible:
		_set_overlay(OVERLAY_NONE)
		_refresh()
		if not _intro_played:
			_start_intro()
	elif _intro_active:
		_finish_intro()

func _build() -> void:
	UI.fill(self, Rect2(0, 0, 800, 450), UI.INK)
	for side in 2:
		var clip := Control.new()
		clip.position = Vector2(side * 400, 0)
		clip.size = Vector2(400, 450)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		var picture := Control.new()
		picture.position.x = -side * 400
		picture.size = Vector2(800, 450)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(picture)
		UI.backdrop(picture, 0.12)
		_halves.append(clip)
	_content = Control.new()
	_content.size = Vector2(800, 450)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var shade := GradientTexture2D.new()
	shade.gradient = Gradient.new()
	shade.gradient.set_color(0, Color(0.025, 0.03, 0.08, 0.9))
	shade.gradient.set_color(1, Color(0.025, 0.03, 0.08, 0))
	shade.fill_to = Vector2(1, 0)
	var veil := UI.image(_content, shade, Rect2(0, 0, 650, 450))
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	UI.label(_content, "S H I N O B I   A R E N A", Rect2(58, 40, 370, 22), 16, UI.GOLD)
	var title := UI.label(_content, "FOUR CLANS", Rect2(54, 61, 450, 66), 56)
	title.add_theme_color_override("font_shadow_color", Color("352440"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	UI.fill(_content, Rect2(58, 137, 274, 2), UI.GOLD)
	for i in 4:
		UI.fill(_content, Rect2(58 + i * 18, 128, 12, 3), GameState.CLANS[i].color)
	_slugs = _platform_slugs()
	for i in _slugs.size():
		var slug: String = _slugs[i]
		var btn := UI.button(_content, BUTTON_NAMES[slug], Rect2(58, 160 + i * 42, 274, 35), _activate.bind(i), 22)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.mouse_entered.connect(_hover.bind(i))
		_buttons.append(btn)
	_description = UI.label(_content, "", Rect2(58, 376, 540, 24), 16, UI.MUTED)
	UI.footer(_content, "W/S  SELECT     ENTER / A  CONFIRM     MOUSE  POINT & CLICK")
	for i in 12:
		var spark := UI.fill(_content, Rect2(440 + (i * 37) % 320, 190 + (i * 53) % 210, 2, 2), UI.GOLD)
		_sparks.append(spark)
	_build_options()
	_build_credits()

func _start_intro() -> void:
	_intro_played = true
	_intro_active = true
	_halves[0].position.x = -400
	_halves[1].position.x = 800
	_content.position.x = -34
	_content.modulate.a = 0
	# Let the first texture upload finish before advancing the entrance.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _intro_active or not visible:
		return
	_intro = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_intro.tween_property(_halves[0], "position:x", 0.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_halves[1], "position:x", 400.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_content, "position:x", 0.0, 0.5).set_delay(0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_content, "modulate:a", 1.0, 0.45).set_delay(0.45)
	_intro.chain().tween_callback(_finish_intro)

func _finish_intro() -> void:
	if _intro and _intro.is_valid():
		_intro.kill()
	_intro_active = false
	_halves[0].position.x = 0
	_halves[1].position.x = 400
	_content.position.x = 0
	_content.modulate.a = 1
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.18

func _input(event: InputEvent) -> void:
	if visible and _intro_active and event is InputEventMouseButton and event.pressed:
		_finish_intro()
		get_viewport().set_input_as_handled()

func _make_overlay(title: String, rect: Rect2) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	UI.fill(root, Rect2(0, 0, 800, 450), Color(0.02, 0.02, 0.06, 0.88))
	UI.panel(root, rect, UI.GOLD)
	UI.label(root, title, Rect2(rect.position.x, rect.position.y + 12, rect.size.x, 36), 30, UI.GOLD, true)
	return root

func _build_options() -> void:
	_options_panel = _make_overlay("OPTIONS", Rect2(154, 34, 492, 370))
	for i in OPT_ROWS.size():
		var row := UI.button(_options_panel, "", Rect2(180, 92 + i * 43, 440, 35), _option_activate.bind(i), 18)
		row.mouse_entered.connect(func():
			_options_cursor = i
			_refresh_options())
		_opt_rows.append(row)
		_opt_values.append(UI.label(row, "", Rect2(328, 3, 66, 29), 18, UI.IVORY, true))
		if i < 3:
			UI.button(row, "-", Rect2(292, 3, 30, 29), _option_adjust.bind(i, -0.1), 20)
			UI.button(row, "+", Rect2(400, 3, 30, 29), _option_adjust.bind(i, 0.1), 20)
	UI.label(_options_panel, "UP/DOWN  SELECT    LEFT/RIGHT  ADJUST    ESC  BACK", Rect2(170, 360, 460, 24), 14, UI.MUTED, true)

func _build_credits() -> void:
	_credits_panel = _make_overlay("CREDITS", Rect2(180, 52, 440, 342))
	UI.label(_credits_panel, "FOUR CLANS", Rect2(200, 113, 400, 35), 32, UI.IVORY, true)
	UI.label(_credits_panel, "Design & programming\nArtur Sums\n\nMade with Godot\n\nThanks for playing.", Rect2(210, 154, 380, 158), 20, UI.MUTED, true)
	UI.button(_credits_panel, "BACK", Rect2(300, 330, 200, 36), _set_overlay.bind(OVERLAY_NONE))

func _hover(index: int) -> void:
	if _overlay != OVERLAY_NONE or not visible or _intro_active:
		return
	if cursor != index:
		cursor = index
		Audio.play("click")
		_refresh()

func _activate(index: int) -> void:
	if not visible or _intro_active or _overlay != OVERLAY_NONE or Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	cursor = index
	Audio.play("confirm")
	match _slugs[index]:
		"start": GameState.change_state(GameState.State.MODE_SELECT)
		"online": GameState.change_state(GameState.State.ONLINE_MENU)
		"options": _set_overlay(OVERLAY_OPTIONS)
		"credits": _set_overlay(OVERLAY_CREDITS)
		"quit": get_tree().quit()

func _process(delta: float) -> void:
	if not visible:
		return
	if _intro_active:
		if UI.confirm() or Input.is_action_just_pressed("menu_cancel"):
			_finish_intro()
		return
	_elapsed += delta
	for i in _sparks.size():
		_sparks[i].position.y = 390.0 - fmod(_elapsed * (5 + i % 3) + i * 23, 220.0)
		_sparks[i].modulate.a = 0.2 + 0.4 * (sin(_elapsed * 1.5 + i) + 1.0) / 2.0
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if _overlay != OVERLAY_NONE and Input.is_action_just_pressed("menu_cancel"):
		_set_overlay(OVERLAY_NONE)
		return
	if _overlay == OVERLAY_CREDITS:
		if UI.confirm():
			_set_overlay(OVERLAY_NONE)
		return
	if _overlay == OVERLAY_OPTIONS:
		if UI.nav("aim_up") or UI.nav("aim_down"):
			_options_cursor = posmod(_options_cursor + (1 if UI.nav("aim_down") else -1), OPT_ROWS.size())
			Audio.play("click")
			_refresh_options()
		elif UI.nav("left") or UI.nav("right"):
			if _options_cursor < 3:
				_option_adjust(_options_cursor, 0.1 if UI.nav("right") else -0.1)
			elif _options_cursor in [3, 4]:
				_option_activate(_options_cursor)
		elif UI.confirm():
			_option_activate(_options_cursor)
		return
	if UI.nav("aim_up") or UI.nav("aim_down"):
		cursor = posmod(cursor + (1 if UI.nav("aim_down") else -1), _slugs.size())
		Audio.play("click")
		_refresh()
	elif UI.confirm():
		_activate(cursor)

func _set_overlay(kind: int) -> void:
	_overlay = kind
	_options_panel.visible = kind == OVERLAY_OPTIONS
	_credits_panel.visible = kind == OVERLAY_CREDITS
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.18
	if kind == OVERLAY_OPTIONS:
		_options_cursor = 0
		_refresh_options()

func _option_activate(row: int) -> void:
	match row:
		3: Settings.set_fullscreen(not Settings.fullscreen)
		4: Settings.set_show_tutorial(not Settings.show_tutorial)
		5: _set_overlay(OVERLAY_NONE)
	Audio.play("click")
	_refresh_options()

func _option_adjust(row: int, delta: float) -> void:
	match row:
		0: Settings.set_master_volume(Settings.master_volume + delta)
		1: Settings.set_music_volume(Settings.music_volume + delta)
		2: Settings.set_sfx_volume(Settings.sfx_volume + delta)
	Audio.play("click")
	_refresh_options()

func _refresh() -> void:
	for i in _buttons.size():
		UI.select(_buttons[i], i == cursor)
		_buttons[i].text = (">  " if i == cursor else "   ") + BUTTON_NAMES[_slugs[i]]
	_description.text = DESCRIPTIONS[_slugs[cursor]]

func _refresh_options() -> void:
	var volumes := [Settings.master_volume, Settings.music_volume, Settings.sfx_volume]
	for i in OPT_ROWS.size():
		UI.select(_opt_rows[i], i == _options_cursor)
		_opt_rows[i].alignment = HORIZONTAL_ALIGNMENT_LEFT
		_opt_rows[i].text = "HOW TO PLAY" if i == 4 else OPT_ROWS[i]
		_opt_values[i].add_theme_color_override("font_color", UI.GOLD if i == _options_cursor else UI.IVORY)
		if i < 3:
			_opt_values[i].text = "%d%%" % roundi(volumes[i] * 100)
		elif i == 3:
			_opt_values[i].text = "ON" if Settings.fullscreen else "OFF"
		elif i == 4:
			_opt_values[i].text = "ON" if Settings.show_tutorial else "OFF"
