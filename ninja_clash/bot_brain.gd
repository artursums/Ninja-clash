extends RefCounted

const Logic := preload("res://bot_logic.gd")
const Navigation := preload("res://bot_navigation.gd")
enum Tactic { OBSERVE, REPOSITION, PRESSURE, RETREAT, SCAVENGE, RECOVER }

var rng := RandomNumberGenerator.new()
var navigation: RefCounted
var tactic := Tactic.OBSERVE
var goal := Vector2.ZERO
var target_id := 0
var remembered_position := Vector2.ZERO
var remembered_velocity := Vector2.ZERO
var next_sense := 0.0
var next_plan := 0.0
var target_lock_until := 0.0
var route: Array = []
var traversal: Dictionary = {}
var traversal_started := -1.0
var failed_links: Dictionary = {}
var next_throw := 0.0
var aim_release := 0.0
var aim := Vector2.ZERO
var next_strike := 0.0
var strike_ready := 0.0
var next_jump := 0.0
var next_dash := 0.0
var recovery_until := 0.0
var guard_until := 0.0
var guard_facing := 1
var threats: Dictionary = {}
var melee_seen := -1.0
var melee_stamp := -1.0
var melee_read := false
var last_position := Vector2.ZERO
var progress_time := 0.0
var last_attack := 0.0
var map_index := -1
var _level := 0
var _tuning: Resource

func _init() -> void:
	rng.randomize()

func reset() -> void:
	goal = Vector2.ZERO
	remembered_position = Vector2.ZERO
	remembered_velocity = Vector2.ZERO
	last_position = Vector2.ZERO
	aim = Vector2.ZERO
	target_id = 0
	next_sense = 0
	next_plan = 0
	target_lock_until = 0
	route.clear()
	traversal.clear()
	traversal_started = -1
	failed_links.clear()
	threats.clear()
	next_throw = 0
	aim_release = 0
	next_strike = 0
	strike_ready = 0
	next_jump = 0
	next_dash = 0
	recovery_until = 0
	guard_until = 0
	melee_stamp = -1
	melee_seen = -1
	progress_time = 0
	last_attack = 0
	tactic = Tactic.OBSERVE

func prepare(actor: Node) -> void:
	if navigation == null or map_index != actor.get_node("/root/GameState").selected_map_index:
		map_index = actor.get_node("/root/GameState").selected_map_index
		navigation = Navigation.new()
		navigation.configure(actor.get_node("/root/Maps").get_map(map_index), actor.tuning)
		reset()

func tick(actor: CharacterBody2D, now: float) -> void:
	actor._bot_held.clear()
	actor._bot_pressed.clear()
	_level = clampi(actor.bot_difficulty - 1, 0, 2)
	_tuning = actor.bot_tuning
	prepare(actor)
	navigation.occluders.clear()
	for platform in actor.get_tree().get_nodes_in_group("crumble_platforms"):
		if platform.collision_layer != 0 and not platform.is_queued_for_deletion():
			navigation.occluders.append(platform.bounds)
	var enemy: Node = instance_from_id(target_id) if target_id else null
	if not is_instance_valid(enemy) or not enemy.alive or now >= next_sense:
		enemy = _sense(actor, enemy, now)
	if enemy == null:
		return
	if last_attack == 0:
		last_attack = now
	if actor.is_sliding or actor.is_swinging:
		aim_release = 0
		return
	if _defend(actor, enemy, now):
		aim_release = 0
		return
	var standing: int = navigation.support(actor.global_position)
	if now >= next_plan and traversal.is_empty():
		_plan(actor, enemy, standing, now)
	var move := _navigate(actor, standing, now)
	if traversal.is_empty() and _attack(actor, enemy, now):
		move = 0
	if move < 0:
		actor._bot_held[actor.input_left] = true
	elif move > 0:
		actor._bot_held[actor.input_right] = true
	elif absf(remembered_position.x - actor.global_position.x) > 8:
		actor.facing = int(signf(remembered_position.x - actor.global_position.x))
	if actor.global_position.distance_to(last_position) > 10 or move == 0:
		last_position = actor.global_position
		progress_time = now
	elif now - progress_time > 0.9:
		_abandon_traversal(now)
		next_plan = 0
		progress_time = now
		if actor.is_on_wall() and not actor.is_on_floor() and now >= next_jump:
			actor._bot_pressed[actor.input_jump] = true
			next_jump = now + 0.45

