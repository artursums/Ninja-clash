extends Control

const Portraits := preload("res://clan_portraits.gd")
const UI = preload("res://menu_ui.gd")

const BANNER_W := 164.0
const BANNER_GAP := 24.0
const BANNER_Y := 112.0
const CHIP_SCALE := 1.6
const PORTRAIT_SIZE := Vector2(128, 192)
const NAME_Y := 310.0

var p1_cursor: int = 3
var p2_cursor: int = 1
var p1_confirmed: bool = false
var p2_confirmed: bool = false

var stamps: Array[Label] = []
var clan_ninjas: Array[TextureRect] = []
var name_labels: Array = []    # clan name shown BELOW each flag
var p1_chip: Label
var p2_chip: Label
var status_label: Label
var _mouse_slot := 1
var _card_buttons: Array[Button] = []
var _player_buttons: Array[Button] = []
var _skin_buttons: Array[Button] = []
var _selection_labels: Array[Label] = []
var _docks: Array[Panel] = []
var _input_lockout_until: float = 0.0
var _opened_frame := -1

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	# Online lobby sync (ADR-0003): host edits the P1 side, the guest edits P2 — each side's
	# pick streams to the other machine; the host validates clan conflicts.
	Net.lobby_peer_pick.connect(_on_remote_pick)
	Net.lobby_host_state.connect(_on_host_pick)
	Net.lobby_pick_rejected.connect(_on_pick_rejected)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		_opened_frame = Engine.get_process_frames()
		p1_cursor = GameState.p1_clan
		p2_cursor = GameState.p2_clan
		p1_confirmed = false
		p2_confirmed = false
		_mouse_slot = 1
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		if Net.is_online():
			_send_local_pick()   # both sides announce their pick on entry, so each sees the other
		_refresh()
		_input_lockout_until = Time.get_ticks_msec()/1000.0+0.2

func _banner_x(i: int) -> float:
	var total: float = 4.0 * BANNER_W + 3.0 * BANNER_GAP
	return (800.0 - total) / 2.0 + i * (BANNER_W + BANNER_GAP)

func _build() -> void:
	UI.backdrop(self, 0.78)
	UI.header(self, "CHOOSE YOUR CLAN", 1)
	for i in 4:
		var card := UI.button(self, "", Rect2(_banner_x(i), BANNER_Y, BANNER_W, 222), _mouse_pick.bind(i))
		_card_buttons.append(card)
		var cn := UI.image(self, Portraits.texture(i, "base"), Rect2(Vector2(_banner_x(i) + (BANNER_W - PORTRAIT_SIZE.x) / 2.0, BANNER_Y + 4), PORTRAIT_SIZE))
		clan_ninjas.append(cn)
		var stamp := UI.label(self, "LOCKED", Rect2(_banner_x(i), BANNER_Y + 158, BANNER_W, 30), 22, UI.GOLD, true)
		stamp.add_theme_color_override("font_shadow_color", UI.INK)
		stamp.add_theme_constant_override("shadow_offset_x", 2)
		stamp.add_theme_constant_override("shadow_offset_y", 2)
		stamps.append(stamp)
		name_labels.append(UI.label(self, "", Rect2(_banner_x(i), NAME_Y, BANNER_W, 24), 21, UI.IVORY, true))
	p1_chip = UI.label(self, "P1", Rect2(0, 0, 45, 27), 22, UI.IVORY, true)
	p2_chip = UI.label(self, "P2", Rect2(0, 0, 45, 27), 22, UI.IVORY, true)
	for slot in [1, 2]:
		var x := 32 if slot == 1 else 416
		_docks.append(UI.panel(self, Rect2(x, 344, 352, 62)))
		_selection_labels.append(UI.label(self, "", Rect2(x + 12, 348, 196, 20), 16))
		_skin_buttons.append(UI.button(self, "", Rect2(x + 12, 373, 190, 26), _mouse_skin.bind(slot), 14))
		_player_buttons.append(UI.button(self, "", Rect2(x + 218, 352, 122, 46), _mouse_lock.bind(slot), 18))
	status_label = UI.label(self, "", Rect2(398, 62, 370, 26), 12, UI.MUTED, true)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(self, "< BACK", Rect2(32, 416, 100, 24), _back, 14)
	UI.button(self, "TAB  RULES", Rect2(650, 416, 118, 24), _setup, 14)
	UI.label(self, "A/D  SELECT   ENTER  READY   P  SKIN   P2  NUM 4/6 + 0", Rect2(144, 416, 496, 24), 12, UI.MUTED, true)

