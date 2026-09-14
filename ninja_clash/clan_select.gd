extends Control

const Portraits := preload("res://clan_portraits.gd")
const Selection := preload("res://local_selection.gd")
const UI := preload("res://menu_ui.gd")
const BANNER_W := 164.0
const BANNER_GAP := 24.0
const BANNER_Y := 112.0
const PORTRAIT_SIZE := Vector2(128, 192)

var selection := Selection.new()
var stamps: Array[Label] = []
var clan_ninjas: Array[TextureRect] = []
var name_labels: Array[Label] = []
var chips: Array[Label] = []
var status_label: Label
var _mouse_slot := 1
var _card_buttons: Array[Button] = []
var _player_buttons: Array[Button] = []
var _skin_buttons: Array[Button] = []
var _selection_labels: Array[Label] = []
var _docks: Array[Panel] = []
var _input_lockout_until := 0.0
var _opened_frame := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_load_selection()

func _solo() -> bool:
	return GameState.game_mode in [GameState.Mode.HUMAN_VS_AI, GameState.Mode.FFA]

func _on_visibility_changed() -> void:
	if visible:
		_load_selection()

func _load_selection() -> void:
	_opened_frame = Engine.get_process_frames()
	var initial: Array = []
	for slot in range(1, (1 if _solo() else GameState.num_players()) + 1):
		initial.append(GameState.clan_index(slot))
	selection.configure(initial)
	status_label.text = ""
	_mouse_slot = 1
	_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
	_refresh()

func _banner_x(index: int) -> float:
	return 36 + index * (BANNER_W + BANNER_GAP)

func _build() -> void:
	UI.backdrop(self, 0.78)
	UI.header(self, "CHOOSE YOUR CLAN", 1)
	for i in 4:
		_card_buttons.append(UI.button(self, "", Rect2(_banner_x(i), BANNER_Y, BANNER_W, 222), _mouse_pick.bind(i)))
		clan_ninjas.append(UI.image(self, Portraits.texture(i, "base"), Rect2(Vector2(_banner_x(i) + 18, BANNER_Y + 4), PORTRAIT_SIZE)))
		var stamp := UI.label(self, "LOCKED", Rect2(_banner_x(i), BANNER_Y + 158, BANNER_W, 30), 22, UI.GOLD, true)
		stamp.add_theme_color_override("font_shadow_color", UI.INK)
		stamp.add_theme_constant_override("shadow_offset_x", 2)
		stamp.add_theme_constant_override("shadow_offset_y", 2)
		stamps.append(stamp)
		name_labels.append(UI.label(self, "", Rect2(_banner_x(i), 310, BANNER_W, 24), 21, UI.IVORY, true))
		chips.append(UI.label(self, "P%d" % (i + 1), Rect2(0, 0, 32, 27), 18, UI.IVORY, true))
		_docks.append(UI.panel(self, Rect2(0, 344, 172, 62)))
		_selection_labels.append(UI.label(self, "", Rect2(0, 348, 160, 20), 16))
		_skin_buttons.append(UI.button(self, "", Rect2(0, 373, 90, 26), _mouse_skin.bind(i + 1), 14))
		_player_buttons.append(UI.button(self, "", Rect2(0, 352, 122, 46), _mouse_lock.bind(i + 1), 18))
	status_label = UI.label(self, "", Rect2(398, 62, 370, 26), 12, UI.MUTED, true)
	UI.button(self, "< BACK", Rect2(32, 416, 100, 24), _back, 14)
	UI.button(self, "MATCH SETUP", Rect2(650, 416, 118, 24), _setup, 14)

func _mouse_ready() -> bool:
	return visible and Time.get_ticks_msec() / 1000.0 >= _input_lockout_until

func _mouse_pick(clan: int) -> void:
	if _mouse_ready() and selection.choose(_mouse_slot - 1, clan):
		status_label.text = ""
		Audio.play("click")
		_refresh()

func _mouse_skin(slot: int) -> void:
	if not _mouse_ready() or slot > selection.clans.size() or selection.ready[slot - 1]:
		return
	GameState.set("p%d_skin" % slot, (GameState.skin_index(slot) + 1) % GameState.skin_count())
	_mouse_slot = slot
	Audio.play("click")
	_refresh()

func _save_clans() -> void:
	for index in selection.clans.size():
		GameState.set("p%d_clan" % (index + 1), selection.clans[index])

