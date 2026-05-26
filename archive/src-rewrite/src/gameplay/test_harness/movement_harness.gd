extends Node2D
## TEMPORARY Sprint 2 / T4 harness — makes the production Movement drivable so you can FEEL it
## (and run the social playtest on the real build). It exercises the whole Foundation stack end to
## end: GSM state machine → CouchInput join + layer switch → Map load → Character Controller +
## Movement. NOT shippable — this is replaced by the real boot flow once UI Flow / Round Flow exist.
##
## Controls: gamepad (press any button to join, then move/A=jump-or-dodge), OR keyboard fallback
## (WASD / arrows = move, Space = jump-or-dodge). Set as the project main scene for convenience.

var _gs: Node = null
var _ci: Node = null
var _arena: Node = null
var _map: MapResource = null
var _started: bool = false
var _label: Label = null


func _ready() -> void:
	_gs = get_node_or_null(^"/root/GameState")
	_ci = get_node_or_null(^"/root/CouchInput")
	if _gs == null or _ci == null:
		push_error("Harness: GameState / CouchInput autoloads missing.")
		return
	_ci.config.debug_keyboard_input = true   # enable the dev keyboard fallback for the harness

	_map = MapRegistry.get_map(&"flat_arena")
	if _map == null:
		push_error("Harness: flat_arena map not found.")
		return
	_arena = (load(_map.scene_path) as PackedScene).instantiate()
	add_child(_arena)

	# A menu state so a controller can join (join only happens in the menu input layer).
	_gs.request_transition(GameStateManager.State.MAIN_MENU)
	_build_label()


func _process(_delta: float) -> void:
	if not _started and _ci != null and _ci.active_slots().size() > 0:
		_start_match()


func _start_match() -> void:
	_started = true
	if _label != null:
		_label.text = "Slot joined — move + jump/dodge. (Esc to quit.)"
	_gs.request_transition(GameStateManager.State.MATCH_SETUP)
	_gs.request_transition(GameStateManager.State.IN_MATCH)   # CouchInput → gameplay layer

	var s: int = _ci.active_slots()[0]
	var body := PlayerCharacterBody.new()
	body.config = load("res://src/core/character_controller_config.tres")
	body.map = _map
	body.slot = s

	var movement := PlayerMovement.new()
	movement.cc = body
	movement.input_source = _ci
	movement.slot = s
	movement.config = load("res://src/gameplay/movement_config.tres")
	body.add_child(movement)

	# Placeholder visual: a rectangle the size of the hitbox.
	var vis := ColorRect.new()
	vis.color = Color(0.25, 0.9, 1.0)
	vis.size = Vector2(body.config.hitbox_width, body.config.hitbox_height)
	vis.position = Vector2(-body.config.hitbox_width * 0.5, -body.config.hitbox_height * 0.5)
	body.add_child(vis)

	_arena.add_child(body)
	body.global_position = _map.spawn_points[0]


func _build_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.text = "Press a button (gamepad) or any of WASD/Arrows/Space (keyboard) to join."
	_label.position = Vector2(8, 8)
	layer.add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
