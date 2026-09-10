# Clan select. Both players pick in P1 vs P2 / AI vs AI / online; in the solo modes
# (P1 vs AI, FFA) only P1 picks — the bots' clans are auto-assigned on confirm.
# Same-clan pick is blocked (other player rejected).
# P1 = WASD keyboard (A/D move, Enter / Space confirm, S un-confirm) or pad 1 (D-pad, Cross).
# P2 = numpad (4/6 move, numpad-Enter / 0 confirm, 5 un-confirm) or pad 2.
# Circle / Esc (menu_cancel): back to mode select.
#
# Visuals: each clan banner sprite bakes its sigil + name (normal + glowing "selected"
# variants). Player chips (ui_chip_p*) mark who hovers which banner; the LOCKED IN stamp
# overlays a confirmed pick.
extends Control

const MENU := "res://sprites/menu/"
const CLAN_SLUGS: Array = ["shadow", "storm", "frost", "fire"]   # by GameState.CLANS index

const BANNER_W := 100.0
const BANNER_H := 150.0
const BANNER_GAP := 40.0
const BANNER_Y := 124.0
const CHIP_SCALE := 1.6
const STAMP_SCALE := 0.95
const NINJA_SIZE := 72.0       # skin preview on the hovered banner (16×16 frame, scaled up)
const NINJA_Y_OFF := 42.0      # ninja top, relative to BANNER_Y — centred on the (now empty) flag body
const NAME_Y := 264.0          # clan-name label row, just below the flags

var p1_cursor: int = 3
var p2_cursor: int = 1
var p1_confirmed: bool = false
var p2_confirmed: bool = false

var banners: Array = []        # TextureRect per clan
var stamps: Array = []         # locked-in TextureRect per clan (hidden unless confirmed)
var clan_ninjas: Array = []    # base-skin preview ON EVERY flag (so all 4 clan colours are visible at once)
var name_labels: Array = []    # clan name shown BELOW each flag
var p1_chip: TextureRect
var p2_chip: TextureRect
var p1_skin_label: Label       # "P1  □  CHEF" — current skin + cycle button
var p2_skin_label: Label
var status_label: Label
var _last_state_seen: int = -1
var _input_lockout_until: float = 0.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameState.state_changed.connect(_on_state_changed)
	visibility_changed.connect(_on_visibility_changed)
	# Online lobby sync (ADR-0003): host edits the P1 side, the guest edits P2 — each side's
	# pick streams to the other machine; the host validates clan conflicts.
	Net.lobby_peer_pick.connect(_on_remote_pick)
	Net.lobby_host_state.connect(_on_host_pick)
	Net.lobby_pick_rejected.connect(_on_pick_rejected)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		p1_cursor = GameState.p1_clan
		p2_cursor = GameState.p2_clan
		p1_confirmed = false
		p2_confirmed = false
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		if Net.is_online():
			_send_local_pick()   # both sides announce their pick on entry, so each sees the other
		_refresh()

func _on_state_changed(_s: int) -> void:
	_last_state_seen = _s

func _banner_x(i: int) -> float:
	var total: float = 4.0 * BANNER_W + 3.0 * BANNER_GAP
	return (800.0 - total) / 2.0 + i * (BANNER_W + BANNER_GAP)

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header := _spr(load(MENU + "header_choose_your_clan_native.png"), 0.85)
	header.position = Vector2((800.0 - header.size.x * 0.85) / 2.0, 10.0)

	for i in 4:
		var banner := _spr(load(MENU + "clan_%s_native.png" % CLAN_SLUGS[i]))
		banner.position = Vector2(_banner_x(i), BANNER_Y)
		banners.append(banner)

		var stamp := _spr(load(MENU + "ui_locked_in_stamp_native.png"), STAMP_SCALE)
		var sw: float = 90.0 * STAMP_SCALE
		stamp.position = Vector2(_banner_x(i) + (BANNER_W - sw) / 2.0, BANNER_Y + (BANNER_H - sw) / 2.0)
		stamp.visible = false
		stamps.append(stamp)

		# Base-skin character centred on every flag — lets you compare all four clan colours at once.
		var cn := _ninja_rect()
		cn.position = Vector2(_banner_x(i) + (BANNER_W - NINJA_SIZE) / 2.0, BANNER_Y + NINJA_Y_OFF)
		clan_ninjas.append(cn)

		# Clan name BELOW the flag (the flag art no longer bakes it in).
		var nm := Label.new()
		nm.position = Vector2(_banner_x(i) - 20.0, NAME_Y)
		nm.size = Vector2(BANNER_W + 40.0, 22.0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 16)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(nm)
		name_labels.append(nm)

	p1_chip = _spr(load(MENU + "ui_chip_p1_native.png"), CHIP_SCALE)
	p2_chip = _spr(load(MENU + "ui_chip_p2_native.png"), CHIP_SCALE)

	p1_skin_label = _skin_label_node(80.0, HORIZONTAL_ALIGNMENT_LEFT)
	p2_skin_label = _skin_label_node(440.0, HORIZONTAL_ALIGNMENT_RIGHT)

	status_label = Label.new()
	status_label.position = Vector2(0, 292)
	status_label.size = Vector2(800, 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)

	# Control hints (bottom). This is the busiest two-player screen, so it teaches every
	# control it accepts — move, lock, un-lock, skin cycle — plus the Fight Setup entry.
	var controls_hint := Label.new()
	controls_hint.position = Vector2(0, 356)
	controls_hint.size = Vector2(800, 18)
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.add_theme_font_size_override("font_size", 12)
	controls_hint.add_theme_color_override("font_color", Color("8a8ea8"))
	controls_hint.text = "◄ ► move      ✕ / Enter / Space — lock in      ▼ — un-lock      ▢ / P / 7 — skin"
	controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls_hint)
	var setup_hint := Label.new()
	setup_hint.position = Vector2(0, 376)
	setup_hint.size = Vector2(800, 18)
	setup_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_hint.add_theme_font_size_override("font_size", 12)
	setup_hint.add_theme_color_override("font_color", Color("8a8ea8"))
	setup_hint.text = "TAB / SELECT  —  FIGHT SETUP (rules & variants)"
	setup_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(setup_hint)

