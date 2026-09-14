extends Control

const UI := preload("res://menu_ui.gd")
const Portraits := preload("res://clan_portraits.gd")
var seats: Array = []
var count_label: Label
var status_label: Label
var invite_button: Button
var map_button: Button
var rules_button: Button
var start_button: Button
var rules_overlay: Control
var rules_text: Label
var _lockout := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.backdrop(self, 0.86)
	UI.label(self, "ONLINE LOBBY", Rect2(32, 26, 300, 38), 32)
	count_label = UI.label(self, "", Rect2(32, 62, 470, 24), 16, UI.MUTED)
	invite_button = UI.button(self, "COPY INVITE", Rect2(500, 32, 160, 44), _copy_invite, 18)
	UI.button(self, "LEAVE", Rect2(672, 32, 96, 44), _leave, 18)
	for index in 4:
		var x := 32 + index * 188
		var card := UI.panel(self, Rect2(x, 100, 176, 246))
		var title := UI.label(card, "", Rect2(8, 6, 160, 26), 21, UI.IVORY, true)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var role := UI.label(card, "", Rect2(8, 32, 160, 20), 14, UI.MUTED, true)
		var portrait := UI.image(card, null, Rect2(56, 51, 64, 92))
		var previous := UI.button(card, "<", Rect2(8, 84, 38, 44), _cycle_clan.bind(-1), 22)
		var next := UI.button(card, ">", Rect2(130, 84, 38, 44), _cycle_clan.bind(1), 22)
		var clan := UI.label(card, "", Rect2(8, 139, 160, 23), 19, UI.IVORY, true)
		var skin := UI.button(card, "", Rect2(8, 162, 160, 29), _cycle_skin, 14)
		var ready := UI.button(card, "", Rect2(8, 195, 160, 44), _toggle_ready, 18)
		var empty := UI.label(card, "+\nOPEN SEAT\nInvite a friend", Rect2(8, 65, 160, 120), 20, UI.MUTED, true)
		seats.append({"card": card, "title": title, "role": role, "portrait": portrait,
			"previous": previous, "next": next, "clan": clan, "skin": skin, "ready": ready, "empty": empty})
	map_button = UI.button(self, "", Rect2(32, 356, 280, 44), Net.choose_map, 17)
	rules_button = UI.button(self, "VIEW RULES", Rect2(324, 356, 180, 44), _rules, 17)
	start_button = UI.button(self, "", Rect2(516, 356, 252, 44), Net.start_lobby_match, 20)
	status_label = UI.footer(self, "")
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rules_overlay = Control.new()
	rules_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rules_overlay)
	UI.fill(rules_overlay, Rect2(0, 0, 800, 450), Color(0.025, 0.03, 0.08, 0.94))
	UI.panel(rules_overlay, Rect2(180, 38, 440, 366), UI.GOLD)
	UI.label(rules_overlay, "MATCH RULES", Rect2(200, 50, 400, 40), 28, UI.GOLD, true)
	rules_text = UI.label(rules_overlay, "", Rect2(220, 96, 360, 238), 18)
	UI.button(rules_overlay, "BACK TO LOBBY", Rect2(252, 346, 296, 44), rules_overlay.hide, 19)
	rules_overlay.hide()
	Net.lobby_changed.connect(_refresh)
	Net.lobby_error.connect(func(message: String): status_label.text = message)
	visibility_changed.connect(_on_visibility)
	_refresh()

func _on_visibility() -> void:
	if visible:
		_lockout = Time.get_ticks_msec() / 1000.0 + 0.25
		rules_overlay.hide()
		_refresh()

