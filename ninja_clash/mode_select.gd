extends Control

const UI = preload("res://menu_ui.gd")
const MODE_ART := [
	preload("res://sprites/menu/modes/duel.webp"),
	preload("res://sprites/menu/modes/solo.webp"),
	preload("res://sprites/menu/modes/free-for-all.webp"),
]
const MODES := [
	{"name": "LOCAL MULTIPLAYER", "tag": "2–4 PLAYERS", "mode": GameState.Mode.HUMAN_VS_HUMAN},
	{"name": "SOLO", "tag": "P1 vs CPU", "mode": GameState.Mode.HUMAN_VS_AI},
	{"name": "FREE FOR ALL", "tag": "P1 vs 3 CPUs", "mode": GameState.Mode.FFA},
]
var cursor := 0
var diff := 1
var local_players := 2
var tiles: Array[Button] = []
var illustrations: Array[TextureRect] = []
var diff_stamps: Array[Button] = []
var diff_label: Label
var _input_lockout_until := 0.0
var _choice_open := false
var _choice_modal: Control
var _continue_button: Button
var _back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		_choice_open = false
		cursor = 0
		for i in MODES.size():
			if MODES[i].mode == GameState.game_mode:
				cursor = i
				break
		diff = GameState.ai_difficulty
		local_players = GameState.local_player_count
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()

func _build() -> void:
	UI.backdrop(self,0.72,false)
	UI.header(self, "CHOOSE YOUR BATTLE", 0)
	for i in MODES.size():
		var x := 32 + i * 252
		var tile := UI.button(self, "", Rect2(x, 104, 232, 218), _choose.bind(i))
		tiles.append(tile)
		illustrations.append(UI.image(tile, MODE_ART[i], Rect2(38, 8, 156, 156)))
		UI.label(tile, MODES[i].name, Rect2(0, 167, 232, 28), 18 if i == 0 else 22, UI.IVORY, true)
		UI.label(tile, MODES[i].tag, Rect2(0, 195, 232, 20), 16, UI.GOLD, true)
	_continue_button = UI.button(self, "CONTINUE", Rect2(572, 359, 196, 40), _continue)
	_back_button = UI.button(self, "BACK", Rect2(32, 359, 116, 40), _back, 17)
	_choice_modal = Control.new()
	_choice_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_choice_modal)
	var veil := UI.fill(_choice_modal, Rect2(0,0,800,450), Color(0.02,0.025,0.055,0.91))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.panel(_choice_modal, Rect2(206,91,388,282), UI.GOLD)
	diff_label = UI.label(_choice_modal, "CHOOSE YOUR RANK", Rect2(224,107,352,38),26,UI.GOLD,true)
	for i in 3:
		diff_stamps.append(UI.button(_choice_modal, GameState.DIFFICULTY_NAMES[i+1],Rect2(236,158+i*51,328,42),_confirm_choice.bind(i+1),23))
	UI.button(_choice_modal,"BACK",Rect2(340,323,120,30),_back,16)

func _choose(index: int) -> void:
	if _choice_open:
		return
	cursor = index
	Audio.play("click")
	_refresh()

func _choose_option(option: int) -> void:
	if cursor == 0:
		local_players = option + 1
	else:
		diff = option
	Audio.play("click")
	_refresh()

func _continue() -> void:
	if not visible or Time.get_ticks_msec()/1000.0 < _input_lockout_until:
		return
	if not _choice_open:
		_choice_open = true
		_input_lockout_until = Time.get_ticks_msec()/1000.0+0.15
		Audio.play("confirm")
		_refresh()
		return
	_commit()

func _confirm_choice(option: int) -> void:
	if not _choice_open or Time.get_ticks_msec()/1000.0 < _input_lockout_until:
		return
	_choose_option(option)
	_commit()

func _commit() -> void:
	GameState.game_mode = MODES[cursor].mode
	GameState.ai_difficulty = diff
	if cursor == 0:
		GameState.local_player_count = local_players
	Audio.play("confirm")
	GameState.change_state(GameState.State.CLAN_SELECT)

func _back() -> void:
	if _choice_open:
		_choice_open = false
		_refresh()
		Audio.play("click")
		return
	Audio.play("click")
	GameState.change_state(GameState.State.TITLE)

func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_back()
	elif not _choice_open and (UI.nav("left") or UI.nav("right")):
		_choose(posmod(cursor + (1 if UI.nav("right") else -1), MODES.size()))
	elif _choice_open and (UI.nav("aim_up") or UI.nav("aim_down")):
		_choose_option(1+posmod((local_players-2 if cursor == 0 else diff-1)+(1 if UI.nav("aim_down") else -1),3))
	elif UI.confirm():
		_continue()

func _refresh() -> void:
	for i in tiles.size():
		UI.select(tiles[i], i == cursor)
		illustrations[i].modulate = Color.WHITE if i == cursor else Color(0.78, 0.78, 0.84)
	_choice_modal.visible = _choice_open
	_continue_button.disabled = _choice_open
	_back_button.disabled = _choice_open
	for tile in tiles:
		tile.disabled = _choice_open
	diff_label.text = "HOW MANY PLAYERS?" if cursor == 0 else "CHOOSE YOUR RANK"
	for i in diff_stamps.size():
		diff_stamps[i].text = "%d PLAYERS" % (i + 2) if cursor == 0 else GameState.DIFFICULTY_NAMES[i + 1]
		UI.select(diff_stamps[i], i+1 == (local_players-1 if cursor == 0 else diff))
