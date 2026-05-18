# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Main scene controller.
# Builds map geometry (floor + 2 walls), registers input actions,
# spawns 2 players, builds tuning UI + scoreboard, handles respawn signal.

extends Node2D

const MAP_W := 800
const MAP_H := 450
const FLOOR_Y := 400
const WALL_THICK := 20
const PLAYER_W := 20.0
const PLAYER_H := 32.0

var players: Array = []
var spawn_points: Array = [Vector2(120, 350), Vector2(680, 350)]
var score_label: Label
var winner_label: Label
var diag_label: Label
var last_key_info: String = "(no key yet)"
var frame_counter: int = 0

func _ready() -> void:
	print("[MAIN] _ready() starting")
	_setup_input_map()
	_build_map()
	_build_ui()
	_spawn_players()
	Combat.score_changed.connect(_update_score)
	Combat.respawn_requested.connect(_on_respawn)
	_update_score()
	print("[MAIN] _ready() complete. Players spawned: ", players.size())

func _process(_delta: float) -> void:
	frame_counter += 1
	if diag_label:
		var p1_left = "←" if Input.is_action_pressed("p1_left") else " "
		var p1_right = "→" if Input.is_action_pressed("p1_right") else " "
		var p1_jump = "J" if Input.is_action_pressed("p1_jump") else " "
		var p1_throw = "T" if Input.is_action_pressed("p1_throw") else " "
		var p2_left = "←" if Input.is_action_pressed("p2_left") else " "
		var p2_right = "→" if Input.is_action_pressed("p2_right") else " "
		var p2_jump = "J" if Input.is_action_pressed("p2_jump") else " "
		var p2_throw = "T" if Input.is_action_pressed("p2_throw") else " "
		diag_label.text = "F:%d  P1[%s%s%s%s]  P2[%s%s%s%s]  Last:%s" % [
			frame_counter, p1_left, p1_right, p1_jump, p1_throw,
			p2_left, p2_right, p2_jump, p2_throw, last_key_info]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		last_key_info = "kc=%d phys=%d" % [event.keycode, event.physical_keycode]
		print("[KEY] keycode=", event.keycode, " physical=", event.physical_keycode,
			" unicode=", event.unicode)
		if event.physical_keycode == KEY_R:
			print("[MAIN] R pressed -> reset")
			Combat.reset_scores()
			for p in players:
				p.respawn(spawn_points[p.slot - 1])

# === Input map ===

func _setup_input_map() -> void:
	# Register both keycode AND physical_keycode for max compatibility across
	# keyboard layouts and Godot's matching paths.
	_add_action("p1_left", KEY_A)
	_add_action("p1_right", KEY_D)
	_add_action("p1_jump", KEY_W)
	_add_action("p1_throw", KEY_S)
	_add_action("p2_left", KEY_LEFT)
	_add_action("p2_right", KEY_RIGHT)
	_add_action("p2_jump", KEY_UP)
	_add_action("p2_throw", KEY_DOWN)
	print("[INPUT] Registered actions: ", InputMap.get_actions())
	for action in ["p1_left", "p1_right", "p1_jump", "p1_throw",
			"p2_left", "p2_right", "p2_jump", "p2_throw"]:
		var events = InputMap.action_get_events(action)
		print("[INPUT]   ", action, " -> events: ", events.size())

func _add_action(action_name: String, key: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	# Clear any prior events so re-runs in the editor don't accumulate
	for prev_event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, prev_event)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	InputMap.action_add_event(action_name, ev)

# === Map geometry ===