func _sense(actor: Node, enemy: Node, now: float) -> Node:
	if not is_instance_valid(enemy) or not enemy.alive or now >= target_lock_until:
		var best := INF
		var chosen: Node = null
		for candidate in actor.get_tree().get_nodes_in_group("players"):
			if candidate == actor or not candidate.alive:
				continue
			var score: float = actor.global_position.distance_to(candidate.global_position)
			if candidate == enemy:
				score -= 100
			if score < best:
				best = score
				chosen = candidate
		if chosen != enemy:
			next_plan = 0
			aim_release = 0
			melee_stamp = -1
		enemy = chosen
		target_id = enemy.get_instance_id() if enemy != null else 0
		target_lock_until = now + rng.randf_range(1.4, 2.2)
	if enemy != null:
		remembered_position = enemy.global_position
		remembered_velocity = enemy.velocity
	next_sense = now + _tuning.perception_s[_level] * rng.randf_range(0.9, 1.15)
	return enemy

func _plan(actor: Node, enemy: Node, standing: int, now: float) -> void:
	next_plan = now + rng.randf_range(_tuning.plan_min_s[_level], _tuning.plan_max_s[_level])
	if standing < 0:
		return
	for key in failed_links.keys():
		if failed_links[key] <= now:
			failed_links.erase(key)
	var foe_ledge: int = navigation.nearest_ledge(remembered_position)
	var distance: float = actor.global_position.distance_to(remembered_position)
	var same_floor := standing == foe_ledge and absf(actor.global_position.y - remembered_position.y) < 38
	var visible_foe: bool = navigation.clear_line(actor.global_position, remembered_position, 5)
	var blade := _pickup(actor, standing)
	var urgent_pickup: bool = actor.stash == 0 or actor.stash < 2 and distance > 110
	if blade != null and urgent_pickup:
		tactic = Tactic.SCAVENGE
		_set_goal(actor, standing, blade.global_position)
		return
	if now < recovery_until:
		tactic = Tactic.RECOVER
	elif same_floor and distance < _tuning.near_range[_level] and (actor.stash > 0 and (actor.hp <= 2 or actor.katana_charges == 0) or now < next_strike):
		tactic = Tactic.RETREAT
	elif actor.stash == 0 or now - last_attack > 5.5 or same_floor and enemy.stash == 0 and rng.randf() < _tuning.pressure_chance[_level]:
		tactic = Tactic.PRESSURE
	elif same_floor and visible_foe and distance >= _tuning.near_range[_level] and distance <= _tuning.far_range[_level] and rng.randf() < 0.55:
		tactic = Tactic.OBSERVE
	else:
		tactic = Tactic.REPOSITION
	if tactic == Tactic.OBSERVE:
		goal = actor.global_position
		route.clear()
		return
	if tactic == Tactic.RECOVER and same_floor:
		var away := signf(actor.global_position.x - remembered_position.x)
		var floor_rect: Rect2 = navigation.ledges[standing]
		goal = Vector2(clampf(actor.global_position.x + away * 55, floor_rect.position.x + 12, floor_rect.end.x - 12), actor.global_position.y)
		route.clear()
		next_plan = recovery_until
		return
	if tactic == Tactic.PRESSURE:
		var side := signf(actor.global_position.x - remembered_position.x)
		if side == 0:
			side = 1
		_set_goal(actor, standing, remembered_position + Vector2(side * 28, 0))
		return
	var ideal: float = _tuning.far_range[_level] * rng.randf_range(0.65, 0.9)
	var best_score := INF
	var best_point: Vector2 = actor.global_position
	for i in navigation.ledges.size():
		var path: Array = navigation.route(standing, i, failed_links.keys())
		if i != standing and path.is_empty():
			continue
		var ledge: Rect2 = navigation.ledges[i]
		for x in [ledge.position.x + 16, ledge.get_center().x, ledge.end.x - 16]:
			var point := Vector2(x, ledge.position.y - 16)
			var separation := point.distance_to(remembered_position)
			var line: bool = navigation.clear_line(point, remembered_position, 5)
			var score := absf(separation - ideal) + path.size() * 38.0
			score += actor.global_position.distance_to(point) * 0.12
			if not line:
				score += 160 if actor.stash > 0 else 0
			if separation < _tuning.near_range[_level]:
				score += 150
			if tactic in [Tactic.RETREAT, Tactic.RECOVER]:
				score -= minf(separation, 260) * 0.5
				if not line:
					score -= 100
			if point.distance_to(actor.global_position) < 28 and not visible_foe:
				score += 180
			if score < best_score:
				best_score = score
				best_point = point
	_set_goal(actor, standing, best_point)

