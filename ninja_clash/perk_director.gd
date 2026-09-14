extends Node2D

const Rules := preload("res://perk_rules.gd")
const Navigation := preload("res://seeker_navigation.gd")
var rng := RandomNumberGenerator.new()
var pickups: Array = []
var events: Array = []
var bag: Array[int] = []
var elapsed := 0.0
var serial := 0
var navigation := Navigation.new()
var _navigation_age := 1.0
var _terrain: Array = []

func _ready() -> void:
	add_to_group("perk_director")
	z_index = 80
	rng.randomize()

func reset() -> void:
	pickups.clear()
	events.clear()
	elapsed = 0
	_navigation_age = 1
	queue_redraw()

func begin_round() -> void:
	reset()
	if Net.is_client() or not MatchConfig.shurikens_enabled:
		return
	var first := rng.randf_range(6,10)
	var roll := rng.randf()
	events.append({"at": first-1, "count": 2 if roll >= 0.85 else 1, "deadline": first+2})
	if roll >= 0.5 and roll < 0.85:
		var second := first + rng.randf_range(8,12)
		events.append({"at": second-1, "count": 1, "deadline": second+2})

func alive_count() -> int:
	var count := 0
	for p in get_tree().get_nodes_in_group("players"):
		if p.alive:
			count += 1
	return count

func next_kind(alive: int, excluded: int = 0) -> int:
	var eligible: Array[int] = [Rules.Kind.MISDIRECTION, Rules.Kind.SEEKER, Rules.Kind.RICOCHET]
	if alive >= 3:
		eligible.append(Rules.Kind.SWAP)
	for kind in bag.duplicate():
		if not eligible.has(kind):
			bag.erase(kind)
	for attempt in 2:
		for index in bag.size():
			if bag[index] != excluded:
				var kind := bag[index]
				bag.remove_at(index)
				return kind
		bag = eligible.duplicate()
		for index in range(bag.size()-1,0,-1):
			var other := rng.randi_range(0,index)
			var value := bag[index]
			bag[index] = bag[other]
			bag[other] = value
	return eligible[0]

func candidates() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var data: Dictionary = Maps.get_map(GameState.selected_map_index)
	for ledge: Rect2 in data.bot_ledges:
		var pos := Vector2(ledge.get_center().x,ledge.position.y-18)
		if pos.x < 36 or pos.x > 844 or pos.y < 60 or pos.y > 450:
			continue
		var clear := true
		var bounds := Rect2(pos-Vector2(16,16),Vector2(32,32))
		for wall in data.walls:
			if Rect2(wall.center-wall.size/2,wall.size).intersects(bounds):
				clear = false
		if clear:
			result.append(pos)
	return result

func _spawn_event(count: int) -> bool:
	var choices: Array[Vector2] = []
	for point in candidates():
		var safe := true
		for p in get_tree().get_nodes_in_group("players"):
			if p.alive and p.position.distance_to(point) < 80:
				safe = false
		for pickup in pickups:
			if pickup.pos.distance_to(point) < 180:
				safe = false
		if safe:
			choices.append(point)
	if choices.is_empty():
		return false
	var first: Vector2 = choices[rng.randi_range(0,choices.size()-1)]
	var kind := next_kind(alive_count())
	add_pickup(kind,first)
	if count == 2:
		var distant: Array[Vector2] = []
		for point in choices:
			if point.distance_to(first) >= 180:
				distant.append(point)
		if not distant.is_empty():
			add_pickup(next_kind(alive_count(),kind),distant[rng.randi_range(0,distant.size()-1)])
	return true

func add_pickup(kind: int, point: Vector2, warning: float = 1.0) -> void:
	serial += 1
	pickups.append({"id": serial,"kind": kind,"pos": point,"warning": warning,"left": 8.0})

func _physics_process(delta: float) -> void:
	visible = GameState.is_round_active()
	if not visible:
		return
	_navigation_age += delta
	if not Net.is_client():
		advance(delta)
	queue_redraw()

func advance(delta: float) -> void:
	elapsed += delta
	for event in events.duplicate():
		if elapsed >= event.at and (_spawn_event(event.count) or elapsed > event.deadline):
			events.erase(event)
	for pickup in pickups.duplicate():
		if pickup.kind == Rules.Kind.SWAP and alive_count() < 3:
			pickups.erase(pickup)
			continue
		if pickup.warning > 0:
			pickup.warning = maxf(0,pickup.warning-delta)
			continue
		pickup.left -= delta
		if pickup.left <= 0:
			pickups.erase(pickup)
			continue
		for p in get_tree().get_nodes_in_group("players"):
			if p.alive and p.perk_kind == Rules.Kind.NONE and p.global_position.distance_to(pickup.pos) < 25:
				p.grant_perk(pickup.kind)
				pickups.erase(pickup)
				Audio.play("confirm")
				break

func seeker_navigation() -> RefCounted:
	if _navigation_age >= 0.15:
		_terrain = Rules.terrain(get_tree())
		navigation.configure(_terrain)
		_navigation_age = 0
	return navigation

func snapshot() -> Array:
	var result: Array = []
	for p in pickups:
		result.append([p.id,p.kind,p.pos.x,p.pos.y,p.warning,p.left])
	return result

func apply_snapshot(rows: Array) -> void:
	pickups.clear()
	for row in rows:
		if row.size() == 6:
			pickups.append({"id":int(row[0]),"kind":int(row[1]),"pos":Vector2(row[2],row[3]),"warning":float(row[4]),"left":float(row[5])})
	queue_redraw()

func _draw() -> void:
	for p in pickups:
		var color: Color = Rules.COLORS[p.kind]
		var at: Vector2 = p.pos
		if p.warning > 0:
			draw_arc(at,20,0,TAU,24,Color(color,0.5),1)
			draw_arc(at,20,-PI/2,-PI/2+TAU*(1-p.warning),24,color,2)
		else:
			draw_rect(Rect2(at-Vector2(15,15),Vector2(30,30)),Color("111a2bef"))
			draw_rect(Rect2(at-Vector2(15,15),Vector2(30,30)),color,false,2)
			draw_line(at+Vector2(-13,18),at+Vector2(-13+26*p.left/8,18),color,2)
		Rules.draw_icon(self,p.kind,at,14)
		var label: String = Rules.NAMES[p.kind]
		var width: float = Rules.FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		draw_rect(Rect2(at+Vector2(-width/2-3,-30),Vector2(width+6,12)),Color("111a2bef"))
		draw_string(Rules.FONT,at+Vector2(-width/2,-20),label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)
