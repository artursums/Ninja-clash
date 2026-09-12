extends SceneTree

const Arena := preload("res://arena_rules.gd")
const TUNING := preload("res://player_tuning.tres")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var game: Node = load("res://Main.tscn").instantiate()
	root.add_child(game)
	var state: Node = root.get_node("GameState")
	var maps: Node = root.get_node("Maps")
	state.game_mode = state.Mode.FFA
	for index in maps.count():
		state.selected_map_index = index
		state.start_new_match()
		game._in_countdown = false
		var data: Dictionary = maps.get_map(index)
		check(game.players.size() == 4, "FFA has four fighters")
		for slot in 4:
			check(game.players[slot].position.is_equal_approx(data.spawn_points[slot]), "FFA uses this arena's authored spawn")
			game.players[slot].set_physics_process(false)
			game.players[slot].collision_layer = 0
		var terrain: Node2D
		for node in game.current_map_nodes:
			if node.get_script() == preload("res://arena_terrain.gd"):
				terrain = node
		check(terrain != null, "Arena has a shared terrain renderer")
		check(terrain.walls == data.walls, "Rendered terrain uses the collision geometry")
		for tile: Rect2 in terrain._tiles:
			check(terrain._solid(tile.get_center()), "Terrain tiles remain within solids")
		for node in game.current_map_nodes:
			if node.get_script() == preload("res://arena_ambience.gd"):
				check(node._lamps.size() >= 4, "Every arena retains its lamps and glows")
				check(node._lamps.size() == data.lamp_anchors.size(), "All authored fixtures are rendered")
				for lamp_index in node._lamps.size():
					var base: Vector2 = (node._lamps[lamp_index] + Vector2(0, 8)) * node.scale
					check(base.is_equal_approx(data.lamp_anchors[lamp_index]), "Scaled lamps stay anchored to arena geometry")
				check(node.get_child_count() == 1, "Atmosphere uses two drawing nodes")
				check(node._points.size() <= node.MAX_PARTICLES, "Particles stay bounded")
				if data.ambience == "tokyo":
					check(node._cars.size() == 24, "Tokyo retains six populated traffic lanes")
					var first: Vector2 = node._car_position(node._cars[0])
					node._elapsed += 1
					check(first != node._car_position(node._cars[0]), "Flying cars move through the sky")
				node.hide()
				var elapsed: float = node._elapsed
				node._process(1.0)
				check(node._elapsed == elapsed, "Hidden atmosphere stops updating")
				node.show()
		await physics_frame
		await process_frame
		await verify_jump_routes(game, data)
	# Both projectiles and fighters must survive travelling beyond the former viewport.
	state.current_state = state.State.ROUND
	var fighter: Node2D = game.players[0]
	fighter.position = Arena.SIZE - Vector2(40, 40)
	fighter._check_screen_wrap()
	check(fighter.position == Arena.SIZE - Vector2(40, 40), "Fighter can use expanded world")
	fighter.position = Vector2(Arena.WIDTH + 25, 220)
	fighter._check_screen_wrap()
	check(fighter.position.is_equal_approx(Vector2(25, 220)), "Fighter wraps at new right edge")
	var star: Node = load("res://shuriken.gd").new()
	star.thrower_slot = 1
	game.arena_root.add_child(star)
	star.set_physics_process(false)
	star.position = Arena.SIZE - Vector2(40, 40)
	star._physics_process(0.0)
	check(star.position.is_equal_approx(Arena.SIZE - Vector2(40, 40)), "Shuriken can use expanded world")
	star.position = Vector2(Arena.WIDTH + 20, 220)
	star._pos_history = [Vector2(Arena.WIDTH + 10, 220)]
	star._physics_process(0.0)
	check(star.position.is_equal_approx(Vector2(20, 220)), "Shuriken uses new wrap bounds")
	check(star._pos_history.size() <= 1, "Wrap clears projectile trail")
	var wave: Node = load("res://blade_wave.gd").new()
	wave.position = Arena.SIZE - Vector2(40, 40)
	check(not wave._offscreen(), "Blade wave survives in expanded world")
	wave.position.x = Arena.WIDTH + 50
	check(wave._offscreen(), "Blade wave expires beyond new boundary")
	wave.free()
	state.change_state(state.State.TITLE)
	game.queue_free()
	await process_frame
	print("Arena integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_jump_routes(game: Node, data: Dictionary) -> void:
	var bodies: Array = []
	for node in game.current_map_nodes:
		if node.is_in_group("crumble_platforms"):
			node.collision_layer = 0
		elif node is StaticBody2D:
			node.set_meta("surface_index", bodies.size())
			bodies.append(node)
	var probe := CharacterBody2D.new()
	probe.collision_layer = 0
	probe.collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(20, 32)
	probe.add_child(shape)
	game.arena_root.add_child(probe)
	await physics_frame
	await process_frame
	var graph: Array = []
	for source in data.walls.size():
		var wall: Dictionary = data.walls[source]
		var rect := Rect2(wall.center - wall.size * 0.5, wall.size)
		var targets: Array = []
		for x in range(int(rect.position.x) + 12, int(rect.end.x) - 10, 16):
			var origin := Vector2(x, rect.position.y - 16.1)
			var clear := true
			for other in data.walls:
				if Rect2(other.center - other.size * 0.5, other.size).intersects(Rect2(origin - Vector2(10, 16), Vector2(20, 32))):
					clear = false
			if not clear:
				continue
			for direction in [-1, 1]:
				for turn_frame in [-1, 12, 24, 36, 48, 60]:
					var target := jump_landing(probe, origin, direction, turn_frame)
					if target >= 0 and not targets.has(target):
						targets.append(target)
				var drop_target := jump_landing(probe, origin, direction, -1, false)
				if drop_target >= 0 and not targets.has(drop_target):
					targets.append(drop_target)
		graph.append(targets)
	for start in data.walls.size():
		if not data.walls[start].bot_perch:
			continue
		var reached: Array = [start]
		var cursor := 0
		while cursor < reached.size():
			for next in graph[reached[cursor]]:
				if not reached.has(next):
					reached.append(next)
			cursor += 1
		for target in data.walls.size():
			if data.walls[target].bot_perch:
				check(reached.has(target), "%s route %d -> %d is connected by jumps and drops" % [data.name, start, target])
	probe.queue_free()
	await process_frame

# Use the real physics world's rectangle collisions and the production jump/gravity values.
# No wall jumps, dashes, or screen wrapping are needed to connect the primary routes.
func jump_landing(probe: CharacterBody2D, origin: Vector2, direction: int, turn_frame: int, jump: bool = true) -> int:
	probe.position = origin
	var vertical: float = -TUNING.jump_strength if jump else 0.0
	for frame in 72:
		var horizontal: float = TUNING.max_hspeed * direction
		if turn_frame >= 0 and frame >= turn_frame:
			horizontal *= -1
		vertical = minf(vertical + TUNING.gravity / 60.0, TUNING.terminal_fall_speed)
		var motion := Vector2(horizontal, vertical) / 60.0
		for slide in 3:
			var collision := probe.move_and_collide(motion)
			if collision == null:
				break
			var normal := collision.get_normal()
			if normal.y < -0.7:
				if jump or absf(probe.position.y - origin.y) > 1.0:
					return collision.get_collider().get_meta("surface_index", -1)
				vertical = 0
			if normal.y > 0.7:
				vertical = 0
			motion = collision.get_remainder().slide(normal)
		if probe.position.y > Arena.HEIGHT + 32:
			break
	return -1
