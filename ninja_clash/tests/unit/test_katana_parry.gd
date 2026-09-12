extends GutTest

const Parry := preload("res://katana_parry.gd")

func test_parry_window_includes_windup_and_followthrough() -> void:
	for time in [0.025, 0.04, 0.15, 0.26, 0.285]:
		assert_true(Parry.active(time))
	for time in [-0.1, 0.0, 0.024, 0.286, 1.0]:
		assert_false(Parry.active(time))

func test_fast_blade_crossing_between_ticks_is_caught() -> void:
	assert_true(Parry.intersects(Vector2(200,200), 1, Vector2(265,220), Vector2(190,220)))
	assert_true(Parry.intersects(Vector2(200,200), -1, Vector2(135,180), Vector2(210,180)))

func test_reach_is_forgiving_only_in_front() -> void:
	for facing in [-1, 1]:
		var tip := Vector2(facing*45,26)
		assert_true(Parry.intersects(Vector2.ZERO, facing, tip, tip))
		for point in [Vector2(facing*-12,0), Vector2(facing*47,0), Vector2(facing*30,28), Vector2(facing*30,-28)]:
			assert_false(Parry.intersects(Vector2.ZERO, facing, point, point))

func test_segment_parallel_to_edge_does_not_false_positive() -> void:
	assert_false(Parry.intersects(Vector2.ZERO, 1, Vector2(70,-28), Vector2(-20,-28)))
	assert_false(Parry.intersects(Vector2.ZERO, 1, Vector2(47,-50), Vector2(47,50)))
	assert_true(Parry.intersects(Vector2.ZERO, 1, Vector2(30,-50), Vector2(30,50)))