func _solo() -> bool:
	return not Net.is_online() and GameState.game_mode in [GameState.Mode.HUMAN_VS_AI, GameState.Mode.FFA]

func _mouse_ready() -> bool:
	return visible and Time.get_ticks_msec() / 1000.0 >= _input_lockout_until

func _mouse_pick(index: int) -> void:
	if not _mouse_ready():
		return
	var slot := (1 if Net.is_host() else 2) if Net.is_online() else _mouse_slot
	if slot == 1 and not p1_confirmed:
		p1_cursor = index
	elif slot == 2 and not p2_confirmed:
		p2_cursor = index
	Audio.play("click")
	_send_local_pick()
	_refresh()

func _mouse_skin(slot: int) -> void:
	if not _mouse_ready() or (Net.is_online() and slot != (1 if Net.is_host() else 2)):
		return
	if slot == 1 and not p1_confirmed:
		GameState.p1_skin = (GameState.p1_skin + 1) % GameState.skin_count()
		_mouse_slot = slot
	elif slot == 2 and not p2_confirmed:
		GameState.p2_skin = (GameState.p2_skin + 1) % GameState.skin_count()
		_mouse_slot = slot
	Audio.play("click")
	_send_local_pick()
	_refresh()

func _mouse_lock(slot: int) -> void:
	if not _mouse_ready() or (Net.is_online() and slot != (1 if Net.is_host() else 2)):
		return
	_mouse_slot = slot
	var mine := p1_cursor if slot == 1 else p2_cursor
	var other := p2_cursor if slot == 1 else p1_cursor
	var other_locked := p2_confirmed if slot == 1 else p1_confirmed
	var locked := p1_confirmed if slot == 1 else p2_confirmed
	if not locked and not _solo() and mine == other and other_locked:
		status_label.text = "CLAN TAKEN - CHOOSE ANOTHER"
		Audio.play("hit")
		return
	if _solo():
		GameState.p1_clan = p1_cursor
		if GameState.game_mode == GameState.Mode.FFA:
			GameState.assign_ffa_clans()
		else:
			GameState.p2_clan = (p1_cursor + randi_range(1, 3)) % 4
		Audio.play("confirm")
		GameState.change_state(GameState.State.MAP_SELECT)
		return
	if slot == 1:
		p1_confirmed = not locked
		GameState.p1_clan = p1_cursor
		if p1_confirmed and not Net.is_online():
			_mouse_slot = 2
	else:
		p2_confirmed = not locked
		GameState.p2_clan = p2_cursor
	Audio.play("confirm")
	_send_local_pick()
	_refresh()
	if p1_confirmed and p2_confirmed and not Net.is_client():
		GameState.change_state(GameState.State.MAP_SELECT)

func _back() -> void:
	Audio.play("click")
	if Net.is_online():
		Net.leave("")
		GameState.change_state(GameState.State.ONLINE_MENU)
	else:
		GameState.change_state(GameState.State.MODE_SELECT)

func _setup() -> void:
	if Net.is_client():
		status_label.text = "THE HOST SETS THE FIGHT RULES"
		return
	GameState.p1_clan = p1_cursor
	GameState.p2_clan = p2_cursor
	Audio.play("confirm")
	GameState.change_state(GameState.State.MATCH_SETUP)

