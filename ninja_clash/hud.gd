extends Control

const UI := preload("res://menu_ui.gd")
var map_banner_label: Label
var _map_banner_clear_at := 0.0
var score_labels: Array[Label] = []
var _score_cards: Array[Control] = []
var _goals: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_map_banner()
	_build_score_bar()
	Combat.score_changed.connect(_refresh_score)
	GameState.state_changed.connect(func(_s: int) -> void: _refresh_score())

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	if map_banner_label and _map_banner_clear_at > 0.0 and t > _map_banner_clear_at:
		map_banner_label.modulate.a = max(0.0, 1.0 - (t - _map_banner_clear_at) * 1.5)
		if map_banner_label.modulate.a <= 0.0:
			map_banner_label.text = ""
			_map_banner_clear_at = 0.0

func _build_map_banner() -> void:
	map_banner_label = Label.new()
	map_banner_label.add_theme_font_override("font", UI.FONT)
	map_banner_label.position = Vector2(400 - 200, 235)
	map_banner_label.custom_minimum_size = Vector2(400, 0)
	map_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_banner_label.add_theme_font_size_override("font_size", 22)
	map_banner_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
	map_banner_label.text = ""
	add_child(map_banner_label)

func show_map_banner(map_name: String) -> void:
	map_banner_label.text = map_name
	map_banner_label.modulate.a = 1.0
	_map_banner_clear_at = Time.get_ticks_msec() / 1000.0 + 2.0

func _build_score_bar() -> void:
	for slot in 4:
		var card := UI.panel(self, Rect2(0, 12, 88, 36), UI.EDGE)
		_score_cards.append(card)
		UI.label(card, "P%d" % (slot+1), Rect2(8, 9, 22, 18), 13, UI.MUTED)
		score_labels.append(UI.label(card, "0", Rect2(32, 5, 28, 26), 23))
		_goals.append(UI.label(card, "", Rect2(59, 11, 27, 18), 12, UI.MUTED))
	_refresh_score()

func _refresh_score() -> void:
	var count := GameState.num_players()
	for index in _score_cards.size():
		_score_cards[index].visible = index < count
		var inset := 24.0+floori(index/2.0)*96.0
		_score_cards[index].position.x = inset if index%2 == 0 else 800.0-inset-88.0
		var clan: Dictionary = GameState.get_clan(index+1)
		_score_cards[index].add_theme_stylebox_override("panel", UI.style(false, clan.color))
		score_labels[index].text = str(Combat.scores.get(index+1,0))
		score_labels[index].add_theme_color_override("font_color", clan.color)
		_goals[index].text = "/ %d" % maxi(1,GameState.target_score)
