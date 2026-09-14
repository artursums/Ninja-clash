extends SceneTree

var checks := 0
var failures := 0
var router: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func key(code: int, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	if code == KEY_SHIFT:
		event.location = KEY_LOCATION_LEFT
	return event

func stick(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = axis
	event.axis_value = value
	return event

func button(code: int, down: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = code
	event.pressed = down
	return event

func step(player: Node, event: InputEvent, action: String, held: bool) -> void:
	Input.parse_input_event(event.duplicate())
	Input.flush_buffered_events()
	router.capture()
	check(router.held(action) == held, "Device input maps to " + action)
	if held:
		check(router.pressed(action), "Device press edge reaches " + action)
	player._physics_process(1.0 / 60.0)

func double_direction(player: Node, down: InputEvent, up: InputEvent, action: String) -> void:
	player.respawn(Vector2(440, 200))
	for tap in 2:
		step(player, down, action, true)
		check(not player.is_sliding, "Direction tap %d does not dash: %s" % [tap + 1, action])
		check(player.slide_charged, "Direction input does not spend the dash charge")
		step(player, up, action, false)

func run() -> void:
	var game: Node = load("res://Main.tscn").instantiate()
	root.add_child(game)
	var state: Node = root.get_node("GameState")
	router = root.get_node("PlayerInput")
	game.set_process(false)
	for player in game.players:
		player.set_physics_process(false)
	await physics_frame
	await process_frame
	state.current_state = state.State.ROUND
	for child in game.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://input_bindings.gd":
			child._add_pad(2, 7)
	for player in game.players:
		player.collision_mask = 0
		player.collision_layer = 0
	var p1: Node = game.players[0]
	var p2: Node = game.players[1]
	for pair in [[KEY_LEFT, "left"], [KEY_RIGHT, "right"], [KEY_UP, "aim_up"], [KEY_DOWN, "aim_down"],
		[KEY_A, "left"], [KEY_D, "right"], [KEY_W, "aim_up"], [KEY_S, "aim_down"]]:
		double_direction(p1, key(pair[0], true), key(pair[0], false), "p1_" + pair[1])
	for pair in [[KEY_KP_4, "left"], [KEY_KP_6, "right"], [KEY_KP_8, "aim_up"], [KEY_KP_5, "aim_down"]]:
		double_direction(p2, key(pair[0], true), key(pair[0], false), "p2_" + pair[1])
	for pair in [[JOY_AXIS_LEFT_X, -1.0, "left"], [JOY_AXIS_LEFT_X, 1.0, "right"],
		[JOY_AXIS_LEFT_Y, -1.0, "aim_up"], [JOY_AXIS_LEFT_Y, 1.0, "aim_down"]]:
		double_direction(p2, stick(pair[0], pair[1]), stick(pair[0], 0.0), "p2_" + pair[2])
	for pair in [[JOY_BUTTON_DPAD_LEFT, "left"], [JOY_BUTTON_DPAD_RIGHT, "right"],
		[JOY_BUTTON_DPAD_UP, "aim_up"], [JOY_BUTTON_DPAD_DOWN, "aim_down"]]:
		double_direction(p2, button(pair[0], true), button(pair[0], false), "p2_" + pair[1])
	for request in [[p1, key(KEY_SHIFT, true), key(KEY_SHIFT, false), "p1_dodge"],
		[p2, key(KEY_KP_ADD, true), key(KEY_KP_ADD, false), "p2_dodge"],
		[p2, button(JOY_BUTTON_B, true), button(JOY_BUTTON_B, false), "p2_dodge"],
		[p2, stick(JOY_AXIS_TRIGGER_RIGHT, 1.0), stick(JOY_AXIS_TRIGGER_RIGHT, 0.0), "p2_slide"]]:
		request[0].respawn(Vector2(440, 200))
		step(request[0], request[1], request[3], true)
		check(request[0].is_sliding, "Dedicated dash input still starts a dash: " + request[3])
		step(request[0], request[2], request[3], false)
	game.queue_free()
	await process_frame
	print("Dash input integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