func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() <= _opened_frame+1:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_back()
		return
	if Input.is_action_just_pressed("menu_setup"):
		_setup()
		return
	if Net.is_online():
		_process_online()
		return
	# Solo-pick modes: only P1 chooses, the bots are assigned automatically on confirm.
	# FFA — the three bots split the remaining clans; P1 vs AI — the bot takes a random
	# other clan. (AI vs AI keeps manual confirms — you're staging both sides of the demo.)
	if GameState.game_mode == GameState.Mode.FFA or GameState.game_mode == GameState.Mode.HUMAN_VS_AI:
		if Input.is_action_just_pressed("p1_skin"):
			GameState.p1_skin = (GameState.p1_skin + 1) % GameState.skin_count()
			Audio.play("click"); _refresh()
		if Input.is_action_just_pressed("p1_left"):
			p1_cursor = (p1_cursor + 3) % 4
			Audio.play("click"); _refresh()
		elif Input.is_action_just_pressed("p1_right"):
			p1_cursor = (p1_cursor + 1) % 4
			Audio.play("click"); _refresh()
		elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p1_confirm"):
			GameState.p1_clan = p1_cursor
			if GameState.game_mode == GameState.Mode.FFA:
				GameState.assign_ffa_clans()
			else:
				GameState.p2_clan = (p1_cursor + 1 + randi() % 3) % 4
			Audio.play("confirm")
			GameState.change_state(GameState.State.MAP_SELECT)
		return

	if not p1_confirmed:
		if Input.is_action_just_pressed("p1_skin"):
			GameState.p1_skin = (GameState.p1_skin + 1) % GameState.skin_count()
			_mouse_slot = 1
			Audio.play("click")
			_refresh()
		if Input.is_action_just_pressed("p1_left"):
			p1_cursor = (p1_cursor + 3) % 4
			Audio.play("click")
			_refresh()
		elif Input.is_action_just_pressed("p1_right"):
			p1_cursor = (p1_cursor + 1) % 4
			Audio.play("click")
			_refresh()
		elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p1_confirm"):
			if p2_confirmed and p2_cursor == p1_cursor:
				status_label.text = "P2 already picked %s — choose another" % GameState.CLANS[p1_cursor].name
				status_label.add_theme_color_override("font_color", Color("c03030"))
				Audio.play("hit")
				return
			p1_confirmed = true
			GameState.p1_clan = p1_cursor
			Audio.play("confirm")
			_refresh()
	else:
		if Input.is_action_just_pressed("p1_aim_down"):
			p1_confirmed = false
			Audio.play("click")
			_refresh()

	if not p2_confirmed:
		if Input.is_action_just_pressed("p2_skin"):
			GameState.p2_skin = (GameState.p2_skin + 1) % GameState.skin_count()
			_mouse_slot = 2
			Audio.play("click")
			_refresh()
		if Input.is_action_just_pressed("p2_left"):
			p2_cursor = (p2_cursor + 3) % 4
			Audio.play("click")
			_refresh()
		elif Input.is_action_just_pressed("p2_right"):
			p2_cursor = (p2_cursor + 1) % 4
			Audio.play("click")
			_refresh()
		elif Input.is_action_just_pressed("p2_jump") or Input.is_action_just_pressed("p2_confirm"):
			if p1_confirmed and p1_cursor == p2_cursor:
				status_label.text = "P1 already picked %s — choose another" % GameState.CLANS[p2_cursor].name
				status_label.add_theme_color_override("font_color", Color("c03030"))
				Audio.play("hit")
				return
			p2_confirmed = true
			GameState.p2_clan = p2_cursor
			Audio.play("confirm")
			_refresh()
	else:
		if Input.is_action_just_pressed("p2_aim_down"):
			p2_confirmed = false
			Audio.play("click")
			_refresh()

	if p1_confirmed and p2_confirmed:
		GameState.change_state(GameState.State.MAP_SELECT)

# === Online lobby (ADR-0003) ================================================

# Any LOCAL device — online there is one human per machine, so both keyboard schemes and any
# pad drive that machine's side of the lobby.
func _act(suffix: String) -> bool:
	return Input.is_action_just_pressed("p1_" + suffix) or Input.is_action_just_pressed("p2_" + suffix)

