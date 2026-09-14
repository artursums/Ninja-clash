extends Control

const UI := preload("res://menu_ui.gd")
var map_banner_label: Label
var _map_banner_clear_at := 0.0
var score_labels: Array[Label] = []
var _score_cards: Array[Control] = []
var _goals: Array[Label] = []
var _names: Array[Label] = []
const Clock := preload("res://round_clock.gd")
var _clock: Node
var _clock_card: Control
var _clock_text: Label
var _clock_bar: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_map_banner()
	_build_score_bar()
	_clock = get_tree().get_first_node_in_group("round_clock")
	_clock_card = UI.panel(self, Rect2(358, 12, 84, 42), UI.EDGE)
	_clock_text = UI.label(_clock_card, "1:00", Rect2(0, 3, 84, 30), 24)
	_clock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_bar = ColorRect.new()
	_clock_bar.position = Vector2(8, 36)
	_clock_bar.size = Vector2(68, 2)
	_clock_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_card.add_child(_clock_bar)
	Combat.score_changed.connect(_refresh_score)
	GameState.state_changed.connect(func(_s: int) -> void: _refresh_score())

func _process(_delta: float) -> void:
	_refresh_clock()
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
		var name_label := UI.label(card, "", Rect2(8, 30, 156, 22), 16)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_names.append(name_label)
		UI.label(card, "P%d" % (slot+1), Rect2(8, 9, 22, 18), 13, UI.MUTED)
		score_labels.append(UI.label(card, "0", Rect2(32, 5, 28, 26), 23))
		_goals.append(UI.label(card, "", Rect2(59, 11, 27, 18), 12, UI.MUTED))
	_refresh_score()

func _refresh_score() -> void:
	var count := GameState.num_players()
	for index in _score_cards.size():
		_score_cards[index].visible = index < count
		_names[index].text = GameState.player_name(index+1) if Net.is_online() else ""
		_names[index].size.x = 144
		_score_cards[index].size.y = 56 if Net.is_online() else 36
		_score_cards[index].size.x = 160 if Net.is_online() else 88
		if Net.is_online():
			var positions := [16, 624] if count == 2 else [16, 188, 624] if count == 3 else [16, 188, 452, 624]
			_score_cards[index].position.x = positions[mini(index, positions.size() - 1)]
		var inset := 24.0+floori(index/2.0)*96.0
		if not Net.is_online():
			_score_cards[index].position.x = inset if index%2 == 0 else 800.0-inset-88.0
		var clan: Dictionary = GameState.get_clan(index+1)
		_score_cards[index].add_theme_stylebox_override("panel", UI.style(false, clan.color))
		score_labels[index].text = str(Combat.scores.get(index+1,0))
		score_labels[index].add_theme_color_override("font_color", clan.color)
		_goals[index].text = "/ %d" % maxi(1,GameState.target_score)

func _refresh_clock() -> void:
	if _clock == null:
		return
	_clock_card.visible = _clock.phase != Clock.Phase.DISABLED
	_clock_text.text = Clock.time_text(_clock.remaining)
	var urgent: bool = _clock.remaining <= 5 or _clock.phase == Clock.Phase.SUDDEN_DEATH
	var color := Color("f16f65") if urgent else Color("e4bb68") if _clock.remaining <= 15 else Color("ede4c9")
	_clock_text.add_theme_color_override("font_color", color)
	_clock_bar.color = color
	_clock_bar.size.x = 68 * clampf(_clock.remaining / maxf(1, _clock.duration), 0, 1)
	_clock_text.modulate.a = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.009) if urgent and GameState.is_round_active() else 1.0
