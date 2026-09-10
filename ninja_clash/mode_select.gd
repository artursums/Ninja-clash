extends Control

const UI = preload("res://menu_ui.gd")
const MODES := [
	{"name": "DUEL", "tag": "P1 vs P2", "detail": "Settle it on the couch.", "mode": 0},
	{"name": "SOLO", "tag": "P1 vs AI", "detail": "Sharpen your instincts.", "mode": 1},
	{"name": "SPECTATE", "tag": "AI vs AI", "detail": "Let the rivals clash.", "mode": 2},
	{"name": "FREE FOR ALL", "tag": "P1 vs 3 AI", "detail": "One ninja. Three rivals.", "mode": 3},
]
var cursor := 0
var diff := 1
var tiles: Array[Button] = []
var diff_stamps: Array[Button] = []
var diff_label: Label
var detail: Label
var _input_lockout_until := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	UI.backdrop(self)
	UI.header(self, "CHOOSE YOUR BATTLE", 0)
	for i in MODES.size():
		var x := 32 + i * 188
		var tile := UI.button(self, "", Rect2(x, 118, 172, 164), _choose.bind(i))
		tiles.append(tile)
		UI.label(tile, "%02d" % (i + 1), Rect2(12, 8, 148, 18), 14, UI.MUTED)
		var fighters := 4 if i == 3 else 2
		for j in fighters:
			var atlas := AtlasTexture.new()
			atlas.atlas = load(GameState.skin_pose_path(GameState.CLANS[(j + 3) % 4].sprite, 0))
			atlas.region = Rect2(0, 0, 16, 16)
			var sprite := UI.image(tile, atlas, Rect2(24 + j * 32 if fighters == 4 else 30 + j * 64, 36, 32 if fighters == 4 else 48, 48))
			sprite.flip_h = j > 0
		UI.label(tile, MODES[i].name, Rect2(0, 99, 172, 28), 22, UI.IVORY, true)
		UI.label(tile, MODES[i].tag, Rect2(0, 133, 172, 20), 16, UI.GOLD, true)
	detail = UI.label(self, "", Rect2(32, 288, 736, 25), 18, UI.MUTED, true)
	diff_label = UI.label(self, "AI RANK", Rect2(32, 333, 110, 28), 16, UI.GOLD)
	for i in 3:
		diff_stamps.append(UI.button(self, GameState.DIFFICULTY_NAMES[i + 1], Rect2(142 + i * 122, 333, 112, 32), _choose_diff.bind(i + 1), 16))
	UI.button(self, "CONTINUE  >", Rect2(586, 363, 182, 34), _continue)
	UI.button(self, "< BACK", Rect2(32, 363, 106, 34), _back, 16)
	UI.footer(self, "LEFT/RIGHT  MODE     UP/DOWN  AI RANK     ENTER / A  CONTINUE     ESC / B  BACK")

func _choose(index: int) -> void:
	cursor = index
	Audio.play("click")
	_refresh()

func _choose_diff(rank: int) -> void:
	diff = rank
	Audio.play("click")
	_refresh()

func _continue() -> void:
	if not visible or Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	GameState.game_mode = MODES[cursor].mode
	GameState.ai_difficulty = diff
	Audio.play("confirm")
	GameState.change_state(GameState.State.CLAN_SELECT)

func _back() -> void:
	Audio.play("click")
	GameState.change_state(GameState.State.TITLE)

func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_back()
	elif UI.nav("left") or UI.nav("right"):
		_choose(posmod(cursor + (1 if UI.nav("right") else -1), MODES.size()))
	elif cursor != 0 and (UI.nav("aim_up") or UI.nav("aim_down")):
		_choose_diff(clampi(diff + (1 if UI.nav("aim_up") else -1), 1, 3))
	elif UI.confirm():
		_continue()

func _refresh() -> void:
	for i in tiles.size():
		UI.select(tiles[i], i == cursor)
	detail.text = MODES[cursor].detail
	diff_label.visible = cursor != 0
	for i in diff_stamps.size():
		diff_stamps[i].visible = cursor != 0
		UI.select(diff_stamps[i], i + 1 == diff)
