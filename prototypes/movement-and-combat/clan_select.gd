# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Clan select. Both players pick. Same-clan pick is blocked (other player rejected).
# P1 = controller (D-pad move, Cross confirm, down un-confirm).
# P2 = keyboard (A/D move, Space confirm, S un-confirm).
# Circle / Esc (menu_cancel): back to title.

extends Control

var p1_cursor: int = 3
var p2_cursor: int = 1
var p1_confirmed: bool = false
var p2_confirmed: bool = false

var tiles: Array = []
var p1_indicator: Label
var p2_indicator: Label
var status_label: Label
var _last_state_seen: int = -1
var _input_lockout_until: float = 0.0   # swallow the screen-entry press so it can't bleed into a pick

const TILE_W: float = 140.0
const TILE_H: float = 180.0
const SPACING: float = 20.0

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
		# Restore last-used clans as cursors; reset confirmations
		p1_cursor = GameState.p1_clan
		p2_cursor = GameState.p2_clan
		p1_confirmed = false
		p2_confirmed = false
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()

func _on_state_changed(_s: int) -> void:
	_last_state_seen = _s

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header: Label = Label.new()
	header.text = "CHOOSE YOUR CLAN"
	header.position = Vector2(0, 30)
	header.size = Vector2(800, 40)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color("f0eee8"))
	add_child(header)

	var total_w: float = 4.0 * TILE_W + 3.0 * SPACING
	var start_x: float = (800.0 - total_w) / 2.0
	var y: float = 110.0

	for i in 4:
		var clan: Dictionary = GameState.CLANS[i]
		var tile: ColorRect = ColorRect.new()
		tile.position = Vector2(start_x + i * (TILE_W + SPACING), y)
		tile.size = Vector2(TILE_W, TILE_H)
		tile.color = clan.color
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tile)

		# Inset secondary color stripe at bottom
		var stripe: ColorRect = ColorRect.new()
		stripe.position = Vector2(tile.position.x, tile.position.y + TILE_H - 14)
		stripe.size = Vector2(TILE_W, 14)
		stripe.color = clan.secondary
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)

		var name_lbl: Label = Label.new()
		name_lbl.text = clan.name
		name_lbl.position = Vector2(tile.position.x, tile.position.y + TILE_H + 6)
		name_lbl.size = Vector2(TILE_W, 30)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", clan.color)
		add_child(name_lbl)

		tiles.append(tile)

	p1_indicator = Label.new()
	p1_indicator.add_theme_font_size_override("font_size", 16)
	add_child(p1_indicator)

	p2_indicator = Label.new()
	p2_indicator.add_theme_font_size_override("font_size", 16)
	add_child(p2_indicator)

	status_label = Label.new()
	status_label.position = Vector2(0, 380)
	status_label.size = Vector2(800, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)

	var hint: Label = Label.new()
	hint.text = "P1 (pad): D-pad move · ✕ confirm · ↓ un-confirm    P2 (keys): A/D move · Space confirm · S un-confirm    ◯/Esc: back"
	hint.position = Vector2(0, 425)
	hint.size = Vector2(800, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("6a6e88"))
	add_child(hint)

func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	# Back to title — any controller (Circle) or Esc.
	if Input.is_action_just_pressed("menu_cancel"):
		Audio.play("click")
		GameState.change_state(GameState.State.TITLE)
		return
	if not p1_confirmed:
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
	for i in 4:
		var tile: ColorRect = tiles[i]
		var is_p1_hover: bool = (not p1_confirmed and i == p1_cursor)
		var is_p2_hover: bool = (not p2_confirmed and i == p2_cursor)
		var is_p1_locked: bool = (p1_confirmed and i == p1_cursor)
		var is_p2_locked: bool = (p2_confirmed and i == p2_cursor)
		if is_p1_locked or is_p2_locked:
			tile.modulate = Color(1.15, 1.15, 1.15)
		elif is_p1_hover or is_p2_hover:
			tile.modulate = Color(1.4, 1.4, 1.4)
		else:
			tile.modulate = Color(0.5, 0.5, 0.5)

	var total_w: float = 4.0 * TILE_W + 3.0 * SPACING
	var start_x: float = (800.0 - total_w) / 2.0
	var p1_x: float = start_x + p1_cursor * (TILE_W + SPACING) + TILE_W * 0.5 - 30
	var p2_x: float = start_x + p2_cursor * (TILE_W + SPACING) + TILE_W * 0.5 + 4
	var y_below: float = 110.0 + TILE_H + 40.0
	p1_indicator.position = Vector2(p1_x, y_below)
	p2_indicator.position = Vector2(p2_x, y_below)
	p1_indicator.text = "▲ P1 LOCKED" if p1_confirmed else "▲ P1"
	p2_indicator.text = "▲ P2 LOCKED" if p2_confirmed else "▲ P2"
	p1_indicator.add_theme_color_override("font_color", GameState.CLANS[p1_cursor].color)
	p2_indicator.add_theme_color_override("font_color", GameState.CLANS[p2_cursor].color)

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
		status_label.text = "both players: pick your clan and lock in"
		status_label.add_theme_color_override("font_color", Color("a8a498"))
