extends Control

const UI = preload("res://menu_ui.gd")
const MODE_ART := [
	preload("res://sprites/menu/modes/duel.webp"),
	preload("res://sprites/menu/modes/solo.webp"),
	preload("res://sprites/menu/modes/spectate.webp"),
	preload("res://sprites/menu/modes/free-for-all.webp"),
]
const MODES := [
	{"name": "DUEL", "tag": "P1 vs P2", "mode": 0},
	{"name": "SOLO", "tag": "P1 vs AI", "mode": 1},
	{"name": "SPECTATE", "tag": "AI vs AI", "mode": 2},
	{"name": "FREE FOR ALL", "tag": "P1 vs 3 AI", "mode": 3},
]
var cursor := 0
var diff := 1
var tiles: Array[Button] = []
var illustrations: Array[TextureRect] = []
var diff_stamps: Array[Button] = []
var diff_label: Label
var _input_lockout_until := 0.0
var _rank_open := false
var _rank_modal: Control
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
		_rank_open = false
		cursor = GameState.game_mode
		diff = GameState.ai_difficulty
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()

func _build() -> void:
	UI.backdrop(self,0.72,false)
	UI.header(self, "CHOOSE YOUR BATTLE", 0)
	for i in MODES.size():
		var x := 32 + i * 188
		var tile := UI.button(self, "", Rect2(x, 104, 172, 218), _choose.bind(i))
		tiles.append(tile)
		illustrations.append(UI.image(tile, MODE_ART[i], Rect2(8, 8, 156, 156)))
		UI.label(tile, MODES[i].name, Rect2(0, 167, 172, 28), 22, UI.IVORY, true)
		UI.label(tile, MODES[i].tag, Rect2(0, 195, 172, 20), 16, UI.GOLD, true)
	_continue_button = UI.button(self, "CONTINUE", Rect2(572, 359, 196, 40), _continue)
	_back_button = UI.button(self, "BACK", Rect2(32, 359, 116, 40), _back, 17)
	_rank_modal = Control.new()
	_rank_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rank_modal)
	var veil := UI.fill(_rank_modal, Rect2(0,0,800,450), Color(0.02,0.025,0.055,0.91))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.panel(_rank_modal, Rect2(206,91,388,282), UI.GOLD)
	diff_label = UI.label(_rank_modal, "CHOOSE YOUR RANK", Rect2(224,107,352,38),26,UI.GOLD,true)
	for i in 3:
		diff_stamps.append(UI.button(_rank_modal, GameState.DIFFICULTY_NAMES[i+1],Rect2(236,158+i*51,328,42),_confirm_rank.bind(i+1),23))
	UI.button(_rank_modal,"BACK",Rect2(340,323,120,30),_back,16)

func _choose(index: int) -> void:
	if _rank_open:
		return
	cursor = index
	Audio.play("click")
	_refresh()

func _choose_diff(rank: int) -> void:
	diff = rank
	Audio.play("click")
	_refresh()

func _continue() -> void:
	if not visible or Time.get_ticks_msec()/1000.0 < _input_lockout_until:
		return
	if cursor != 0 and not _rank_open:
		_rank_open = true
		_input_lockout_until = Time.get_ticks_msec()/1000.0+0.15
		Audio.play("confirm")
		_refresh()
		return
	_commit()

func _confirm_rank(rank: int) -> void:
	if not _rank_open or Time.get_ticks_msec()/1000.0 < _input_lockout_until:
		return
	diff = rank
	_commit()

func _commit() -> void:
	GameState.game_mode = MODES[cursor].mode
	GameState.ai_difficulty = diff
	Audio.play("confirm")
	GameState.change_state(GameState.State.CLAN_SELECT)

func _back() -> void:
	if _rank_open:
		_rank_open = false
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
	elif not _rank_open and (UI.nav("left") or UI.nav("right")):
		_choose(posmod(cursor + (1 if UI.nav("right") else -1), MODES.size()))
	elif _rank_open and (UI.nav("aim_up") or UI.nav("aim_down")):
		_choose_diff(1+posmod(diff-1+(1 if UI.nav("aim_down") else -1),3))
	elif UI.confirm():
		_continue()

func _refresh() -> void:
	for i in tiles.size():
		UI.select(tiles[i], i == cursor)
		illustrations[i].modulate = Color.WHITE if i == cursor else Color(0.78, 0.78, 0.84)
	_rank_modal.visible = _rank_open
	_continue_button.disabled = _rank_open
	_back_button.disabled = _rank_open
	for tile in tiles:
		tile.disabled = _rank_open
	for i in diff_stamps.size():
		UI.select(diff_stamps[i], i+1 == diff)
