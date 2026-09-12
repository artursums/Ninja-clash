extends RefCounted

const HALF := Vector2(10, 16)
const STEP := 1.0 / 60.0
static var _cache: Dictionary = {}

var ledges: Array = []
var solids: Array[Rect2] = []
var occluders: Array[Rect2] = []
var edges: Array = []
var speed := 158.4
var jump := 480.0
var gravity := 1400.0
var terminal := 320.0
var dash_speed := 400.0
var dash_duration := 0.2

func configure(data: Dictionary, tuning: Resource) -> void:
	ledges = data.bot_ledges
	for wall in data.walls:
		solids.append(Rect2(wall.center - wall.size * 0.5, wall.size))
	speed = tuning.max_hspeed
	jump = tuning.jump_strength
	gravity = tuning.gravity
	terminal = tuning.terminal_fall_speed
	dash_speed = tuning.slide_speed
	dash_duration = tuning.slide_duration_s
	var key := hash([solids, speed, jump, gravity, terminal, dash_speed, dash_duration])
	if _cache.has(key):
		edges = _cache[key]
		return
	for i in ledges.size():
		var outgoing: Array = []
		for j in ledges.size():
			if i == j:
				continue
			var link := _connect(i, j)
			if not link.is_empty():
				outgoing.append(link)
		edges.append(outgoing)
	_cache[key] = edges

func support(point: Vector2, tolerance: float = 7.0) -> int:
	for i in ledges.size():
		var ledge: Rect2 = ledges[i]
		if absf(point.y + HALF.y - ledge.position.y) <= tolerance and point.x > ledge.position.x - HALF.x + 0.1 and point.x < ledge.end.x + HALF.x - 0.1:
			return i
	return -1

func nearest_ledge(point: Vector2) -> int:
	var best := -1
	var distance := INF
	for i in ledges.size():
		var ledge: Rect2 = ledges[i]
		var landing := Vector2(clampf(point.x, ledge.position.x + 12, ledge.end.x - 12), ledge.position.y - HALF.y)
		var d := point.distance_to(landing)
		if d < distance:
			distance = d
			best = i
	return best

func route(from: int, destination: int, blocked: Array = []) -> Array:
	if from < 0 or destination < 0 or from == destination:
		return []
	var costs := {from: 0.0}
	var previous: Dictionary = {}
	var open: Array[int] = [from]
	while not open.is_empty():
		var current := open[0]
		for candidate in open:
			if costs[candidate] < costs[current]:
				current = candidate
		open.erase(current)
		if current == destination:
			var result: Array = []
			while current != from:
				var link: Dictionary = previous[current]
				result.push_front(link)
				current = link.from
			return result
		for link in edges[current]:
			if blocked.has(link.from * 1000 + link.to):
				continue
			var cost: float = costs[current] + link.cost
			if cost < costs.get(link.to, INF):
				costs[link.to] = cost
				previous[link.to] = link
				if not open.has(link.to):
					open.append(link.to)
	return []

func clear_line(from: Vector2, to: Vector2, padding: float = 0.0) -> bool:
	for solid: Rect2 in solids + occluders:
		var inflated := solid.grow(padding)
		if inflated.has_point(from) or inflated.has_point(to):
			return false
		var corners := [inflated.position, Vector2(inflated.end.x, inflated.position.y), inflated.end, Vector2(inflated.position.x, inflated.end.y)]
		for i in 4:
			if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true

func steering(link: Dictionary, point: Vector2) -> int:
	var target_x: float = link.landing.x
	if link.kind == "drop" and point.y - HALF.y < ledges[link.from].end.y + 1:
		target_x = link.exit_x
	return 0 if absf(target_x - point.x) < 3 else int(signf(target_x - point.x))

