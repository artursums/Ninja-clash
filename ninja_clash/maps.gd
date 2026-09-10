extends Node

const Arena := preload("res://arena_rules.gd")
const LONG_DECK := Rect2(0, 0, 192, 32)
const SHORT_DECK := Rect2(0, 40, 128, 32)
const PILLAR := Rect2(200, 0, 48, 120)
const BLOCK := Rect2(256, 0, 96, 96)

var MAPS: Array = [
	_arena("Verdant Cistern", "sunken chambers · aqueduct crossings", "verdant_cistern", "cistern", Color("102d32"), Color("b7e39b"), [
		Rect2(0, 0, 64, 144), Rect2(896, 0, 64, 144), Rect2(64, 0, 352, 32),
		Rect2(544, 0, 352, 32), Rect2(0, 224, 64, 104), Rect2(896, 224, 64, 104),
		Rect2(0, 416, 64, 92), Rect2(896, 416, 64, 92), Rect2(0, 508, 416, 32),
		Rect2(544, 508, 416, 32), Rect2(96, 448, 192, 60), Rect2(672, 448, 192, 60),
		Rect2(176, 384, 128, 40), Rect2(656, 384, 128, 40), Rect2(288, 320, 384, 40),
		Rect2(336, 360, 32, 56), Rect2(592, 360, 32, 56), Rect2(64, 256, 176, 48),
		Rect2(720, 256, 176, 48), Rect2(288, 192, 144, 40), Rect2(528, 192, 144, 40),
		Rect2(408, 128, 144, 32),
	], [Vector2(128, 424), Vector2(832, 424), Vector2(344, 168), Vector2(616, 168)]),

	_arena("Sakura Temple", "moon gate · sheltered courtyards", "sakura_temple", "sakura", Color("302538"), Color("e4d1c5"), [
		Rect2(0, 0, 128, 112), Rect2(832, 0, 128, 112), Rect2(128, 0, 304, 40),
		Rect2(528, 0, 304, 40), Rect2(0, 112, 80, 68), Rect2(880, 112, 80, 68),
		Rect2(80, 180, 224, 36), Rect2(656, 180, 224, 36), Rect2(0, 408, 64, 100),
		Rect2(896, 408, 64, 100), Rect2(0, 508, 432, 32), Rect2(528, 508, 432, 32),
		Rect2(112, 444, 192, 64), Rect2(656, 444, 192, 64), Rect2(0, 376, 144, 32),
		Rect2(816, 376, 144, 32), Rect2(184, 312, 144, 40), Rect2(632, 312, 144, 40),
		Rect2(336, 244, 288, 40), Rect2(352, 284, 32, 96), Rect2(576, 284, 32, 96),
		Rect2(336, 116, 128, 32), Rect2(496, 116, 128, 32), Rect2(408, 444, 144, 32),
	], [Vector2(208, 420), Vector2(752, 420), Vector2(232, 156), Vector2(728, 156)]),

	_arena("Neo Tokyo", "service tunnels · neon rooftops", "neo_tokyo", "tokyo", Color("102334"), Color("50deef"), [
		Rect2(0, 0, 64, 96), Rect2(896, 0, 64, 96), Rect2(64, 0, 176, 32),
		Rect2(288, 0, 608, 32), Rect2(0, 428, 240, 112), Rect2(688, 428, 272, 112),
		Rect2(288, 492, 400, 48), Rect2(160, 364, 96, 24), Rect2(736, 364, 224, 24),
		Rect2(288, 300, 48, 192), Rect2(656, 300, 32, 192), Rect2(400, 300, 160, 32),
		Rect2(456, 360, 48, 132), Rect2(176, 236, 96, 24), Rect2(448, 236, 128, 32),
		Rect2(720, 236, 144, 24), Rect2(64, 172, 96, 32), Rect2(304, 172, 224, 32),
		Rect2(832, 172, 128, 40), Rect2(112, 108, 128, 32), Rect2(576, 108, 192, 40),
		Rect2(0, 172, 64, 128), Rect2(928, 212, 32, 88), Rect2(0, 364, 80, 64),
		Rect2(336, 428, 64, 24), Rect2(560, 428, 96, 24),
		Rect2(368, 364, 64, 24), Rect2(560, 364, 64, 24), Rect2(928, 388, 32, 40),
	], [Vector2(112, 404), Vector2(704, 404), Vector2(400, 148), Vector2(784, 212)]),

	_arena("Sky Temple", "broken cloisters · hanging sanctuary", "sky_temple", "sky", Color("4b655e"), Color("dbdc94"), [
		Rect2(0, 0, 192, 40), Rect2(768, 0, 192, 40), Rect2(0, 40, 64, 212),
		Rect2(896, 40, 64, 212), Rect2(64, 468, 192, 72), Rect2(704, 468, 192, 72),
		Rect2(256, 516, 192, 24), Rect2(512, 516, 192, 24), Rect2(0, 396, 112, 72),
		Rect2(848, 396, 112, 72), Rect2(192, 396, 128, 24), Rect2(640, 396, 128, 24),
		Rect2(96, 324, 128, 24), Rect2(736, 324, 128, 24), Rect2(352, 324, 256, 40),
		Rect2(448, 364, 64, 80), Rect2(224, 252, 128, 32), Rect2(608, 252, 128, 32),
		Rect2(64, 180, 128, 40), Rect2(768, 180, 128, 40), Rect2(320, 180, 128, 32),
		Rect2(512, 180, 128, 32), Rect2(256, 108, 128, 32), Rect2(576, 108, 128, 32),
		Rect2(0, 468, 64, 72), Rect2(896, 468, 64, 72),
		Rect2(192, 0, 256, 24), Rect2(512, 0, 256, 24),
	], [Vector2(160, 444), Vector2(800, 444), Vector2(344, 156), Vector2(616, 156)]),

]

