extends Control

const UI := preload("res://menu_ui.gd")
const Portraits := preload("res://clan_portraits.gd")
const OPTIONS := ["REMATCH", "CHOOSE ARENA", "CHOOSE CLAN", "MAIN MENU"]
const STATS := [["strikes", "KATANA STRIKES"], ["throws", "SHURIKEN THROWS"], ["hits", "HITS LANDED"], ["blocks", "BLOCKS"], ["eliminations", "ELIMINATIONS"]]
var winner_label: Label
var tally_label: Label
var portrait: TextureRect
var actions: Array[Button] = []
var stat_headers: Array[Label] = []
var stat_values: Array[Array] = []
var _cursor := 0
var _input_lockout_until := 0.0
var _entry: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.image(self, UI.BACKGROUND, Rect2(0, 0, 800, 450))
	UI.fill(self, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, 0.83))
	var portrait_frame := UI.panel(self, Rect2(40, 26, 160, 218), UI.GOLD)
	portrait = UI.image(portrait_frame, null, Rect2(14, 10, 132, 198))
	UI.label(self, "VICTORY", Rect2(224, 42, 272, 28), 21, UI.GOLD)
	winner_label = UI.label(self, "", Rect2(220, 78, 284, 58), 48)
	tally_label = UI.label(self, "", Rect2(224, 150, 268, 30), 22, UI.GOLD)
	for i in OPTIONS.size():
		var button := UI.button(self, OPTIONS[i], Rect2(520, 40+i*49, 240, 40), _activate.bind(i), 19)
		button.mouse_entered.connect(_hover.bind(i))
		actions.append(button)
	UI.label(self, "BATTLE RECORD", Rect2(40, 255, 190, 26), 17, UI.GOLD)
	for slot in 4:
		stat_headers.append(UI.label(self, "", Rect2(), 16, UI.IVORY, true))
	for row in STATS.size():
		var y := 296+row*26
		UI.fill(self, Rect2(40, y, 720, 25), Color(0.08, 0.09, 0.16, 0.9 if row%2 == 0 else 0.55))
		UI.label(self, STATS[row][1], Rect2(52, y, 198, 25), 14, UI.MUTED)
		var values: Array = []
		for slot in 4:
			values.append(UI.label(self, "0", Rect2(), 19, UI.IVORY, true))
		stat_values.append(values)
	visibility_changed.connect(_on_visibility_changed)
	GameState.state_changed.connect(func(value: int):
		if value == GameState.State.MATCH_END:
			_refresh()
	)

func _on_visibility_changed() -> void:
	if _entry != null:
		_entry.kill()
	if not visible:
		return
	_cursor = 0
	_input_lockout_until = Time.get_ticks_msec()/1000.0+0.65
	_refresh()
	portrait.modulate.a = 0
	_entry = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_entry.tween_property(portrait, "modulate:a", 1.0, 0.3)
	Audio.play_win_fanfare()

func _refresh() -> void:
	if Net.is_client():
		_cursor = 3
	var slot := clampi(GameState.match_winner_slot, 1, 4)
	var clan: Dictionary = GameState.get_clan(slot)
	Portraits.apply(portrait, GameState.clan_index(slot), GameState.SKIN_STYLES[GameState.skin_index(slot)])
	winner_label.text = clan.name
	winner_label.add_theme_color_override("font_color", clan.color)
	tally_label.text = "P%d   %d WINS" % [slot, Combat.scores.get(slot, 0)]
	var count := GameState.num_players()
	var width := 500.0/count
	for index in 4:
		var shown := index < count
		var x := 260+index*width
		var header: Label = stat_headers[index]
		header.visible = shown
		header.position = Vector2(x, 260)
		header.size = Vector2(width, 28)
		header.text = "P%d  %s · %d" % [index+1, GameState.get_clan(index+1).name, Combat.scores.get(index+1,0)]
		header.add_theme_font_size_override("font_size", 13 if count == 4 else 16)
		header.add_theme_color_override("font_color", GameState.get_clan(index+1).color)
		for row in STATS.size():
			var value: Label = stat_values[row][index]
			value.visible = shown
			value.position = Vector2(x, 296+row*26)
			value.size = Vector2(width, 25)
			value.text = str(Combat.stat(index+1, STATS[row][0]))
	for i in actions.size():
		actions[i].disabled = Net.is_client() and i != 3
		actions[i].text = "LEAVE MATCH" if Net.is_client() and i == 3 else OPTIONS[i]
		UI.select(actions[i], i == _cursor and not actions[i].disabled)

func _hover(index: int) -> void:
	if actions[index].disabled:
		return
	_cursor = index
	_refresh()

func _activate(index: int) -> void:
	if not visible or Time.get_ticks_msec()/1000.0 < _input_lockout_until:
		return
	if Net.is_client():
		if index == 3:
			Net.leave("")
			GameState.change_state(GameState.State.ONLINE_MENU)
		return
	Audio.play("confirm")
	match index:
		0: GameState.start_new_match()
		1: GameState.change_state(GameState.State.MAP_SELECT)
		2: GameState.change_state(GameState.State.CLAN_SELECT)
		3: GameState.change_state(GameState.State.TITLE)

func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec()/1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_cursor = 3
		_refresh()
	elif UI.nav("aim_up") or UI.nav("aim_down"):
		_cursor = 3 if Net.is_client() else posmod(_cursor+(1 if UI.nav("aim_down") else -1), actions.size())
		Audio.play("click")
		_refresh()
	elif UI.confirm():
		_activate(3 if Net.is_client() else _cursor)