func _set_goal(actor: Node, standing: int, point: Vector2) -> void:
	var destination: int = navigation.nearest_ledge(point)
	if destination < 0:
		return
	var ledge: Rect2 = navigation.ledges[destination]
	goal = Vector2(clampf(point.x, ledge.position.x + 12, ledge.end.x - 12), ledge.position.y - 16)
	route = navigation.route(standing, destination, failed_links.keys())
	if destination != standing and route.is_empty():
		# Pick a reachable intermediate perch instead of walking into an impossible route.
		var best := INF
		for link in navigation.edges[standing]:
			if failed_links.has(link.from * 1000 + link.to):
				continue
			var score: float = link.landing.distance_to(goal)
			if score < best:
				best = score
				route = [link]
		if route.is_empty():
			goal = actor.global_position

func _pickup(actor: Node, standing: int) -> Node:
	var best: Node = null
	var score := INF
	for blade in actor.get_tree().get_nodes_in_group("shurikens"):
		if not blade.stuck or blade.consumed:
			continue
		var d: float = actor.global_position.distance_to(blade.global_position)
		if d > _tuning.pickup_range[_level] and actor.katana_charges > 0:
			continue
		var ledge: int = navigation.nearest_ledge(blade.global_position)
		if ledge < 0 or absf(navigation.ledges[ledge].position.y - blade.global_position.y) > 42:
			continue
		var path: Array = navigation.route(standing, ledge, failed_links.keys())
		if standing != ledge and path.is_empty():
			continue
		d += path.size() * 45
		if d < score:
			score = d
			best = blade
	return best

func _navigate(actor: Node, standing: int, now: float) -> int:
	if not traversal.is_empty():
		if traversal_started >= 0 and actor.is_on_floor() and standing == traversal.to:
			traversal.clear()
			traversal_started = -1
		elif traversal_started >= 0 and now - traversal_started > traversal.duration + 0.8:
			_abandon_traversal(now)
			next_plan = 0
	if traversal.is_empty() and not route.is_empty() and actor.is_on_floor():
		traversal = route.pop_front().duplicate()
		traversal_started = -1
		aim_release = 0
		strike_ready = 0
	if not traversal.is_empty():
		if traversal_started < 0:
			var dx: float = traversal.launch.x - actor.global_position.x
			if absf(dx) > 3:
				return int(signf(dx))
			if traversal.kind == "boost" and not actor.slide_charged:
				return 0
			if not actor.is_on_floor() or now < next_jump:
				return 0
			traversal_started = now
			if traversal.kind != "drop":
				actor._bot_pressed[actor.input_jump] = true
				next_jump = now + 0.4
		var direction: int = navigation.steering(traversal, actor.global_position)
		if traversal.kind == "boost" and now - traversal_started >= 14.0 / 60.0 and not traversal.get("boosted", false):
			traversal = traversal.duplicate()
			traversal.boosted = true
			if actor.slide_charged:
				actor._bot_pressed[actor.input_slide] = true
				if traversal.boost_up:
					actor._bot_held[actor.input_aim_up] = true
		return direction
	if not actor.is_on_floor():
		if standing < 0:
			var landing := _air_landing(actor.global_position)
			return 0 if absf(landing.x - actor.global_position.x) < 6 else int(signf(landing.x - actor.global_position.x))
		return 0
	var local_x := goal.x
	if standing >= 0:
		var floor_rect: Rect2 = navigation.ledges[standing]
		local_x = clampf(local_x, floor_rect.position.x + 12, floor_rect.end.x - 12)
	var offset: float = local_x - actor.global_position.x
	return 0 if absf(offset) < 5 else int(signf(offset))

