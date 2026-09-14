extends RefCounted

const Rules := preload("res://perk_rules.gd")
const Arena := preload("res://arena_rules.gd")
const CELL := 16.0
var grid := AStarGrid2D.new()
var solids: Array[Rect2] = []
var signature := 0

func configure(terrain: Array) -> void:
	var rects: Array[Rect2] = []
	for entry in terrain:
		rects.append(entry.rect.grow(10.0))
	var next_signature := hash(rects)
	if signature == next_signature and not solids.is_empty():
		return
	signature = next_signature
	solids = rects
	grid.region = Rect2i(0, 0, ceili(Arena.WIDTH/CELL), ceili(Arena.HEIGHT/CELL))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var id := Vector2i(x,y)
			var pos := grid.get_point_position(id)
			grid.set_point_solid(id, not point_free(pos))

func point_free(point: Vector2) -> bool:
	if not Rect2(Vector2(8,8),Arena.SIZE-Vector2(16,16)).has_point(point):
		return false
	for rect in solids:
		if rect.has_point(point):
			return false
	return true

func clear(from: Vector2, to: Vector2) -> bool:
	for rect in solids:
		if rect.has_point(from) or rect.has_point(to) or not Rules.sweep(from, to-from, rect).is_empty():
			return false
	return true

func _cell(point: Vector2) -> Vector2i:
	var base := Vector2i(point / CELL)
	var best := Vector2i(-1,-1)
	var distance := INF
	for y in range(base.y-3,base.y+4):
		for x in range(base.x-3,base.x+4):
			var id := Vector2i(x,y)
			if not grid.is_in_boundsv(id) or grid.is_point_solid(id):
				continue
			var candidate := grid.get_point_position(id)
			if candidate.distance_squared_to(point) < distance and clear(point,candidate):
				distance = candidate.distance_squared_to(point)
				best = id
	return best

func waypoint(from: Vector2, to: Vector2) -> Vector2:
	if clear(from,to):
		return to
	var start := _cell(from)
	var end := _cell(to)
	if start.x < 0 or end.x < 0:
		return from
	var path := grid.get_point_path(start,end)
	for index in range(path.size()-1,-1,-1):
		if clear(from,path[index]):
			return path[index]
	return from
