extends Node

const Arena := preload("res://arena_rules.gd")
const LONG_DECK := Rect2(0, 0, 192, 32)
const SHORT_DECK := Rect2(0, 40, 128, 32)
const PILLAR := Rect2(200, 0, 48, 120)
const BLOCK := Rect2(256, 0, 96, 96)

var MAPS: Array = [
	_arena("Verdant Cistern", "sunken chambers · aqueduct crossings", "verdant_cistern", "cistern", Color("102d32"), Color("b7e39b"), [
		Rect2(0, 0, 59, 132), Rect2(821, 0, 59, 132), Rect2(59, 0, 322, 29),
		Rect2(499, 0, 322, 29), Rect2(0, 205, 59, 96), Rect2(821, 205, 59, 96),
		Rect2(0, 381, 59, 85), Rect2(821, 381, 59, 85), Rect2(0, 466, 381, 29),
		Rect2(499, 466, 381, 29), Rect2(99, 411, 165, 55), Rect2(616, 411, 165, 55),
		Rect2(152, 351, 112, 16), Rect2(616, 351, 112, 16), Rect2(264, 293, 352, 24), Rect2(59, 235, 161, 44),
		Rect2(660, 235, 161, 44), Rect2(264, 164, 96, 24), Rect2(520, 164, 96, 24),
		Rect2(374, 117, 132, 30),
	], [Vector2(117, 389), Vector2(763, 389), Vector2(315, 142), Vector2(565, 142)], [Vector2(86, 235), Vector2(794, 235), Vector2(330, 293), Vector2(550, 293)]),

	_arena("Sakura Temple", "moon gate · sheltered courtyards", "sakura_temple", "sakura", Color("302538"), Color("e4d1c5"), [
		Rect2(0, 0, 117, 103), Rect2(763, 0, 117, 103), Rect2(117, 0, 279, 37),
		Rect2(484, 0, 279, 37), Rect2(0, 103, 73, 62), Rect2(807, 103, 73, 62),
		Rect2(73, 165, 206, 33), Rect2(601, 165, 206, 33), Rect2(0, 374, 59, 92),
		Rect2(821, 374, 59, 92), Rect2(0, 466, 396, 29), Rect2(484, 466, 396, 29),
		Rect2(103, 407, 176, 59), Rect2(601, 407, 176, 59), Rect2(0, 345, 92, 29),
		Rect2(788, 345, 92, 29), Rect2(152, 286, 144, 24), Rect2(584, 286, 144, 24),
		Rect2(308, 224, 264, 24),
		Rect2(308, 106, 112, 30), Rect2(460, 106, 112, 30),
	], [Vector2(191, 385), Vector2(689, 385), Vector2(213, 143), Vector2(667, 143)], [Vector2(132, 165), Vector2(748, 165), Vector2(338, 224), Vector2(542, 224)]),

	_arena("Neo Tokyo", "service tunnels · neon rooftops", "neo_tokyo", "tokyo", Color("102334"), Color("50deef"), [
		Rect2(0, 0, 59, 88), Rect2(821, 0, 59, 88), Rect2(59, 0, 141, 29),
		Rect2(264, 0, 557, 29), Rect2(0, 392, 200, 103), Rect2(641, 392, 239, 103),
		Rect2(264, 451, 377, 44), Rect2(147, 328, 77, 20), Rect2(675, 328, 205, 20),
		Rect2(264, 275, 44, 52), Rect2(601, 275, 40, 52), Rect2(367, 271, 146, 16),
		 Rect2(161, 200, 88, 16), Rect2(411, 211, 117, 16),
		Rect2(660, 204, 92, 22), Rect2(59, 158, 88, 29), Rect2(279, 151, 205, 16),
		Rect2(763, 158, 117, 36), Rect2(159, 99, 61, 29), Rect2(528, 99, 176, 37),
		Rect2(0, 158, 59, 117), Rect2(851, 194, 29, 81), Rect2(0, 328, 73, 64),
		Rect2(308, 391, 59, 16), Rect2(513, 391, 88, 16),
		Rect2(348, 331, 64, 16), Rect2(505, 331, 64, 16), Rect2(851, 348, 29, 44),
	], [Vector2(103, 370), Vector2(651, 370), Vector2(367, 129), Vector2(724, 182)], [Vector2(120, 158), Vector2(796, 158), Vector2(286, 275), Vector2(616, 275), Vector2(440, 271)]),

	_arena("Sky Temple", "broken cloisters · hanging sanctuary", "sky_temple", "sky", Color("4b655e"), Color("dbdc94"), [
		Rect2(0, 0, 176, 37), Rect2(704, 0, 176, 37), Rect2(0, 37, 59, 194),
		Rect2(821, 37, 59, 194), Rect2(59, 429, 176, 66), Rect2(645, 429, 176, 66),
		Rect2(235, 473, 176, 22), Rect2(469, 473, 176, 22), Rect2(0, 363, 103, 66),
		Rect2(777, 363, 103, 66), Rect2(176, 363, 117, 22), Rect2(587, 363, 117, 22),
		Rect2(88, 297, 117, 22), Rect2(675, 297, 117, 22), Rect2(323, 297, 234, 37),
		 Rect2(205, 231, 118, 29), Rect2(557, 231, 118, 29),
		Rect2(59, 165, 117, 37), Rect2(704, 165, 117, 37), Rect2(293, 165, 118, 22),
		Rect2(469, 165, 118, 22), Rect2(235, 99, 117, 22), Rect2(528, 99, 117, 22),
		Rect2(0, 429, 59, 66), Rect2(821, 429, 59, 66),
		Rect2(176, 0, 235, 22), Rect2(469, 0, 235, 22),
	], [Vector2(147, 407), Vector2(733, 407), Vector2(315, 145), Vector2(565, 145)], [Vector2(146, 165), Vector2(734, 165), Vector2(348, 297), Vector2(532, 297)]),

]

static func _arena(title: String, subtitle: String, folder: String, ambience: String, stone: Color, edge: Color, geometry: Array, spawns: Array, lamps: Array) -> Dictionary:
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
		"background_tint": Color(0.53, 0.60, 0.65) if ambience == "sky" else Color(0.65, 0.67, 0.73),
		"crumble_platforms": _crumble_platforms(ambience),
		"platform_overhang": 1.0, "transparent_platforms": false,
		"walls": walls, "spawn_points": spawns, "bot_ledges": _exposed_ledges(geometry),
		"lamp_anchors": PackedVector2Array(lamps),
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

static func _crumble_platforms(ambience: String) -> Array[Rect2]:
	# Optional low shortcuts; the permanent navigation graph stays connected without them.
	match ambience:
		"cistern": return [Rect2(348, 390, 72, 16), Rect2(460, 390, 72, 16)]
		"sakura": return [Rect2(336, 352, 72, 16), Rect2(472, 352, 72, 16)]
		"tokyo": return [Rect2(407, 391, 64, 16)]
		_: return [Rect2(320, 407, 64, 16), Rect2(496, 407, 64, 16)]