func _refresh() -> void:
	if seats.is_empty():
		return
	var players: Array = Net.lobby.members
	var mine := Net.local_member()
	count_label.text = "%d / 4 PLAYERS  ·  2–4 players, free-for-all" % players.size()
	for index in 4:
		var seat: Dictionary = seats[index]
		var occupied := index < players.size()
		seat.empty.visible = not occupied
		for key in ["title", "role", "portrait", "clan", "skin", "ready"]:
			seat[key].visible = occupied
		seat.previous.visible = false
		seat.next.visible = false
		if not occupied:
			seat.card.add_theme_stylebox_override("panel", UI.style())
			continue
		var player: Dictionary = players[index]
		var local: bool = not mine.is_empty() and mine.peer == player.peer
		var clan: Dictionary = GameState.CLANS[int(player.clan)]
		seat.title.text = player.name
		seat.title.tooltip_text = player.name
		seat.role.text = "P%d%s%s" % [index + 1, " · YOU" if local else "", " · HOST" if int(player.peer) == 1 else ""]
		seat.card.add_theme_stylebox_override("panel", UI.style(local or player.ready, clan.color))
		Portraits.apply(seat.portrait, int(player.clan), GameState.SKIN_STYLES[int(player.skin)])
		seat.clan.text = clan.name
		seat.clan.add_theme_color_override("font_color", clan.color)
		var taken := players.any(func(other): return other.peer != player.peer and other.ready and other.clan == player.clan)
		if taken:
			seat.clan.text += " · TAKEN"
		seat.previous.visible = local
		seat.next.visible = local
		for key in ["previous", "next", "skin"]:
			seat[key].disabled = not local or player.ready or Net.lobby.locked
		seat.skin.text = GameState.skin_label(int(player.skin)) + (" >" if local else "")
		seat.ready.text = ("UNREADY" if local else "READY") if player.ready else ("READY" if local else "CHOOSING…")
		seat.ready.disabled = not local or Net.lobby.locked or (not player.ready and (taken or Net.lobby.editing_rules))
		UI.select(seat.ready, player.ready, Color("8cdc64"))
		seat.ready.add_theme_color_override("font_disabled_color", Color("8cdc64") if player.ready else UI.MUTED)
	invite_button.text = "COPY INVITE" if OS.has_feature("web") else "COPY ADDRESS"
	invite_button.disabled = Net.invitation_code == "" if OS.has_feature("web") else not Net.is_host()
	map_button.text = Maps.get_map(GameState.selected_map_index).name + (" >" if Net.is_host() else "")
	map_button.disabled = not Net.is_host() or Net.lobby.locked
	rules_button.text = "RULES · %d HP · %d WINS" % [MatchConfig.max_hp, GameState.target_score]
	rules_button.add_theme_font_size_override("font_size", 14)
	rules_button.tooltip_text = "Edit match rules (Tab)" if Net.is_host() else "View all match rules (Tab)"
	rules_button.disabled = Net.lobby.locked
	start_button.text = "START WITH %d PLAYERS" % players.size() if Net.is_host() else "HOST STARTS THE MATCH"
	start_button.tooltip_text = "Host: press F or gamepad Start"
	start_button.disabled = not Net.is_host() or not Net.lobby.can_start()
	UI.select(start_button, not start_button.disabled)
	if Net.lobby.locked:
		status_label.text = "STARTING MATCH…"
	elif Net.lobby.editing_rules:
		status_label.text = "HOST IS CHOOSING THE RULES"
	elif players.size() < 2:
		status_label.text = "INVITE A FRIEND TO START · EMPTY SEATS ARE OPTIONAL"
	elif Net.lobby.can_start():
		status_label.text = "EVERYONE IS READY · HOST: START THE MATCH (F / GAMEPAD START)"
	else:
		var waiting: Array[String] = []
		for player in players:
			if not player.ready:
				waiting.append(String(player.name))
		status_label.text = "WAITING FOR " + ", ".join(waiting)
	if Net.lobby_message != "" and not Net.lobby.can_start():
		status_label.text = Net.lobby_message
	status_label.tooltip_text = status_label.text
	_refresh_rules()

func _cycle_clan(direction: int) -> void:
	var mine := Net.local_member()
	if mine.is_empty() or mine.ready:
		return
	for step in range(1, 5):
		var clan := posmod(int(mine.clan) + direction * step, 4)
		if not Net.lobby.members.any(func(other): return other.peer != mine.peer and other.ready and int(other.clan) == clan):
			Net.choose_character(clan, int(mine.skin), false)
			return

func _cycle_skin() -> void:
	var mine := Net.local_member()
	if not mine.is_empty() and not mine.ready:
		Net.choose_character(int(mine.clan), (int(mine.skin) + 1) % GameState.skin_count(), false)

func _toggle_ready() -> void:
	var mine := Net.local_member()
	if not mine.is_empty():
		Net.choose_character(int(mine.clan), int(mine.skin), not mine.ready)

func _copy_invite() -> void:
	var address := Net.invitation_url() if OS.has_feature("web") else " / ".join(Net.local_ipv4_addresses())
	DisplayServer.clipboard_set(address)
	status_label.text = "INVITE COPIED — SHARE IT WITH UP TO THREE FRIENDS"

func _rules() -> void:
	if Net.is_host():
		Net.edit_rules()
	else:
		_refresh_rules()
		rules_overlay.show()

func _refresh_rules() -> void:
	rules_text.text = "2–4 PLAYERS · FREE-FOR-ALL\nFirst to %d wins · %d HP\nKatana: %s · %d charges\nRecharge each round: %s\nShurikens: %s · Start with %d\nInfinite shurikens: %s\nBlade wave: %s" % [GameState.target_score, MatchConfig.max_hp,
		_on_off(MatchConfig.katana_enabled), MatchConfig.katana_charges, _on_off(MatchConfig.katana_recharge),
		_on_off(MatchConfig.shurikens_enabled), MatchConfig.start_shurikens, _on_off(MatchConfig.infinite_shurikens), _on_off(MatchConfig.blade_wave_enabled)]

func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"

func _leave() -> void:
	Net.leave()
	GameState.change_state(GameState.State.TITLE)

func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec() / 1000.0 < _lockout:
		return
	if rules_overlay.visible:
		if Input.is_action_just_pressed("menu_cancel") or UI.confirm():
			rules_overlay.hide()
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_leave()
	elif Input.is_action_just_pressed("menu_setup"):
		_rules()
	elif UI.nav("left") or UI.nav("right"):
		_cycle_clan(1 if UI.nav("right") else -1)
	elif Input.is_action_just_pressed("menu_random") and Net.is_host():
		Net.choose_map()
	elif UI.nav("skin"):
		_cycle_skin()
	elif UI.confirm():
		_toggle_ready()
	elif Input.is_action_just_pressed("online_start") and Net.is_host():
		Net.start_lobby_match()
