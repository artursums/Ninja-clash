# Mode select: P1 vs P2 / P1 vs AI / AI vs AI / P1 vs 3 (FFA), plus AI difficulty.
# Left/Right → mode. Up/Down → difficulty (AI modes only). Confirm → clan select. Back → title.
#
# Visuals are the pre-rendered sprites/menu/ kit: each mode tile bakes its own name,
# tagline and ninja silhouettes (normal + selected variants); the difficulty stamps bake
# rank name + dots; the bottom hint plate bakes its controls text.
extends Control

const MODES: Array = [
	{"name": "P1 vs P2", "mode": 0, "slug": "p1_vs_p2"},   # HUMAN_VS_HUMAN
	{"name": "P1 vs AI", "mode": 1, "slug": "p1_vs_ai"},   # HUMAN_VS_AI
	{"name": "AI vs AI", "mode": 2, "slug": "ai_vs_ai"},   # AI_VS_AI
	{"name": "P1 vs 3",  "mode": 3, "slug": "p1_vs_3"},    # FFA
]
const DIFF_SLUGS: Array = ["genin", "chunin", "jonin"]   # diff value 1..3 → index 0..2

const MENU := "res://sprites/menu/"
const TILE_W := 144.0
const TILE_GAP := 12.0
const TILE_Y := 100.0
const DIFF_W := 116.0
const DIFF_GAP := 18.0
const DIFF_Y := 246.0

var cursor: int = 0
var diff: int = 1
var tiles: Array = []          # TextureRect per mode
var diff_stamps: Array = []    # TextureRect per difficulty
var diff_label: Label
var diff_frame: NinePatchRect  # selection frame around the chosen difficulty
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
		cursor = GameState.game_mode
		diff = GameState.ai_difficulty
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header := _spr(load(MENU + "header_select_mode_native.png"))
	header.position = Vector2((800.0 - header.size.x) / 2.0, 16.0)

	var total_w: float = MODES.size() * TILE_W + (MODES.size() - 1) * TILE_GAP
	var start_x: float = (800.0 - total_w) / 2.0
	for i in MODES.size():
		var tile := _spr(load(MENU + "mode_%s_native.png" % MODES[i].slug))
		tile.position = Vector2(start_x + i * (TILE_W + TILE_GAP), TILE_Y)
		tiles.append(tile)

	diff_label = Label.new()
	diff_label.text = "AI DIFFICULTY"
	diff_label.position = Vector2(0, 222)
	diff_label.size = Vector2(800, 20)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 14)
	diff_label.add_theme_color_override("font_color", Color("d4a830"))
	add_child(diff_label)

	# Selection frame sits behind the chosen stamp (built before stamps so it renders under them).
	diff_frame = NinePatchRect.new()
	diff_frame.texture = load(MENU + "ui_select_frame_native.png")
	diff_frame.patch_margin_left = 6
	diff_frame.patch_margin_right = 6
	diff_frame.patch_margin_top = 6
	diff_frame.patch_margin_bottom = 6
	diff_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diff_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(diff_frame)

	var dtotal: float = DIFF_SLUGS.size() * DIFF_W + (DIFF_SLUGS.size() - 1) * DIFF_GAP
	var dstart: float = (800.0 - dtotal) / 2.0
	for i in DIFF_SLUGS.size():
		var stamp := _spr(load(MENU + "diff_%s_native.png" % DIFF_SLUGS[i]))
		stamp.position = Vector2(dstart + i * (DIFF_W + DIFF_GAP), DIFF_Y)
		diff_stamps.append(stamp)

	var hint := _spr(load(MENU + "ui_hint_plate_native.png"), 1.5)
	hint.position = Vector2((800.0 - hint.size.x * 1.5) / 2.0, 392.0)

# A native-res pixel sprite, top-left anchored, optional uniform scale.
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

func _ai_mode() -> bool:
	return MODES[cursor].mode != GameState.Mode.HUMAN_VS_HUMAN

func _nav(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)

func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		GameState.change_state(GameState.State.TITLE)
		return
	var n: int = MODES.size()
	if _nav("left"):
		cursor = (cursor + n - 1) % n
		Audio.play("click")
		_refresh()
	elif _nav("right"):
		cursor = (cursor + 1) % n
		Audio.play("click")
		_refresh()
	elif _ai_mode() and _nav("aim_up"):
		diff = clampi(diff + 1, 1, 3)
		Audio.play("click")
		_refresh()
	elif _ai_mode() and _nav("aim_down"):
		diff = clampi(diff - 1, 1, 3)
		Audio.play("click")
		_refresh()
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump") \
			or Input.is_action_just_pressed("p1_confirm") or Input.is_action_just_pressed("p2_confirm"):
		GameState.game_mode = MODES[cursor].mode
		GameState.ai_difficulty = diff
		Audio.play("confirm")
		GameState.change_state(GameState.State.CLAN_SELECT)

func _refresh() -> void:
	for i in tiles.size():
		var slug: String = MODES[i].slug
		var sel: bool = (i == cursor)
		tiles[i].texture = load(MENU + "mode_%s%s_native.png" % [slug, "_selected" if sel else ""])

	# The difficulty row exists only for AI modes — HIDDEN (not dimmed) otherwise, so a
	# P1-vs-P2 player never wonders what the inert stamps and dead Up/Down inputs are for.
	var ai: bool = _ai_mode()
	diff_label.visible = ai
	diff_label.add_theme_color_override("font_color", Color("d4a830"))
	diff_label.text = "AI DIFFICULTY   (▲/▼ change)"
	for i in diff_stamps.size():
		diff_stamps[i].visible = ai
	# Place / show the selection frame around the active difficulty stamp.
	diff_frame.visible = ai
	if ai:
		var s: TextureRect = diff_stamps[diff - 1]
		var pad := 7.0
		diff_frame.position = s.position - Vector2(pad, pad)
		diff_frame.size = s.size + Vector2(pad * 2.0, pad * 2.0)
