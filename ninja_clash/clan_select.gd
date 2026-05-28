# Clan select. Both players pick. Same-clan pick is blocked (other player rejected).
# P1 = controller (D-pad move, Cross confirm, down un-confirm).
# P2 = keyboard (A/D move, Space confirm, S un-confirm).
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
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		p1_cursor = GameState.p1_clan
		p2_cursor = GameState.p2_clan
		p1_confirmed = false
		p2_confirmed = false
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
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

	# Fight Setup entry hint (bottom). Bound to the global "menu_setup" action (Tab / pad Select).
	var setup_hint := Label.new()
	setup_hint.position = Vector2(0, 374)
	setup_hint.size = Vector2(800, 20)
	setup_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_hint.add_theme_font_size_override("font_size", 13)
	setup_hint.add_theme_color_override("font_color", Color("8a8ea8"))
	setup_hint.text = "TAB / SELECT  —  FIGHT SETUP"
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
		GameState.change_state(GameState.State.MODE_SELECT)
		return
	# Fight Setup / Variants — open from any mode, at any point before lock-in. Returns here.
	if Input.is_action_just_pressed("menu_setup"):
		Audio.play("confirm")
		GameState.change_state(GameState.State.MATCH_SETUP)
		return
	# Free-for-all: only P1 picks; the three bots take the remaining clans automatically.
	if GameState.game_mode == GameState.Mode.FFA:
		if Input.is_action_just_pressed("p1_skin"):
			GameState.p1_skin = (GameState.p1_skin + 1) % GameState.skin_count()
			Audio.play("click"); _refresh()
		if Input.is_action_just_pressed("p1_left"):
			p1_cursor = (p1_cursor + 3) % 4
			Audio.play("click"); _refresh()
		elif Input.is_action_just_pressed("p1_right"):
			p1_cursor = (p1_cursor + 1) % 4
			Audio.play("click"); _refresh()
		elif Input.is_action_just_pressed("p1_jump"):
			GameState.p1_clan = p1_cursor
			GameState.assign_ffa_clans()
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
		elif Input.is_action_just_pressed("p1_jump"):
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
		elif Input.is_action_just_pressed("p2_jump"):
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

func _refresh() -> void:
	var ffa: bool = (GameState.game_mode == GameState.Mode.FFA)
	for i in 4:
		# A banner glows (selected sprite) when a player hovers or has locked it.
		var attended: bool = (i == p1_cursor) or (not ffa and i == p2_cursor)
		banners[i].texture = load(MENU + "clan_%s%s_native.png" % [CLAN_SLUGS[i], "_selected" if attended else ""])
		var locked: bool = (p1_confirmed and i == p1_cursor) or (not ffa and p2_confirmed and i == p2_cursor)
		stamps[i].visible = locked

		# Exactly ONE character per flag — never duplicated when two players share it (the chips
		# above show who's there, TowerFall-style). Skin: a player hovering alone previews their own
		# skin; a shared or unattended flag shows the base skin. Hidden only under the locked-in stamp.
		var p1_here: bool = (i == p1_cursor and not p1_confirmed)
		var p2_here: bool = (not ffa and i == p2_cursor and not p2_confirmed)
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
	var same: bool = (not ffa and p1_cursor == p2_cursor)
	var chip_w: float = 28.0 * CHIP_SCALE
	var chip_h: float = 22.0 * CHIP_SCALE
	var chip_y: float = BANNER_Y - chip_h - 2.0
	var centre1: float = _banner_x(p1_cursor) + (BANNER_W - chip_w) / 2.0
	var centre2: float = _banner_x(p2_cursor) + (BANNER_W - chip_w) / 2.0
	p1_chip.position = Vector2(centre1 + (-16.0 if same else 0.0), chip_y)
	p2_chip.position = Vector2(centre2 + (16.0 if same else 0.0), chip_y)
	p2_chip.visible = not ffa

	# Skin readouts — current skin name + cycle button, tinted to the hovered clan.
	p1_skin_label.text = "P1  □  %s" % GameState.skin_label(GameState.p1_skin)
	p1_skin_label.add_theme_color_override("font_color", GameState.CLANS[p1_cursor].color)
	p2_skin_label.visible = not ffa
	if not ffa:
		p2_skin_label.text = "P2  P  %s" % GameState.skin_label(GameState.p2_skin)
		p2_skin_label.add_theme_color_override("font_color", GameState.CLANS[p2_cursor].color)

	if ffa:
		status_label.text = "P1: pick your clan — the 3 bots take the rest"
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