func _spr(tex: Texture2D, sprite_scale: float = 1.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(tex.get_size())
	tr.scale = Vector2(sprite_scale, sprite_scale)
	add_child(tr)
	return tr

func _ninja_rect() -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(NINJA_SIZE, NINJA_SIZE)
	add_child(tr)
	return tr

func _skin_label_node(x: float, align: int) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, 330)
	lbl.size = Vector2(280, 26)
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl

# Frame-0 idle-pose texture for a clan colour + skin style.
func _ninja_atlas(clan_idx: int, skin_idx: int) -> AtlasTexture:
	var color: String = GameState.CLANS[clan_idx].sprite
	var atlas := AtlasTexture.new()
	atlas.atlas = load(GameState.skin_pose_path(color, skin_idx))
	atlas.region = Rect2(0, 0, 16, 16)   # frame 0 = idle pose
	return atlas

func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	if Input.is_action_just_pressed("menu_cancel"):
		Audio.play("click")
		if Net.is_online():
			# Backing out of the online lobby ends the session for both sides.
			Net.leave("")
			GameState.change_state(GameState.State.ONLINE_MENU)
		else:
			GameState.change_state(GameState.State.MODE_SELECT)
		return
	# Fight Setup / Variants — open from any mode, at any point before lock-in. Returns here.
	# Online only the HOST owns the ruleset (it ships to the guest in the match bundle).
	if Input.is_action_just_pressed("menu_setup"):
		if Net.is_client():
			status_label.text = "the host sets the fight rules"
			status_label.add_theme_color_override("font_color", Color("a8a498"))
		else:
			Audio.play("confirm")
			GameState.change_state(GameState.State.MATCH_SETUP)
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
	# Solo-pick modes hide the whole P2 side — the bot's clan is assigned on confirm.
	var solo: bool = (GameState.game_mode == GameState.Mode.FFA) \
		or (GameState.game_mode == GameState.Mode.HUMAN_VS_AI and not Net.is_online())
	for i in 4:
		# A banner glows (selected sprite) when a player hovers or has locked it.
		var attended: bool = (i == p1_cursor) or (not solo and i == p2_cursor)
		banners[i].texture = load(MENU + "clan_%s%s_native.png" % [CLAN_SLUGS[i], "_selected" if attended else ""])
		var locked: bool = (p1_confirmed and i == p1_cursor) or (not solo and p2_confirmed and i == p2_cursor)
		stamps[i].visible = locked

		# Exactly ONE character per flag — never duplicated when two players share it (the chips
		# above show who's there, TowerFall-style). Skin: a player hovering alone previews their own
		# skin; a shared or unattended flag shows the base skin. Hidden only under the locked-in stamp.
		var p1_here: bool = (i == p1_cursor and not p1_confirmed)
		var p2_here: bool = (not solo and i == p2_cursor and not p2_confirmed)
		var skin_to_show: int = 0   # base ("CLASSIC")
		if p1_here and not p2_here:
			skin_to_show = GameState.p1_skin
		elif p2_here and not p1_here:
			skin_to_show = GameState.p2_skin
		clan_ninjas[i].visible = not locked
		if clan_ninjas[i].visible:
			clan_ninjas[i].texture = _ninja_atlas(i, skin_to_show)
			clan_ninjas[i].flip_h = false

		# Clan name below the flag, tinted to the clan colour.
		name_labels[i].text = GameState.CLANS[i].name
		name_labels[i].add_theme_color_override("font_color", GameState.CLANS[i].color)

	# Chips above the hovered banners; nudge apart when both players share a banner.
	var same: bool = (not solo and p1_cursor == p2_cursor)
	var chip_w: float = 28.0 * CHIP_SCALE
	var chip_h: float = 22.0 * CHIP_SCALE
	var chip_y: float = BANNER_Y - chip_h - 2.0
	var centre1: float = _banner_x(p1_cursor) + (BANNER_W - chip_w) / 2.0
	var centre2: float = _banner_x(p2_cursor) + (BANNER_W - chip_w) / 2.0
	p1_chip.position = Vector2(centre1 + (-16.0 if same else 0.0), chip_y)
	p2_chip.position = Vector2(centre2 + (16.0 if same else 0.0), chip_y)
	p2_chip.visible = not solo

	# Skin readouts — current skin name + cycle button, tinted to the hovered clan.
	p1_skin_label.text = "P1  □/P  %s" % GameState.skin_label(GameState.p1_skin)
	p1_skin_label.add_theme_color_override("font_color", GameState.CLANS[p1_cursor].color)
	p2_skin_label.visible = not solo
	if not solo:
		p2_skin_label.text = "P2  □/7  %s" % GameState.skin_label(GameState.p2_skin)
		p2_skin_label.add_theme_color_override("font_color", GameState.CLANS[p2_cursor].color)

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
		status_label.text = ""   # no idle instruction text (removed for a cleaner screen)