func _air_landing(point: Vector2) -> Vector2:
	var best := INF
	var result := point
	for ledge: Rect2 in navigation.ledges:
		if ledge.position.y < point.y + 16:
			continue
		var candidate := Vector2(clampf(point.x, ledge.position.x + 12, ledge.end.x - 12), ledge.position.y - 16)
		var cost := absf(candidate.x - point.x) * 2 + candidate.y - point.y
		if cost < best:
			best = cost
			result = candidate
	return result

func _abandon_traversal(now: float) -> void:
	if not traversal.is_empty():
		failed_links[traversal.from * 1000 + traversal.to] = now + 4.0
	traversal.clear()
	traversal_started = -1
	route.clear()

func _attack(actor: Node, enemy: Node, now: float) -> bool:
	var offset: Vector2 = remembered_position - actor.global_position
	var clear: bool = navigation.clear_line(actor.global_position, remembered_position, 5)
	if not clear:
		aim_release = 0
		strike_ready = 0
		return false
	if absf(offset.x) <= 38 and absf(offset.y) < 24 and actor.katana_charges > 0:
		actor.facing = 1 if offset.x >= 0 else -1
		if strike_ready == 0:
			strike_ready = now + _tuning.melee_windup[_level] * rng.randf_range(0.85, 1.25)
		if now >= strike_ready and now >= next_strike and now >= actor.katana_cooldown_until:
			actor._bot_pressed[actor.input_katana] = true
			next_strike = now + _tuning.melee_recovery[_level] * rng.randf_range(0.9, 1.25)
			strike_ready = 0
			last_attack = now
			recovery_until = next_strike
			next_plan = 0
			return true
		return now >= next_strike
	strike_ready = 0
	if actor.stash <= 0:
		if actor.katana_charges == 0 and absf(offset.x) < 30 and absf(offset.y) < 40 and actor.is_on_floor() and now >= next_jump and actor._bot_should_stomp():
			actor._bot_pressed[actor.input_jump] = true
			next_jump = now + 0.7
		return false
	if offset.length() > 380 or offset.length() < 50 or now < recovery_until:
		aim_release = 0
		return false
	if now < next_throw:
		return false
	if aim_release == 0:
		var lead: float = minf(offset.length() / 500.0, 0.3)
		var error: float = _tuning.aim_error_px[_level]
		aim = Logic.aim_octant(offset + remembered_velocity * lead + Vector2(rng.randf_range(-error, error), rng.randf_range(-error, error)))
		aim_release = now + _tuning.aim_windup_s[_level] * rng.randf_range(0.85, 1.3)
		return false
	if now >= aim_release:
		# The direction stays locked during the tell; a sudden player dodge can defeat it.
		var origin: Vector2 = actor.global_position + aim.normalized() * 22
		if navigation.clear_line(actor.global_position, origin + aim.normalized() * 44, 5):
			actor._bot_throw_dir = aim
			actor._bot_pressed[actor.input_throw] = true
			last_attack = now
			next_throw = now + _tuning.throw_cd[_level] * rng.randf_range(0.85, 1.3)
		else:
			next_plan = 0
			next_throw = now + 0.3
		aim_release = 0
	return false

