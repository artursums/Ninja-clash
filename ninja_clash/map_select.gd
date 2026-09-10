extends Control

const UI = preload("res://menu_ui.gd")
var cursor := 0
var thumb: TextureRect
var name_label: Label
var subtitle_label: Label
var counter_label: Label
var cards: Array[Button] = []
var preview_textures: Array[Texture2D] = []
var host_controls: Array[Button] = []
var _input_lockout_until := 0.0
var _starting := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	Net.map_cursor_changed.connect(_on_remote_cursor)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		cursor = posmod(GameState.selected_map_index, Maps.count())
		_starting = false
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		if Net.is_host():
			Net.send_map_cursor(cursor)
		_refresh()

func _on_remote_cursor(index: int) -> void:
	if not Net.is_client():
		return
	cursor = posmod(index, Maps.count())
	# The cursor packet may arrive before the host's screen-change packet.
	GameState.selected_map_index = cursor
	if visible:
		Audio.play("click")
		_refresh()

func _preview(data: Dictionary) -> Texture2D:
	var path: String = data.get("preview", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		path = data.get("background", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path)
	var fallback := GradientTexture2D.new()
	fallback.gradient = Gradient.new()
	fallback.gradient.set_color(0, data.get("sky_top", UI.INK))
	fallback.gradient.set_color(1, data.get("sky_bot", UI.EDGE))
	fallback.fill_to = Vector2(0, 1)
	return fallback

func _build() -> void:
	UI.backdrop(self, 0.84)
	UI.header(self, "CHOOSE YOUR ARENA", 2)
	# The border is behind the image; no opaque frame can cover the preview.
	UI.panel(self, Rect2(30, 106, 466, 264), UI.GOLD)
	thumb = UI.image(self, null, Rect2(34, 110, 458, 256))
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.clip_contents = true
	UI.fill(self, Rect2(34, 309, 458, 57), Color(0.025, 0.03, 0.07, 0.88))
	name_label = UI.label(self, "", Rect2(48, 312, 430, 29), 26)
	subtitle_label = UI.label(self, "", Rect2(48, 342, 430, 18), 15, UI.MUTED)
	for i in Maps.count():
		var data: Dictionary = Maps.get_map(i)
		var texture := _preview(data)
		preview_textures.append(texture)
		var card := UI.button(self, "", Rect2(520, 108 + i * 65, 248, 57), _choose.bind(i))
		cards.append(card)
		var miniature := UI.image(card, texture, Rect2(5, 5, 78, 47))
		miniature.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		miniature.clip_contents = true
		UI.label(card, "%02d" % (i + 1), Rect2(94, 5, 144, 16), 12, UI.GOLD)
		UI.label(card, data.name.to_upper(), Rect2(94, 22, 146, 25), 16)
	counter_label = UI.label(self, "", Rect2(150, 376, 224, 23), 15, UI.MUTED, true)
	host_controls.append(UI.button(self, "< BACK", Rect2(32, 376, 110, 28), _back, 16))
	host_controls.append(UI.button(self, "<", Rect2(400, 376, 42, 28), _step.bind(-1), 18))
	host_controls.append(UI.button(self, ">", Rect2(450, 376, 42, 28), _step.bind(1), 18))
	host_controls.append(UI.button(self, "RANDOM", Rect2(520, 376, 100, 28), _randomize, 16))
	host_controls.append(UI.button(self, "FIGHT  >", Rect2(630, 376, 138, 28), _start, 18))
	UI.footer(self, "LEFT/RIGHT  ARENA     X / Y  RANDOM     ENTER / A  FIGHT     ESC / B  BACK")

func _can_choose() -> bool:
	return visible and not Net.is_client() and not _starting and Time.get_ticks_msec() / 1000.0 >= _input_lockout_until

func _choose(index: int) -> void:
	if not _can_choose():
		return
	cursor = posmod(index, Maps.count())
	GameState.selected_map_index = cursor
	Net.send_map_cursor(cursor)
	Audio.play("click")
	_refresh()

func _step(direction: int) -> void:
	_choose(cursor + direction)

func _randomize() -> void:
	var next := cursor
	if Maps.count() > 1:
		next = (cursor + randi_range(1, Maps.count() - 1)) % Maps.count()
	_choose(next)

func _back() -> void:
	if not _can_choose():
		return
	Audio.play("click")
	GameState.change_state(GameState.State.CLAN_SELECT)

func _start() -> void:
	if not _can_choose():
		return
	_starting = true
	GameState.selected_map_index = cursor
	Audio.play("confirm")
	GameState.start_new_match()

func _process(_delta: float) -> void:
	if not _can_choose():
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_back()
	elif Input.is_action_just_pressed("menu_random"):
		_randomize()
	elif UI.nav("left") or UI.nav("right"):
		_step(1 if UI.nav("right") else -1)
	elif UI.confirm():
		_start()

func _refresh() -> void:
	var data: Dictionary = Maps.get_map(cursor)
	thumb.texture = preview_textures[cursor]
	name_label.text = data.name.to_upper()
	subtitle_label.text = "HOST IS CHOOSING THE ARENA..." if Net.is_client() else data.get("subtitle", "")
	counter_label.text = "ARENA  %02d / %02d" % [cursor + 1, Maps.count()]
	for i in cards.size():
		UI.select(cards[i], i == cursor)
		cards[i].disabled = Net.is_client()
	for button in host_controls:
		button.disabled = Net.is_client()