func _build_map() -> void:
	# Floor (solid)
	_make_wall(Vector2(MAP_W / 2.0, FLOOR_Y + WALL_THICK / 2.0),
		Vector2(MAP_W, WALL_THICK), Color(0.3, 0.3, 0.35))
	# Left wall
	_make_wall(Vector2(WALL_THICK / 2.0, MAP_H / 2.0),
		Vector2(WALL_THICK, MAP_H), Color(0.3, 0.3, 0.35))
	# Right wall
	_make_wall(Vector2(MAP_W - WALL_THICK / 2.0, MAP_H / 2.0),
		Vector2(WALL_THICK, MAP_H), Color(0.3, 0.3, 0.35))
	# Ceiling
	_make_wall(Vector2(MAP_W / 2.0, WALL_THICK / 2.0),
		Vector2(MAP_W, WALL_THICK), Color(0.3, 0.3, 0.35))

func _make_wall(center: Vector2, size: Vector2, color: Color) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	var vis: ColorRect = ColorRect.new()
	vis.size = size
	vis.position = -size / 2.0
	vis.color = color
	body.add_child(vis)
	add_child(body)

# === UI ===

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)

	score_label = Label.new()
	score_label.position = Vector2(MAP_W / 2.0 - 120.0, 8.0)
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.custom_minimum_size = Vector2(240.0, 0.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(score_label)

	winner_label = Label.new()
	winner_label.position = Vector2(MAP_W / 2.0 - 200.0, 60.0)
	winner_label.custom_minimum_size = Vector2(400.0, 0.0)
	winner_label.add_theme_font_size_override("font_size", 22)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	winner_label.text = ""
	canvas.add_child(winner_label)

	# Diagnostic overlay (top-right): frame counter, live input state, last key
	diag_label = Label.new()
	diag_label.position = Vector2(10.0, MAP_H - 30.0)
	diag_label.add_theme_font_size_override("font_size", 14)
	diag_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	diag_label.text = "(starting...)"
	canvas.add_child(diag_label)

	var TuningScript: Script = load("res://tuning_panel.gd")
	var tp = VBoxContainer.new()
	tp.set_script(TuningScript)
	tp.position = Vector2(10.0, 100.0)
	# Don't grab focus from gameplay
	tp.focus_mode = Control.FOCUS_NONE
	canvas.add_child(tp)

# === Players ===

func _spawn_players() -> void:
	var PlayerScript: Script = load("res://player.gd")
	if PlayerScript == null:
		push_error("[MAIN] Failed to load player.gd!")
		return
	for slot in [1, 2]:
		var p = CharacterBody2D.new()
		p.set_script(PlayerScript)
		p.slot = slot
		p.spawn_pos = spawn_points[slot - 1]
		p.facing = 1 if slot == 1 else -1
		p.position = spawn_points[slot - 1]

		# Player collision shape
		var col: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(PLAYER_W, PLAYER_H)
		col.shape = rect
		p.add_child(col)

		# Visual ColorRect
		var vis: ColorRect = ColorRect.new()
		vis.name = "Visual"
		vis.size = Vector2(PLAYER_W, PLAYER_H)
		vis.position = Vector2(-PLAYER_W / 2.0, -PLAYER_H / 2.0)
		vis.color = Color(0.85, 0.25, 0.25) if slot == 1 else Color(0.25, 0.45, 0.95)
		# Don't let this Control grab mouse events from the game
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(vis)

		# Stash label above head
		var lbl: Label = Label.new()
		lbl.name = "StashLabel"
		lbl.position = Vector2(-6.0, -PLAYER_H / 2.0 - 22.0)
		lbl.text = "3"
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(lbl)

		add_child(p)
		players.append(p)
		print("[MAIN] Spawned player slot=", slot, " at ", p.position)

func _update_score(_unused: Variant = null) -> void:
	if score_label == null:
		return
	score_label.text = "P1: %d  -  P2: %d" % [Combat.scores.get(1, 0), Combat.scores.get(2, 0)]
	for slot in [1, 2]:
		if Combat.scores.get(slot, 0) >= 5:
			winner_label.text = "P%d wins! (Press R to reset)" % slot
			return
	winner_label.text = ""

func _on_respawn(slot: int) -> void:
	for p in players:
		if p.slot == slot:
			p.respawn(spawn_points[slot - 1])
			break
