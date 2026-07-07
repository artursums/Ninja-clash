# Map select. Move with stick/D-pad or A/D, confirm with Cross/Space, △/X = random map.
# Circle / Esc: back to clan select.
#
# Visuals: wooden map frame (glowing "selected" variant) framing each arena's own background
# image as the preview, with the arena name on a wooden plate below + flanking arrows. Fully
# data-driven over Maps — every level shows its real backdrop and name, no per-level menu art.
extends Control

const MENU := "res://sprites/menu/"

const FRAME_W := 228.0
const FRAME_H := 178.0
const FRAME_X := (800.0 - FRAME_W) / 2.0
const FRAME_Y := 96.0
const THUMB_W := 184.0
const THUMB_H := 134.0

var cursor: int = 0
var thumb: TextureRect
var name_label: Label
var subtitle_label: Label
var _input_lockout_until: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	# Online: the HOST browses; the guest's screen mirrors the host's cursor live.
	Net.map_cursor_changed.connect(_on_remote_cursor)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		cursor = GameState.selected_map_index
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		if Net.is_host():
			Net.send_map_cursor(cursor)
		_refresh()

# Guest ← host: the host moved to another arena preview.
func _on_remote_cursor(c: int) -> void:
	if visible and Net.is_client():
		cursor = c % Maps.count()
		Audio.play("click")
		_refresh()

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header := _spr(load(MENU + "header_choose_arena_native.png"))
	header.position = Vector2((800.0 - header.size.x) / 2.0, 16.0)

	# Arena preview = the level's own background image, dropped into the frame window first;
	# the wooden frame sits on top so its border tucks over the preview edges.
	thumb = TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.clip_contents = true   # crop the covered image to the window
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.position = Vector2(FRAME_X + (FRAME_W - THUMB_W) / 2.0, FRAME_Y + (FRAME_H - THUMB_H) / 2.0)
	thumb.size = Vector2(THUMB_W, THUMB_H)
	add_child(thumb)

	var frame := _spr(load(MENU + "map_frame_selected_native.png"))
	frame.position = Vector2(FRAME_X, FRAME_Y)

	var arrow_l := _spr(load(MENU + "ui_arrow_left_normal_native.png"), 2.2)
	arrow_l.position = Vector2(FRAME_X - 20.0 * 2.2 - 18.0, FRAME_Y + FRAME_H / 2.0 - 9.0 * 2.2)
	var arrow_r := _spr(load(MENU + "ui_arrow_right_normal_native.png"), 2.2)
	arrow_r.position = Vector2(FRAME_X + FRAME_W + 18.0, FRAME_Y + FRAME_H / 2.0 - 9.0 * 2.2)

	# Name plate (reuse the wooden plank) + the arena name & subtitle as dynamic text.
	var plate := _spr(load(MENU + "pause_button_normal_native.png"))
	var plate_w := 300.0
	plate.size = Vector2(214, 52)   # native; scaled below via stretch to plate_w
	plate.scale = Vector2(plate_w / 214.0, 46.0 / 52.0)
	plate.position = Vector2((800.0 - plate_w) / 2.0, 290.0)

	name_label = Label.new()
	name_label.position = Vector2((800.0 - plate_w) / 2.0, 290.0)
	name_label.size = Vector2(plate_w, 46.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("d4a830"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	subtitle_label = Label.new()
	subtitle_label.position = Vector2(0, 344.0)
	subtitle_label.size = Vector2(800, 20.0)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color("a8a498"))
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle_label)

	var hint := _spr(load(MENU + "ui_hint_plate_native.png"), 1.5)
	hint.position = Vector2((800.0 - hint.size.x * 1.5) / 2.0, 392.0)

func _spr(tex: Texture2D, sprite_scale: float = 1.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(tex.get_size())
	tr.scale = Vector2(sprite_scale, sprite_scale)
	add_child(tr)
	return tr

func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	# Online guest: watch only — the host picks the arena (the cursor mirrors live).
	if Net.is_client():
		return
	if Input.is_action_just_pressed("menu_cancel"):
		GameState.change_state(GameState.State.CLAN_SELECT)
		return
	if Input.is_action_just_pressed("menu_random"):
		cursor = randi() % Maps.count()
		GameState.selected_map_index = cursor
		Audio.play("confirm")
		GameState.start_new_match()
		return
	var count: int = Maps.count()
	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left"):
		cursor = (cursor + count - 1) % count
		Audio.play("click")
		Net.send_map_cursor(cursor)
		_refresh()
	elif Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right"):
		cursor = (cursor + 1) % count
		Audio.play("click")
		Net.send_map_cursor(cursor)
		_refresh()
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
			or Input.is_action_just_pressed("p1_confirm") or Input.is_action_just_pressed("p2_confirm"):
		GameState.selected_map_index = cursor
		Audio.play("confirm")
		GameState.start_new_match()

func _refresh() -> void:
	var data: Dictionary = Maps.get_map(cursor)
	var bg_path: String = data.get("background", "")
	thumb.texture = load(bg_path) if bg_path != "" and ResourceLoader.exists(bg_path) else null
	name_label.text = String(data.name).to_upper()
	subtitle_label.text = String(data.get("subtitle", ""))
	if Net.is_client():
		subtitle_label.text = "P1 (host) is choosing the arena…"
