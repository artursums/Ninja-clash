extends SceneTree

const Navigation := preload("res://bot_navigation.gd")
const Brain := preload("res://bot_brain.gd")
const TUNING := preload("res://player_tuning.tres")
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	var state: Node = root.get_node("GameState")
	var maps: Node = root.get_node("Maps")
	state.game_mode = state.Mode.HUMAN_VS_AI
	for index in maps.count():
		state.selected_map_index = index
		state.start_new_match()
		game._in_countdown = false
		for fighter in game.players:
			fighter.set_physics_process(false)
			fighter.collision_layer = 0
		for platform in get_nodes_in_group("crumble_platforms"):
			platform.collision_layer = 0
		await physics_frame
		await process_frame
		var nav := Navigation.new()
		var data: Dictionary = maps.get_map(index)
		nav.configure(data, TUNING)
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
		for source in nav.ledges.size():
			for target in nav.ledges.size():
				check(source == target or not nav.route(source, target).is_empty(), "%s has a route %d -> %d" % [data.name, source, target])
			for link in nav.edges[source]:
				var landed := actual_landing(probe, nav, link)
				check(landed == link.to, "%s %s route %d -> %d lands on %d in real physics" % [data.name, link.kind, source, link.to, landed])
		probe.queue_free()
		print("Verified navigation: ", data.name)
		await process_frame
	verify_decisions()
	state.change_state(state.State.TITLE)
	game.queue_free()
	root.get_node("Audio").stop_music()
	await process_frame
	print("Bot integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func actual_landing(probe: CharacterBody2D, nav: RefCounted, link: Dictionary) -> int:
	probe.position = link.launch
	var vy := 0.0 if link.kind == "drop" else -TUNING.jump_strength
	var dash := Vector2.ZERO
	for frame in 120:
		var direction: int = nav.steering(link, probe.position)
		if frame == 14:
			dash = Vector2(direction, -1 if link.boost_up else 0).normalized() * TUNING.slide_speed
		var vx := direction * TUNING.max_hspeed
		if link.kind == "boost" and frame >= 14 and frame < 26:
			vx = dash.x
			vy = maxf(dash.y, -TUNING.slide_speed / sqrt(2.0))
		else:
			vy = minf(vy + TUNING.gravity / 60, TUNING.terminal_fall_speed)
		var motion := Vector2(vx, vy) / 60
		for slide in 3:
			var hit := probe.move_and_collide(motion)
			if hit == null:
				break
			var normal := hit.get_normal()
			if normal.y < -0.7:
				var landed: int = nav.support(probe.position)
				if landed == link.to or landed != link.from or link.kind != "drop":
					return landed
				vy = 0
			elif normal.y > 0.7:
				vy = 0
			motion = hit.get_remainder().slide(normal)
	return -1

func verify_decisions() -> void:
	var actor: Node = game.players[1]
	var enemy: Node = game.players[0]
	actor.bot_tuning = load("res://bot_tuning.tres")
	actor.bot_difficulty = 2
	var brain := Brain.new()
	actor._bot_brain = brain
	actor.position = Vector2(352, 149)
	enemy.position = Vector2(350, 281)
	actor.stash = 3
	actor.katana_charges = 3
	brain.rng.seed = 42
	brain.tick(actor, 10)
	var goal := brain.goal
	var deadline := brain.next_plan
	for step in 5:
		enemy.position.x += 8
		brain.tick(actor, 10.01 + step * 0.01)
		check(brain.goal == goal and brain.next_plan == deadline, "Moving below the CPU does not drag its committed destination")
	check(not actor._bot_pressed.has(actor.input_throw), "CPU does not throw through the platform below it")
	brain.next_throw = 123
	brain.guard_until = 234
	brain.threats[17] = {"seen": 10, "roll": 0, "answered": true}
	actor.respawn(actor.position)
	check(brain.next_throw == 0 and brain.guard_until == 0 and brain.threats.is_empty() and brain.route.is_empty() and brain.target_id == 0, "Respawn clears combat decisions and target memory")
	brain.aim_release = 600
	actor.is_sliding = true
	brain.tick(actor, 500)
	check(brain.aim_release == 0, "A dash cancels a pending throw instead of releasing stale aim after traversal")
	actor.is_sliding = false
	verify_defence(actor, enemy, brain)

class Threat:
	extends Node2D
	const FLIGHT_TIME_SCALE := 0.4725
	var velocity_v := Vector2(-850, 0)
	var thrower_slot := 1
	var stuck := false
	var consumed := false
	var ricocheted := false
	var _dead := false

func verify_defence(actor: Node, enemy: Node, brain: RefCounted) -> void:
	actor.position = Vector2(350, 281)
	enemy.position = Vector2(460, 281)
	actor.slide_charged = false
	actor.guard_meter = 4
	actor.guard_cooldown_until = 0
	var threat := Threat.new()
	game.arena_root.add_child(threat)
	threat.position = actor.position + Vector2(80, 0)
	threat.add_to_group("shurikens")
	var now := 500.0
	brain.reset()
	check(not brain._defend(actor, enemy, now), "A new projectile cannot trigger an instant defence")
	var read: Dictionary = brain.threats[threat.get_instance_id()]
	read.roll = 0.99
	check(not brain._defend(actor, enemy, now + 0.25), "A missed threat read remains a real mistake")
	for step in 10:
		check(not brain._defend(actor, enemy, now + 0.26 + step * 0.01), "Defence does not reroll a missed read every frame")
	brain.reset()
	brain._defend(actor, enemy, now)
	brain.threats[threat.get_instance_id()].roll = 0.0
	check(brain._defend(actor, enemy, now + 0.25), "A successful delayed read can guard when the dash is unavailable")
	threat.stuck = true
	check(brain._defend(actor, enemy, now + 0.3) and actor._bot_held.has(actor.input_defend), "Guard stays held instead of flickering as threats change")
	brain.reset()
	threat.stuck = false
	threat.remove_from_group("shurikens")
	threat.add_to_group("blade_waves")
	threat.velocity_v = Vector2(-340, 0)
	brain._defend(actor, enemy, now)
	brain.threats[threat.get_instance_id()].roll = 0.0
	actor._bot_pressed.clear()
	check(brain._defend(actor, enemy, now + 0.25) and not actor._bot_pressed.has(actor.input_katana), "Blade waves are guarded or dodged, never treated as parryable shurikens")
	threat.queue_free()
