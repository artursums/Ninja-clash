# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-18
#
# Map select. P1 navigates with A/D, confirms with W. X = random map.
# ESC: back to clan select.

extends Control

var cursor: int = 0
var tiles: Array = []
var name_labels: Array = []
var status_label: Label
var _input_lockout_until: float = 0.0   # swallow the screen-entry press so it can't bleed into confirm
const TILE_W: float = 150.0
const TILE_H: float = 110.0
const SPACING: float = 16.0

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _on_visibility_changed() -> void:
	if visible:
		cursor = GameState.selected_map_index
		_input_lockout_until = Time.get_ticks_msec() / 1000.0 + 0.2
		_refresh()

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color("0d0d1a")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var header: Label = Label.new()
	header.text = "CHOOSE ARENA"
	header.position = Vector2(0, 30)
	header.size = Vector2(800, 40)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color("f0eee8"))
	add_child(header)

	var count: int = Maps.count()
	var total_w: float = count * TILE_W + (count - 1) * SPACING
	var start_x: float = (800.0 - total_w) / 2.0
	var y: float = 140.0

	for i in count:
		var data: Dictionary = Maps.get_map(i)
		var tile_holder: Control = Control.new()
		tile_holder.position = Vector2(start_x + i * (TILE_W + SPACING), y)
		tile_holder.size = Vector2(TILE_W, TILE_H)
		tile_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tile_holder)

		# Background of thumbnail (uses map's bg_color)
		var thumb_bg: ColorRect = ColorRect.new()
		thumb_bg.size = Vector2(TILE_W, TILE_H)
		thumb_bg.color = data.bg_color
		thumb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_holder.add_child(thumb_bg)

		# Mini wall rendering, scaled 800x450 → TILE_W x TILE_H
		var scale_x: float = TILE_W / 800.0
		var scale_y: float = TILE_H / 450.0
		for w in data.walls:
			var mini: ColorRect = ColorRect.new()
			mini.size = Vector2(w.size.x * scale_x, w.size.y * scale_y)
			mini.position = Vector2(
				(w.center.x - w.size.x * 0.5) * scale_x,
				(w.center.y - w.size.y * 0.5) * scale_y,
			)
			mini.color = data.wall_color
			mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile_holder.add_child(mini)

		# Spawn dots
		for sp in data.spawn_points:
			var dot: ColorRect = ColorRect.new()
			dot.size = Vector2(4, 4)
			dot.position = Vector2(sp.x * scale_x - 2, sp.y * scale_y - 2)
			dot.color = Color("d4a830")
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile_holder.add_child(dot)

		tiles.append(tile_holder)

		var name_lbl: Label = Label.new()
		name_lbl.text = data.name
		name_lbl.position = Vector2(tile_holder.position.x, tile_holder.position.y + TILE_H + 6)
		name_lbl.size = Vector2(TILE_W, 24)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color("f0eee8"))
		add_child(name_lbl)
		name_labels.append(name_lbl)

	status_label = Label.new()
	status_label.position = Vector2(0, 350)
	status_label.size = Vector2(800, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("a8a498"))
	add_child(status_label)

	var hint: Label = Label.new()
	hint.text = "move: stick/D-pad or A/D    confirm: ✕ / Space    random: △ / X    back: ◯ / Esc"
	hint.position = Vector2(0, 420)
	hint.size = Vector2(800, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("6a6e88"))
	add_child(hint)

func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() / 1000.0 < _input_lockout_until:
		return
	# Back to clan select (Circle / Esc) and random map (Triangle / X) — any controller.
	if Input.is_action_just_pressed("menu_cancel"):
		GameState.change_state(GameState.State.CLAN_SELECT)
		return
	if Input.is_action_just_pressed("menu_random"):
		cursor = randi() % Maps.count()
		GameState.selected_map_index = cursor
		Audio.play("confirm")
		GameState.start_new_match()
		return
	var count: int = Maps.count()
	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left"):
		cursor = (cursor + count - 1) % count
		Audio.play("click")
		_refresh()
	elif Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right"):
		cursor = (cursor + 1) % count
		Audio.play("click")
		_refresh()
	elif Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump"):
		GameState.selected_map_index = cursor
		Audio.play("confirm")
		GameState.start_new_match()

func _refresh() -> void:
	for i in tiles.size():
		var tile: Control = tiles[i]
		if i == cursor:
			tile.modulate = Color(1.4, 1.4, 1.4)
			name_labels[i].add_theme_color_override("font_color", Color("d4a830"))
		else:
			tile.modulate = Color(0.55, 0.55, 0.6)
			name_labels[i].add_theme_color_override("font_color", Color("a8a498"))
	var picked: Dictionary = Maps.get_map(cursor)
	status_label.text = "↑ " + picked.name + " — press W or ↑ to confirm"
