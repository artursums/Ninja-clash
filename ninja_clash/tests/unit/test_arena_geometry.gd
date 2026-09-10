extends GutTest

const MapsScript := preload("res://maps.gd")
const Arena := preload("res://arena_rules.gd")

func test_four_safe_supported_spawns_on_every_map() -> void:
	var maps = autofree(MapsScript.new())
	for i in maps.count():
		var data: Dictionary = maps.get_map(i)
		assert_eq(data.spawn_points.size(), 4, data.name + " supports four fighters")
		for slot in 4:
			var point: Vector2 = data.spawn_points[slot]
			var fighter := Rect2(point - Vector2(10, 16), Vector2(20, 32))
			assert_true(Rect2(Vector2.ZERO, Arena.SIZE).encloses(fighter), "Spawn lies inside arena")
			var supported := false
			for wall in data.walls:
				var rect := Rect2(wall.center - wall.size * 0.5, wall.size)
				assert_false(rect.intersects(fighter), data.name + " spawn is clear of masonry")
				var gap: float = rect.position.y - fighter.end.y
				if gap >= 0 and gap <= 12 and rect.position.x <= fighter.position.x and rect.end.x >= fighter.end.x:
					supported = true
			assert_true(supported, data.name + " spawn has an immediate landing")
			for other in range(slot + 1, 4):
				assert_gte(point.distance_to(data.spawn_points[other]), 200.0, "Spawn slots are separated")

func test_masonry_has_no_overlapping_collision_bodies() -> void:
	var maps = autofree(MapsScript.new())
	for i in maps.count():
		var walls: Array = maps.get_map(i).walls
		for a in walls.size():
			var first := Rect2(walls[a].center - walls[a].size * 0.5, walls[a].size)
			assert_true(Rect2(Vector2.ZERO, Arena.SIZE).encloses(first), "Geometry stays inside wrap bounds")
			for b in range(a + 1, walls.size()):
				var second := Rect2(walls[b].center - walls[b].size * 0.5, walls[b].size)
				assert_false(first.intersects(second), "Map %d solids %d and %d do not overlap" % [i, a, b])

func test_each_map_has_distinct_geometry_and_small_shared_atlas() -> void:
	var maps = autofree(MapsScript.new())
	var layouts: Array = []
	for i in maps.count():
		var data: Dictionary = maps.get_map(i)
		var signature: Array = []
		var atlas: Texture2D = load(data.walls[0].sprite)
		assert_lte(atlas.get_width() * atlas.get_height(), 512 * 256, "Small terrain atlas")
		assert_lte(data.walls.size(), 32, "Bounded static body count")
		for wall in data.walls:
			signature.append([wall.center, wall.size])
			assert_eq(wall.sprite, data.walls[0].sprite, "One shared terrain texture")
			assert_eq(wall.sprite_mode, "block", "Art follows exact collision rectangle")
		assert_false(layouts.has(signature), "Each arena has its own layout")
		layouts.append(signature)

func test_wrap_uses_new_world_bounds_and_preserves_overshoot() -> void:
	var margin := Vector2(20, 32)
	assert_eq(Arena.wrap_position(Vector2(900, 500), margin), Vector2(900, 500), "Former boundary is playable space")
	assert_eq(Arena.wrap_position(Vector2(985, 200), margin), Vector2(-15, 200), "Right exit preserves overshoot")
	assert_eq(Arena.wrap_position(Vector2(-25, 200), margin), Vector2(975, 200), "Left exit preserves overshoot")
	assert_eq(Arena.wrap_position(Vector2(400, 578), margin), Vector2(400, -26), "Bottom exit")
	assert_eq(Arena.wrap_position(Vector2(400, -38), margin), Vector2(400, 566), "Top exit")

func test_bot_landing_targets_have_headroom() -> void:
	var maps = autofree(MapsScript.new())
	for i in maps.count():
		var data: Dictionary = maps.get_map(i)
		for ledge: Rect2 in data.bot_ledges:
			var fighter := Rect2(ledge.get_center().x - 10, ledge.position.y - 32, 20, 32)
			for wall in data.walls:
				assert_false(Rect2(wall.center - wall.size * 0.5, wall.size).intersects(fighter), "Bot landing target has clear headroom")

func test_wrap_portals_match_the_opposite_edge() -> void:
	var maps = autofree(MapsScript.new())
	for i in maps.count():
		var walls: Array = maps.get_map(i).walls
		for y in range(4, int(Arena.HEIGHT), 8):
			assert_eq(_solid_at(walls, Vector2(0.5, y)), _solid_at(walls, Vector2(Arena.WIDTH - 0.5, y)), "Side exits have an open destination")
		for x in range(4, int(Arena.WIDTH), 8):
			assert_eq(_solid_at(walls, Vector2(x, 0.5)), _solid_at(walls, Vector2(x, Arena.HEIGHT - 0.5)), "Vertical exits align with the opposite opening")

func _solid_at(walls: Array, point: Vector2) -> bool:
	for wall in walls:
		if Rect2(wall.center - wall.size * 0.5, wall.size).has_point(point):
			return true
	return false