# Online frame: edit MY side with local input, mirror the remote side from Net signals.
# The host validates conflicts and is the only one who advances to map select.
func _process_online() -> void:
	var host: bool = Net.is_host()
	var my_confirmed: bool = p1_confirmed if host else p2_confirmed
	var changed: bool = false
	if not my_confirmed:
		if _act("skin"):
			if host:
				GameState.p1_skin = (GameState.p1_skin + 1) % GameState.skin_count()
			else:
				GameState.p2_skin = (GameState.p2_skin + 1) % GameState.skin_count()
			Audio.play("click")
			changed = true
		if _act("left") or _act("right"):
			var step: int = 1 if _act("right") else 3
			if host:
				p1_cursor = (p1_cursor + step) % 4
			else:
				p2_cursor = (p2_cursor + step) % 4
			Audio.play("click")
			changed = true
		elif _act("jump") or _act("confirm"):
			var my_cursor: int = p1_cursor if host else p2_cursor
			var other_confirmed: bool = p2_confirmed if host else p1_confirmed
			var other_cursor: int = p2_cursor if host else p1_cursor
			if other_confirmed and other_cursor == my_cursor:
				status_label.text = "%s is already taken — choose another" % GameState.CLANS[my_cursor].name
				status_label.add_theme_color_override("font_color", Color("c03030"))
				Audio.play("hit")
			else:
				if host:
					p1_confirmed = true
					GameState.p1_clan = p1_cursor
				else:
					p2_confirmed = true
					GameState.p2_clan = p2_cursor   # preview; the host's bundle is authoritative
				Audio.play("confirm")
				changed = true
	elif _act("aim_down"):
		if host:
			p1_confirmed = false
		else:
			p2_confirmed = false
		Audio.play("click")
		changed = true
	if changed:
		_send_local_pick()
		_refresh()
	# Only the host starts the match flow; the guest follows via the state relay.
	if host and p1_confirmed and p2_confirmed:
		GameState.change_state(GameState.State.MAP_SELECT)

# Push MY side's current pick to the other machine.
func _send_local_pick() -> void:
	if Net.is_host():
		Net.send_host_pick(p1_cursor, GameState.p1_skin, p1_confirmed)
	elif Net.is_client():
		Net.send_client_pick(p2_cursor, GameState.p2_skin, p2_confirmed)

# Host ← guest: the P2 side changed. Validate a confirm against the host's own lock.
func _on_remote_pick(cursor: int, skin: int, confirmed: bool) -> void:
	if not visible or not Net.is_host():
		return
	p2_cursor = clampi(cursor, 0, 3)
	GameState.p2_skin = skin % GameState.skin_count()
	if confirmed and p1_confirmed and p2_cursor == p1_cursor:
		p2_confirmed = false
		Net.send_pick_rejected("P1 already picked %s — choose another" % GameState.CLANS[p1_cursor].name)
	else:
		p2_confirmed = confirmed
		if confirmed:
			GameState.p2_clan = p2_cursor
	_refresh()

# Guest ← host: the P1 side changed.
func _on_host_pick(cursor: int, skin: int, confirmed: bool) -> void:
	if not visible or not Net.is_client():
		return
	p1_cursor = clampi(cursor, 0, 3)
	GameState.p1_skin = skin % GameState.skin_count()
	p1_confirmed = confirmed
	_refresh()

# Guest ← host: my confirm was refused (clan taken on the host's authoritative view).
func _on_pick_rejected(reason: String) -> void:
	if not visible or not Net.is_client():
		return
	p2_confirmed = false
	Audio.play("hit")
	_send_local_pick()
	_refresh()
	# After _refresh so the standard status text can't paint over the rejection.
	status_label.text = reason
	status_label.add_theme_color_override("font_color", Color("c03030"))

