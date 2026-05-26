extends GutTest
## Unit tests for the Map system (src/core/map/). Covers the screen-wrap formula, the static
## validator, the registry, and the loader against the shipped flat_arena. The full trajectory-
## sweep recoverability validator is deferred to Sprint 3 (needs Projectile physics).


# --- Screen-wrap formula --------------------------------------------------------

func test_wrap_axis_within_range() -> void:
	assert_almost_eq(ScreenWrap.wrap_axis(490.0, 480.0), 10.0, 0.001)


func test_wrap_axis_handles_negative() -> void:
	assert_almost_eq(ScreenWrap.wrap_axis(-10.0, 480.0), 470.0, 0.001)


func test_wrap_axis_handles_multiple_wraps() -> void:
	# 1450 - 3*480 = 10
	assert_almost_eq(ScreenWrap.wrap_axis(1450.0, 480.0), 10.0, 0.001)


func test_wrap_position_horizontal_only() -> void:
	var m := MapResource.new()
	m.horizontal_wrap = true
	m.vertical_wrap = false
	m.playfield_width = 480.0
	var p := ScreenWrap.wrap_position(Vector2(-5.0, 300.0), m)
	assert_almost_eq(p.x, 475.0, 0.001)
	assert_almost_eq(p.y, 300.0, 0.001, "vertical wrap disabled → y unchanged")


# --- Validator ------------------------------------------------------------------

func test_validator_passes_for_complete_map() -> void:
	assert_true(MapValidator.is_valid(_valid_map()))


func test_validator_requires_four_spawn_points() -> void:
	var m := _valid_map()
	m.spawn_points = [Vector2.ZERO, Vector2.ONE] as Array[Vector2]
	assert_false(MapValidator.is_valid(m))


func test_validator_requires_recoverability_flag() -> void:
	var m := _valid_map()
	m.recoverability_validated = false
	assert_false(MapValidator.is_valid(m))


func test_validator_requires_id_and_name() -> void:
	var m := _valid_map()
	m.id = &""
	assert_false(MapValidator.is_valid(m))


# --- Registry + loader (against the shipped flat_arena) -------------------------

func test_registry_finds_flat_arena() -> void:
	var ids: Array = []
	for m in MapRegistry.all_maps():
		ids.append(m.id)
	assert_has(ids, &"flat_arena")


func test_registry_ids_are_unique() -> void:
	assert_eq(MapRegistry.duplicate_ids(), [] as Array[StringName])


func test_shipped_flat_arena_validates() -> void:
	var m := MapRegistry.get_map(&"flat_arena")
	assert_not_null(m)
	if m != null:
		assert_true(MapValidator.is_valid(m), "flat_arena must pass validation to ship")


func test_loader_instantiates_flat_arena() -> void:
	var scene := MapLoader.load_map(&"flat_arena")
	assert_not_null(scene, "flat_arena scene instantiates")
	if scene != null:
		assert_true(scene.has_node(^"Floor"), "scene has its floor geometry")
		scene.free()


func _valid_map() -> MapResource:
	var m := MapResource.new()
	m.id = &"test_map"
	m.display_name = "Test Map"
	m.spawn_points = [Vector2.ZERO, Vector2.ONE, Vector2(2, 2), Vector2(3, 3)] as Array[Vector2]
	m.recommended_player_count = Vector2i(2, 4)
	m.recoverability_validated = true
	return m
