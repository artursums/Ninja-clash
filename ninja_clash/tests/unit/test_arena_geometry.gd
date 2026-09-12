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
	assert_eq(Arena.wrap_position(Arena.SIZE - Vector2(40, 40)), Arena.SIZE - Vector2(40, 40), "Former boundary is playable space")
	assert_eq(Arena.wrap_position(Vector2(Arena.WIDTH + 25, 200)), Vector2(25, 200), "Right exit preserves overshoot")
	assert_eq(Arena.wrap_position(Vector2(-25, 200)), Vector2(Arena.WIDTH - 25, 200), "Left exit preserves overshoot")
	assert_eq(Arena.wrap_position(Vector2(400, Arena.HEIGHT + 38)), Vector2(400, 38), "Bottom exit")
	assert_eq(Arena.wrap_position(Vector2(400, -38)), Vector2(400, Arena.HEIGHT - 38), "Top exit")

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

func test_open_corridors_fit_the_fighter_with_clearance() -> void:
	var maps = autofree(MapsScript.new())
	for map_index in maps.count():
		var data: Dictionary = maps.get_map(map_index)
		for first in data.walls:
			var a := Rect2(first.center-first.size/2,first.size)
			for second in data.walls:
				var b := Rect2(second.center-second.size/2,second.size)
				var overlap_y := minf(a.end.y,b.end.y)-maxf(a.position.y,b.position.y)
				var overlap_x := minf(a.end.x,b.end.x)-maxf(a.position.x,b.position.x)
				var gap_x := b.position.x-a.end.x
				var gap_y := b.position.y-a.end.y
				if gap_x > 0 and overlap_y >= 8:
					var passage := Rect2(a.end.x,maxf(a.position.y,b.position.y),gap_x,overlap_y)
					if not _gap_is_solid(data.walls,passage):
						assert_gte(gap_x,40.0,data.name+" open side passage fits a 20px fighter comfortably")
				if gap_y > 0 and overlap_x >= 8:
					var passage := Rect2(maxf(a.position.x,b.position.x),a.end.y,overlap_x,gap_y)
					if not _gap_is_solid(data.walls,passage):
						assert_gte(gap_y,44.0,data.name+" open tunnel has 12px clearance above the fighter")

func _gap_is_solid(walls: Array, gap: Rect2) -> bool:
	for wall in walls:
		if Rect2(wall.center-wall.size/2,wall.size).encloses(gap):
			return true
	return false

func test_lamps_rest_on_clear_terrain_faces() -> void:
	var maps = autofree(MapsScript.new())
	for index in maps.count():
		var data: Dictionary = maps.get_map(index)
		assert_gte(data.lamp_anchors.size(), 4, "Every arena retains its lamps")
		for anchor: Vector2 in data.lamp_anchors:
			var supported := false
			for wall in data.walls:
				var rect := Rect2(wall.center - wall.size * 0.5, wall.size)
				if is_equal_approx(rect.position.y, anchor.y) and anchor.x - 6 >= rect.position.x and anchor.x + 6 <= rect.end.x:
					supported = true
				assert_false(rect.intersects(Rect2(anchor - Vector2(6, 18), Vector2(12, 18))), "Lamp remains visible above the masonry")
			assert_true(supported, data.name + " lamp base rests on a platform")

func test_optional_platforms_have_safe_clearance() -> void:
	var maps = autofree(MapsScript.new())
	for index in maps.count():
		var data: Dictionary = maps.get_map(index)
		for rect: Rect2 in data.crumble_platforms:
			assert_gte(rect.size.x,64.0,"Crumbling landings have space to turn around")
			assert_true(Rect2(40,40,Arena.WIDTH-80,Arena.HEIGHT-80).encloses(rect),"Dynamic platforms never remove a seam floor")
			for wall in data.walls:
				var solid := Rect2(wall.center-wall.size/2,wall.size)
				assert_false(solid.intersects(rect),"Optional slabs do not overlap masonry")
				assert_false(solid.intersects(Rect2(rect.position-Vector2(0,40),Vector2(rect.size.x,40))),"Full landing has headroom")
				if minf(solid.end.y,rect.end.y) > maxf(solid.position.y,rect.position.y):
					var gap := maxf(solid.position.x-rect.end.x,rect.position.x-solid.end.x)
					assert_gte(gap,40.0,"Optional slabs cannot create a narrow side trap")
			for spawn: Vector2 in data.spawn_points:
				assert_false(rect.grow(16).has_point(spawn),"Spawns use permanent ground")