func _refresh() -> void:
	if not Net.is_online():
		if p1_confirmed and not p2_confirmed:
			_mouse_slot = 2
		elif p2_confirmed and not p1_confirmed:
			_mouse_slot = 1
	# Solo-pick modes hide the whole P2 side — the bot's clan is assigned on confirm.
	var solo: bool = (GameState.game_mode == GameState.Mode.FFA) \
		or (GameState.game_mode == GameState.Mode.HUMAN_VS_AI and not Net.is_online())
	for i in 4:
		var attended: bool = (i == p1_cursor) or (not solo and i == p2_cursor)
		UI.select(_card_buttons[i], attended, GameState.CLANS[i].color)
		clan_ninjas[i].modulate = Color.WHITE if attended else Color(0.72, 0.72, 0.78)
		var locked: bool = (p1_confirmed and i == p1_cursor) or (not solo and p2_confirmed and i == p2_cursor)
		stamps[i].visible = locked

		var p1_here: bool = i == p1_cursor
		var p2_here: bool = not solo and i == p2_cursor
		var active_slot: int = (1 if Net.is_host() else 2) if Net.is_online() else _mouse_slot
		var skin_to_show: int = 0
		if p1_here and (not p2_here or p1_confirmed or (not p2_confirmed and active_slot == 1)):
			skin_to_show = GameState.p1_skin
		elif p2_here:
			skin_to_show = GameState.p2_skin
		Portraits.apply(clan_ninjas[i], i, GameState.SKIN_STYLES[skin_to_show])

		# Clan name below the flag, tinted to the clan colour.
		name_labels[i].text = GameState.CLANS[i].name
		name_labels[i].add_theme_color_override("font_color", GameState.CLANS[i].color)

	# Chips above the hovered banners; nudge apart when both players share a banner.
	var same: bool = (not solo and p1_cursor == p2_cursor)
	var chip_w: float = 28.0 * CHIP_SCALE
	var chip_y: float = BANNER_Y - 27.0
	var centre1: float = _banner_x(p1_cursor) + (BANNER_W - chip_w) / 2.0
	var centre2: float = _banner_x(p2_cursor) + (BANNER_W - chip_w) / 2.0
	p1_chip.position = Vector2(centre1 + (-16.0 if same else 0.0), chip_y)
	p2_chip.position = Vector2(centre2 + (16.0 if same else 0.0), chip_y)
	p2_chip.visible = not solo

	for slot in [1, 2]:
		var locked: bool = p1_confirmed if slot == 1 else p2_confirmed
		var local: bool = not Net.is_online() or slot == (1 if Net.is_host() else 2)
		_player_buttons[slot - 1].visible = slot == 1 or not solo
		_skin_buttons[slot - 1].visible = slot == 1 or not solo
		_player_buttons[slot - 1].disabled = not local
		_skin_buttons[slot - 1].disabled = not local or locked
		_player_buttons[slot - 1].text = "P%d  %s" % [slot, "UNLOCK" if locked else "LOCK IN"]
		_skin_buttons[slot - 1].text = "%s  >" % GameState.skin_label(GameState.p1_skin if slot == 1 else GameState.p2_skin)
		var index: int = slot - 1
		var clan: Dictionary = GameState.CLANS[p1_cursor if slot == 1 else p2_cursor]
		_docks[index].visible = slot == 1 or not solo
		_selection_labels[index].visible = slot == 1 or not solo
		_selection_labels[index].text = ("YOUR CLAN  ·  " if solo else "P%d  ·  " % slot) + clan.name
		_selection_labels[index].add_theme_color_override("font_color", clan.color)
		var x := 32.0 if slot == 1 else 416.0
		_docks[index].size.x = 736 if solo else 352
		_selection_labels[index].position = Vector2(x + 12, 348)
		_selection_labels[index].size.x = 270 if solo else 196
		_skin_buttons[index].position = Vector2(328, 355) if solo else Vector2(x + 12, 373)
		_skin_buttons[index].size = Vector2(188, 40) if solo else Vector2(190, 26)
		_player_buttons[index].position = Vector2(540, 352) if solo else Vector2(x + 218, 352)
		_player_buttons[index].size = Vector2(216, 46) if solo else Vector2(122, 46)
		if solo:
			_player_buttons[index].text = "READY  >"
		UI.select(_player_buttons[index], local and (solo or _mouse_slot == slot), clan.color)
	if solo:
		if GameState.game_mode == GameState.Mode.FFA:
			status_label.text = "P1: pick your clan — the 3 bots take the rest"
		else:
			status_label.text = "P1: pick your clan — the bot takes another"
		status_label.add_theme_color_override("font_color", Color("a8a498"))
		return
	if Net.is_online():
		var my_locked: bool = p1_confirmed if Net.is_host() else p2_confirmed
		if p1_confirmed and p2_confirmed:
			status_label.text = "starting..."
			status_label.add_theme_color_override("font_color", Color("d4a830"))
		elif my_locked:
			status_label.text = "locked in — waiting for your opponent…"
			status_label.add_theme_color_override("font_color", Color("a8a498"))
		else:
			status_label.text = "ONLINE — you are %s" % ("P1 (host)" if Net.is_host() else "P2 (guest)")
			status_label.add_theme_color_override("font_color", Color("a8a498"))
		return
	if p1_confirmed and p2_confirmed:
		status_label.text = "starting..."
		status_label.add_theme_color_override("font_color", Color("d4a830"))
	elif p1_confirmed:
		status_label.text = "waiting for P2 to lock..."
		status_label.add_theme_color_override("font_color", Color("a8a498"))
	elif p2_confirmed:
		status_label.text = "waiting for P1 to lock..."
		status_label.add_theme_color_override("font_color", Color("a8a498"))
	else:
		status_label.text = "P%d: CHOOSE A CLAN, THEN LOCK IN" % _mouse_slot
