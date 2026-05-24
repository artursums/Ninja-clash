# PROTOTYPE - NOT FOR PRODUCTION
# Mode select: P1 vs P2 / P1 vs AI / AI vs AI, plus AI difficulty (GENIN/CHUNIN/JONIN).
# Left/Right → mode. Up/Down → difficulty (AI modes only). Confirm → clan select. Back → title.
extends Control

const MODES: Array = [
	{"name": "P1 vs P2", "tag": "two players, one couch", "mode": 0},  # HUMAN_VS_HUMAN
	{"name": "P1 vs AI", "tag": "beat the bot",           "mode": 1},  # HUMAN_VS_AI
	{"name": "AI vs AI", "tag": "watch a demo",           "mode": 2},  # AI_VS_AI
	{"name": "P1 vs 3",  "tag": "free-for-all · 3 bots",  "mode": 3},  # FFA
]
const TILE_W: float = 174.0
const TILE_H: float = 120.0
const SPACING: float = 16.0

var cursor: int = 0
var diff: int = 1
var tiles: Array = []
var name_labels: Array = []
var tag_labels: Array = []
var diff_label: Label
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

	var header: Label = Label.new()
	header.text = "SELECT MODE"
	header.position = Vector2(0, 34)
	header.size = Vector2(800, 40)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color("f0eee8"))
	add_child(header)

	var total_w: float = MODES.size() * TILE_W + (MODES.size() - 1) * SPACING
	var start_x: float = (800.0 - total_w) / 2.0
	var y: float = 130.0
	for i in MODES.size():
		var tile: ColorRect = ColorRect.new()
		tile.position = Vector2(start_x + i * (TILE_W + SPACING), y)
		tile.size = Vector2(TILE_W, TILE_H)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tile)

		var name_lbl: Label = Label.new()
		name_lbl.text = MODES[i].name
		name_lbl.size = Vector2(TILE_W, TILE_H)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 26)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(name_lbl)
		name_labels.append(name_lbl)
		tiles.append(tile)

		var tag: Label = Label.new()
		tag.text = MODES[i].tag
		tag.position = Vector2(tile.position.x, y + TILE_H + 6)
		tag.size = Vector2(TILE_W, 20)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 12)
		add_child(tag)
		tag_labels.append(tag)

	diff_label = Label.new()
	diff_label.position = Vector2(0, 322)
	diff_label.size = Vector2(800, 30)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 20)
	add_child(diff_label)

	var hint: Label = Label.new()
	hint.text = "←/→ mode    ↑/↓ difficulty    ✕ / Space confirm    ◯ / Esc back"
	hint.position = Vector2(0, 420)
	hint.size = Vector2(800, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("6a6e88"))
	add_child(hint)

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
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump"):
		GameState.game_mode = MODES[cursor].mode
		GameState.ai_difficulty = diff
		Audio.play("confirm")
		GameState.change_state(GameState.State.CLAN_SELECT)

func _refresh() -> void:
	for i in tiles.size():
		if i == cursor:
			tiles[i].color = Color("2a2a48")
			name_labels[i].add_theme_color_override("font_color", Color("f0eee8"))
			tag_labels[i].add_theme_color_override("font_color", Color("d4a830"))
		else:
			tiles[i].color = Color("16162a")
			name_labels[i].add_theme_color_override("font_color", Color("8a8ea8"))
			tag_labels[i].add_theme_color_override("font_color", Color("5a5e74"))
	if _ai_mode():
		diff_label.text = "AI difficulty:   ◄  %s  ►" % GameState.DIFFICULTY_NAMES[diff]
		diff_label.add_theme_color_override("font_color", Color("8cdc64"))
	else:
		diff_label.text = "— no AI in this mode —"
		diff_label.add_theme_color_override("font_color", Color("4a4e60"))