func _connect(from: int, to: int) -> Dictionary:
	var source: Rect2 = ledges[from]
	var target: Rect2 = ledges[to]
	var rise := source.position.y - target.position.y
	var gap := maxf(0, maxf(source.position.x - target.end.x, target.position.x - source.end.x))
	if rise > 154 or gap > 220 or rise < -360:
		return {}
	var launches := [source.position.x + 11, source.end.x - 11, clampf(target.get_center().x, source.position.x + 11, source.end.x - 11), clampf(target.position.x - 28, source.position.x + 11, source.end.x - 11), clampf(target.end.x + 28, source.position.x + 11, source.end.x - 11)]
	var landings := [clampf(source.get_center().x, target.position.x + 12, target.end.x - 12), target.position.x + 12, target.end.x - 12]
	var kinds := ["drop", "jump", "boost"] if rise < -8 else ["jump", "boost"]
	for kind in kinds:
		for x in launches:
			for target_x in landings:
				var link := {
					"from": from, "to": to, "kind": kind,
					"launch": Vector2(x, source.position.y - HALF.y - 0.1),
					"landing": Vector2(target_x, target.position.y - HALF.y),
					"exit_x": source.position.x - 14 if x < source.get_center().x else source.end.x + 14,
					"boost_up": rise > 30,
				}
				var duration := _simulate(link)
				if duration > 0:
					link.cost = duration + absf(x - source.get_center().x) / speed + (0.3 if kind == "boost" else 0.0)
					link.duration = duration
					return link
	return {}

func _simulate(link: Dictionary) -> float:
	var point: Vector2 = link.launch
	var vy := 0.0 if link.kind == "drop" else -jump
	var dash_direction := Vector2.ZERO
	for frame in 120:
		var elapsed := frame * STEP
		var direction := steering(link, point)
		if link.kind == "boost" and frame == 14:
			dash_direction = Vector2(direction, -1 if link.boost_up else 0).normalized()
		var boosting: bool = link.kind == "boost" and elapsed >= 14 * STEP and elapsed < 14 * STEP + dash_duration
		var vx := direction * speed
		if boosting:
			vx = dash_direction.x * dash_speed
			vy = maxf(dash_direction.y * dash_speed, -dash_speed / sqrt(2.0))
		else:
			vy = minf(vy + gravity * STEP, terminal)
		var motion := Vector2(vx, vy) * STEP
		for slide in 3:
			var hit := _sweep(point, motion)
			if hit.is_empty():
				point += motion
				break
			point += motion * hit.fraction
			var normal: Vector2 = hit.normal
			if normal.y < -0.7:
				var landed := support(point, 1)
				if landed == link.to:
					return elapsed + STEP
				if landed != link.from or link.kind != "drop":
					return -1
				vy = 0
			elif normal.y > 0.7:
				vy = 0
			motion = (motion * (1.0 - hit.fraction)).slide(normal)

		if point.y > 520 or point.x < -12 or point.x > 892:
			return -1
	return -1

# Swept body bounds preserve corner collisions that point rays and discrete steps miss.
func _sweep(origin: Vector2, motion: Vector2) -> Dictionary:
	var earliest := 1.01
	var hit_normal := Vector2.ZERO
	for solid in solids:
		var rect := Rect2(solid.position - HALF - Vector2.ONE * 0.08, solid.size + HALF * 2 + Vector2.ONE * 0.16)
		var entry := -INF
		var leave := INF
		var normal := Vector2.ZERO
		var possible := true
		for axis in 2:
			if absf(motion[axis]) < 0.00001:
				if origin[axis] <= rect.position[axis] + 0.00001 or origin[axis] >= rect.end[axis] - 0.00001:
					possible = false
					break
				continue
			var near := (rect.position[axis] - origin[axis]) / motion[axis]
			var far := (rect.end[axis] - origin[axis]) / motion[axis]
			var first := minf(near, far)
			if first > entry:
				entry = first
				normal = Vector2.ZERO
				normal[axis] = -signf(motion[axis])
			leave = minf(leave, maxf(near, far))
		if possible and entry >= -0.00001 and entry <= 1 and entry <= leave and entry < earliest:
			earliest = maxf(entry, 0)
			hit_normal = normal
	return {} if hit_normal == Vector2.ZERO else {"fraction": earliest, "normal": hit_normal}