static func _arena(title: String, subtitle: String, folder: String, ambience: String, stone: Color, edge: Color, geometry: Array, spawns: Array) -> Dictionary:
	var path := "res://sprites/levels/" + folder + "/"
	var walls: Array = []
	for rect: Rect2 in geometry:
		var region := LONG_DECK if rect.size.x >= 144 else SHORT_DECK
		if rect.size.y > 40:
			region = PILLAR if rect.size.y > rect.size.x else BLOCK
		walls.append({
			"center": rect.get_center(), "size": rect.size,
			"sprite": path + "masonry.webp", "sprite_region": region,
			"sprite_mode": "block", "sprite_walkable": 0.0,
			"bot_perch": _walkable_top(rect, geometry),
		})
	var result := {
		"name": title, "subtitle": subtitle, "ambience": ambience,
		"background": path + "panorama.webp", "preview": path + "arena.webp",
		"bg_color": stone.darkened(0.65), "sky_top": stone.darkened(0.65), "sky_bot": stone,
		"wall_color": stone, "wall_edge_color": edge,
		"background_tint": Color(0.65, 0.72, 0.78) if ambience == "sky" else Color(0.8, 0.8, 0.86),
		"platform_overhang": 1.0, "transparent_platforms": false,
		"walls": walls, "spawn_points": spawns, "bot_ledges": _exposed_ledges(geometry),
	}
	if ambience == "tokyo":
		result["music"] = "res://audio/gameplay/Rain Circuit Clash.mp3"
	return result

static func _exposed_ledges(geometry: Array) -> Array[Rect2]:
	var ledges: Array[Rect2] = []
	for rect: Rect2 in geometry:
		if rect.position.y < 80:
			continue
		var spans: Array[Vector2] = [Vector2(rect.position.x, rect.end.x)]
		for other: Rect2 in geometry:
			if other.position.y >= rect.position.y or other.end.y <= rect.position.y - 32:
				continue
			var remaining: Array[Vector2] = []
			for span in spans:
				if other.end.x <= span.x or other.position.x >= span.y:
					remaining.append(span)
				else:
					if other.position.x > span.x:
						remaining.append(Vector2(span.x, other.position.x))
					if other.end.x < span.y:
						remaining.append(Vector2(other.end.x, span.y))
			spans = remaining
		for span in spans:
			if span.y - span.x >= 40:
				ledges.append(Rect2(span.x, rect.position.y, span.y - span.x, rect.size.y))
	return ledges

static func _walkable_top(rect: Rect2, geometry: Array) -> bool:
	if rect.position.y < 80 or rect.size.x < 48:
		return false
	for x in range(int(rect.position.x) + 12, int(rect.end.x) - 10, 16):
		var fighter := Rect2(x - 10, rect.position.y - 32, 20, 32)
		var clear := true
		for other: Rect2 in geometry:
			if other.intersects(fighter):
				clear = false
				break
		if clear:
			return true
	return false

func get_map(index: int) -> Dictionary:
	return MAPS[posmod(index, MAPS.size())]

func count() -> int:
	return MAPS.size()
