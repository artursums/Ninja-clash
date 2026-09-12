extends Node2D

const Arena := preload("res://arena_rules.gd")
const TILE := 32
const CORE := Rect2(272, 24, TILE, TILE)
var theme := "cistern"
var walls: Array = []
var atlas: Texture2D
var edge_color := Color.WHITE
var _tiles: Array[Rect2] = []
var _edges: Array[Rect2] = []
var _edge_sources: Array[Rect2] = []
var _caps: Array[Rect2] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for wall in walls:
		var rect := Rect2(wall.center - wall.size * 0.5, wall.size)
		for y in range(int(rect.position.y), int(rect.end.y), TILE):
			for x in range(int(rect.position.x), int(rect.end.x), TILE):
				_tiles.append(Rect2(x, y, minf(TILE, rect.end.x - x), minf(TILE, rect.end.y - y)))
		# Only exposed faces get trim; adjoining solids read as one continuous structure.
		for x in range(int(rect.position.x), int(rect.end.x), 8):
			var width := minf(8, rect.end.x - x)
			if not _solid(Vector2(x + width * 0.5, rect.position.y - 1)):
				_caps.append(Rect2(x, rect.position.y, width, minf(8, rect.size.y)))
			if not _solid(Vector2(x + width * 0.5, rect.end.y + 1)):
				_edges.append(Rect2(x, rect.end.y - 4, width, 4))
				_edge_sources.append(Rect2(16 + posmod(x, 160), 28, width, 4))
		for y in range(int(rect.position.y), int(rect.end.y), 8):
			var height := minf(8, rect.end.y - y)
			if not _solid(Vector2(rect.position.x - 1, y + height * 0.5)):
				_edges.append(Rect2(rect.position.x, y, minf(6, rect.size.x), height))
				_edge_sources.append(Rect2(200, 8 + posmod(y, 96), minf(6, rect.size.x), height))
			if not _solid(Vector2(rect.end.x + 1, y + height * 0.5)):
				_edges.append(Rect2(rect.end.x - minf(6, rect.size.x), y, minf(6, rect.size.x), height))
				_edge_sources.append(Rect2(248 - minf(6, rect.size.x), 8 + posmod(y, 96), minf(6, rect.size.x), height))

func _solid(point: Vector2) -> bool:
	point = Arena.wrap_position(point)
	for wall in walls:
		if Rect2(wall.center - wall.size * 0.5, wall.size).has_point(point):
			return true
	return false

func _draw() -> void:
	for tile in _tiles:
		draw_texture_rect_region(atlas, tile, Rect2(CORE.position + Vector2(posmod(int(tile.position.x / TILE), 2), posmod(int(tile.position.y / TILE), 2)) * TILE, tile.size))
	for cap in _caps:
		draw_texture_rect_region(atlas, cap, Rect2(Vector2(fposmod(cap.position.x, 160) + 16, 0), cap.size))
	for i in _edges.size():
		draw_texture_rect_region(atlas, _edges[i], _edge_sources[i])
