# Map select. Move with stick/D-pad or A/D, confirm with Cross/Space, △/X = random map.
# Circle / Esc: back to clan select.
#
# Visuals: wooden map frame (glowing "selected" variant) around a pre-rendered arena
# thumbnail, with a carved nameplate below and flanking arrows. One arena ships today
# (Sakura Temple); the cursor logic stays data-driven for when more are added.
extends Control

const MENU := "res://sprites/menu/"
# Arena name (Maps autoload) → sprite slug. Falls back to "sakura" for any unmapped arena.
const SLUG_BY_NAME := {"Sakura Temple": "sakura"}

const FRAME_W := 228.0
const FRAME_H := 178.0
const FRAME_X := (800.0 - FRAME_W) / 2.0
const FRAME_Y := 96.0
const THUMB_W := 184.0
const THUMB_H := 134.0

var cursor: int = 0
var thumb: TextureRect
var nameplate: TextureRect
var _input_lockout_until: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		cursor = GameState.selected_map_index
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()

func _slug_for(index: int) -> String:
	var map_name: String = Maps.get_map(index).name
	return SLUG_BY_NAME.get(map_name, "sakura")

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header := _spr(load(MENU + "header_choose_arena_native.png"))
	header.position = Vector2((800.0 - header.size.x) / 2.0, 16.0)

	# Wooden frame first, arena thumbnail dropped into its window on top (the frame's
	# inner panel is opaque, so the thumbnail must sit above it).
	var frame := _spr(load(MENU + "map_frame_selected_native.png"))
	frame.position = Vector2(FRAME_X, FRAME_Y)

	thumb = _spr(load(MENU + "map_sakura_temple_native.png"))
	thumb.position = Vector2(FRAME_X + (FRAME_W - THUMB_W) / 2.0, FRAME_Y + (FRAME_H - THUMB_H) / 2.0)

	var arrow_l := _spr(load(MENU + "ui_arrow_left_normal_native.png"), 2.2)
	arrow_l.position = Vector2(FRAME_X - 20.0 * 2.2 - 18.0, FRAME_Y + FRAME_H / 2.0 - 9.0 * 2.2)
	var arrow_r := _spr(load(MENU + "ui_arrow_right_normal_native.png"), 2.2)
	arrow_r.position = Vector2(FRAME_X + FRAME_W + 18.0, FRAME_Y + FRAME_H / 2.0 - 9.0 * 2.2)

	nameplate = _spr(load(MENU + "map_nameplate_sakura_native.png"))
	nameplate.position = Vector2((800.0 - nameplate.size.x) / 2.0, 298.0)

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
		_refresh()
	elif Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right"):
		cursor = (cursor + 1) % count
		Audio.play("click")
		_refresh()
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump"):
		GameState.selected_map_index = cursor
		Audio.play("confirm")
		GameState.start_new_match()

func _refresh() -> void:
	var slug: String = _slug_for(cursor)
	thumb.texture = load(MENU + "map_%s_temple_native.png" % slug)
	nameplate.texture = load(MENU + "map_nameplate_%s_native.png" % slug)