func _mouse_lock(slot: int) -> void:
	if not _mouse_ready() or slot > selection.clans.size():
		return
	_mouse_slot = slot
	if not selection.toggle_ready(slot - 1):
		status_label.text = "CLAN TAKEN - CHOOSE ANOTHER"
		Audio.play("hit")
		return
	_save_clans()
	Audio.play("confirm")
	if selection.ready[slot - 1]:
		_mouse_slot = selection.next_unready(slot - 1) + 1
	_refresh()
	if selection.all_ready():
		if GameState.game_mode == GameState.Mode.FFA:
			GameState.assign_ffa_clans()
		elif GameState.game_mode == GameState.Mode.HUMAN_VS_AI:
			GameState.p2_clan = (GameState.p1_clan + randi_range(1, 3)) % 4
		GameState.change_state(GameState.State.MAP_SELECT)

func _back() -> void:
	Audio.play("click")
	GameState.change_state(GameState.State.MODE_SELECT)

func _setup() -> void:
	_save_clans()
	Audio.play("confirm")
	GameState.change_state(GameState.State.MATCH_SETUP)

func _pressed(slot: int, suffix: String) -> bool:
	var action := "p%d_%s" % [slot, suffix]
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)

func _process(_delta: float) -> void:
	if not _mouse_ready() or Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_back()
		return
	if Input.is_action_just_pressed("menu_setup"):
		_setup()
		return
	for index in selection.clans.size():
		var slot := index + 1
		if selection.ready[index]:
			if _pressed(slot, "aim_down"):
				_mouse_lock(slot)
			continue
		if _pressed(slot, "skin"):
			_mouse_skin(slot)
		if _pressed(slot, "left") or _pressed(slot, "right"):
			_mouse_slot = slot
			_mouse_pick(selection.clans[index] + (1 if _pressed(slot, "right") else -1))
		elif _pressed(slot, "jump") or _pressed(slot, "confirm"):
			_mouse_lock(slot)
			if not visible:
				return

func _refresh() -> void:
	var count := selection.clans.size()
	for clan in 4:
		var visitors: Array[int] = []
		var chosen := -1
		for index in count:
			if selection.clans[index] == clan:
				visitors.append(index)
				if chosen < 0 or index + 1 == _mouse_slot:
					chosen = index
		for index in visitors:
			if selection.ready[index]:
				chosen = index
				break
		var attended := not visitors.is_empty()
		UI.select(_card_buttons[clan], attended, GameState.CLANS[clan].color)
		clan_ninjas[clan].modulate = Color.WHITE if attended else Color(0.72, 0.72, 0.78)
		stamps[clan].visible = chosen >= 0 and selection.ready[chosen]
		Portraits.apply(clan_ninjas[clan], clan, GameState.SKIN_STYLES[GameState.skin_index(chosen + 1) if chosen >= 0 else 0])
		name_labels[clan].text = GameState.CLANS[clan].name
		name_labels[clan].add_theme_color_override("font_color", GameState.CLANS[clan].color)
		for offset in visitors.size():
			chips[visitors[offset]].position = Vector2(_banner_x(clan) + BANNER_W / 2 - visitors.size() * 16 + offset * 32, BANNER_Y - 27)
	for index in 4:
		var active := index < count
		for item in [_docks[index], _selection_labels[index], _skin_buttons[index], _player_buttons[index], chips[index]]:
			item.visible = active
		if not active:
			continue
		var solo := count == 1
		var compact := count > 2
		var width := (736.0 - 16 * (count - 1)) / count
		var x := 32 + index * (width + 16)
		var clan: Dictionary = GameState.CLANS[selection.clans[index]]
		_docks[index].position.x = x
		_docks[index].size.x = width
		_selection_labels[index].position = Vector2(x + 12, 348)
		_selection_labels[index].size.x = width - 24
		_selection_labels[index].text = ("YOUR CLAN  ·  " if solo else "P%d  ·  " % (index + 1)) + clan.name
		_selection_labels[index].add_theme_color_override("font_color", clan.color)
		_skin_buttons[index].text = GameState.skin_label(GameState.skin_index(index + 1)) + " >"
		_skin_buttons[index].disabled = selection.ready[index]
		_skin_buttons[index].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_skin_buttons[index].position = Vector2(328, 355) if solo else Vector2(x + 12, 373)
		_skin_buttons[index].size = Vector2(188, 40) if solo else Vector2(width - 88, 26) if compact else Vector2(190, 26)
		_skin_buttons[index].add_theme_font_size_override("font_size", 11 if compact else 14)
		var button := _player_buttons[index]
		button.text = "READY >" if solo else ("UNDO" if selection.ready[index] else "READY") if compact else "P%d  %s" % [index + 1, "UNLOCK" if selection.ready[index] else "LOCK IN"]
		button.position = Vector2(540, 352) if solo else Vector2(x + width - 68, 371) if compact else Vector2(x + 218, 352)
		button.size = Vector2(216, 46) if solo else Vector2(60, 30) if compact else Vector2(122, 46)
		button.add_theme_font_size_override("font_size", 12 if compact else 18)
		UI.select(button, solo or selection.ready[index] or _mouse_slot == index + 1, clan.color)