func _defend(actor: Node, enemy: Node, now: float) -> bool:
	if now < guard_until and actor.guard_meter > 0 and now >= actor.guard_cooldown_until:
		actor.facing = guard_facing
		actor._bot_held[actor.input_defend] = true
		return true
	var urgent: Node = null
	var impact := INF
	var present: Dictionary = {}
	var projectiles: Array = actor.get_tree().get_nodes_in_group("shurikens") + actor.get_tree().get_nodes_in_group("blade_waves")
	for blade in projectiles:
		var wave: bool = blade.is_in_group("blade_waves")
		if blade.thrower_slot == actor.slot:
			continue
		if wave and blade._dead or not wave and (blade.stuck or blade.consumed or blade.ricocheted):
			continue
		var offset: Vector2 = blade.global_position - actor.global_position
		if offset.length() > _tuning.dodge_range[_level]:
			continue
		var time: float = Logic.impact_time(offset, blade.velocity_v * (1.0 if wave else blade.FLIGHT_TIME_SCALE) - actor.velocity)
		if time > 0.85 or not navigation.clear_line(blade.global_position, actor.global_position, 2):
			continue
		var id: int = blade.get_instance_id()
		present[id] = true
		if not threats.has(id):
			threats[id] = {"seen": now, "roll": rng.randf(), "answered": false, "wave": wave}
		if time < impact and not threats[id].answered:
			impact = time
			urgent = blade
	for id in threats.keys():
		if not present.has(id) and now - threats[id].seen > 1.5:
			threats.erase(id)
	if urgent != null:
		var read: Dictionary = threats[urgent.get_instance_id()]
		if now - read.seen >= _tuning.reaction_s[_level] and impact <= 0.32:
			read.answered = true
			var offset: Vector2 = urgent.global_position - actor.global_position
			guard_facing = 1 if offset.x >= 0 else -1
			if not read.wave and read.roll < _tuning.deflect_chance[_level] and absf(offset.x) < 55 and absf(offset.y) < 22 and actor.katana_charges > 0 and now >= actor.katana_cooldown_until:
				actor.facing = guard_facing
				actor._bot_pressed[actor.input_katana] = true
				return true
			var escape := _dodge_direction(actor)
			if read.roll < _tuning.dodge_chance[_level] and actor.slide_charged and now >= next_dash and escape != Vector2.ZERO:
				if escape.y < 0:
					actor._bot_held[actor.input_aim_up] = true
				if escape.x != 0:
					actor._bot_held[actor.input_left if escape.x < 0 else actor.input_right] = true
				actor._bot_pressed[actor.input_dodge] = true
				next_dash = now + 0.65
				_abandon_traversal(now)
				next_plan = 0
				return true
			if read.roll < _tuning.guard_chance[_level] and actor.guard_meter >= 0.6 and now >= actor.guard_cooldown_until:
				guard_until = now + clampf(impact + 0.15, 0.22, 0.5)
				actor.facing = guard_facing
				actor._bot_held[actor.input_defend] = true
				return true
	var melee_offset: Vector2 = enemy.global_position - actor.global_position
	if enemy.is_swinging and melee_offset.length() < 120:
		if melee_stamp != enemy.swing_start_t:
			melee_stamp = enemy.swing_start_t
			melee_seen = now
			melee_read = rng.randf() < _tuning.guard_chance[_level]
		if melee_read and now - melee_seen >= _tuning.reaction_s[_level] and absf(melee_offset.x) < 45 and absf(melee_offset.y) < 25 and navigation.clear_line(actor.global_position, enemy.global_position):
			melee_read = false
			if actor.guard_meter >= 0.6 and now >= actor.guard_cooldown_until:
				guard_facing = 1 if melee_offset.x >= 0 else -1
				guard_until = now + 0.28
				actor.facing = guard_facing
				actor._bot_held[actor.input_defend] = true
				return true
	return false

func _dodge_direction(actor: Node) -> Vector2:
	var point: Vector2 = actor.global_position
	if actor.is_on_floor() and navigation.clear_line(point, point + Vector2(0, -75), 10):
		return Vector2.UP
	var preferred := int(signf(goal.x - point.x))
	if preferred == 0:
		preferred = actor.facing
	for direction in [preferred, -preferred]:
		var destination := point + Vector2(direction * 82, 0)
		if not navigation.clear_line(point, destination, 10):
			continue
		if actor.is_on_floor() and navigation.support(destination) < 0:
			continue
		if not actor.is_on_floor() and _air_landing(destination).is_equal_approx(destination):
			continue
		return Vector2(direction, 0)
	return Vector2.ZERO
