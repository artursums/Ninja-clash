extends GutTest
## Map data integrity — regression guard for the "opponent spawned next to me" report.
## Two fighters must never START on top of each other, so every map's first two spawn points
## must exist and be well separated. (Tests the Maps data directly — autoloads aren't available
## in GUT -s mode.) The slot→spawn mapping in main.gd is deterministic: slot 1 → spawn_points[0],
## slot 2 → spawn_points[1], so guarding the data guards the spawn separation.

const MapsScript := preload("res://maps.gd")
const MIN_SPAWN_SEPARATION := 200.0   # px; the duel map uses 230 vs 570 = 340 px apart


func test_maps_every_map_has_at_least_two_spawn_points() -> void:
	# Arrange
	var maps = autofree(MapsScript.new())   # untyped: maps.gd has no class_name
	# Act / Assert
	for i in maps.count():
		var data: Dictionary = maps.get_map(i)
		assert_true(data.has("spawn_points"), "map %d defines spawn_points" % i)
		assert_gte(data.spawn_points.size(), 2, "map %d has >= 2 spawn points" % i)


func test_maps_first_two_spawns_are_well_separated() -> void:
	# Arrange
	var maps = autofree(MapsScript.new())
	# Act / Assert
	for i in maps.count():
		var sp: Array = maps.get_map(i).spawn_points
		var dist: float = sp[0].distance_to(sp[1])
		assert_gte(dist, MIN_SPAWN_SEPARATION,
			"map %d: P1/P2 spawns must be >= %d px apart (got %.0f)" % [i, int(MIN_SPAWN_SEPARATION), dist])
