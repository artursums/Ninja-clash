extends GutTest
## Regression guard for the data-driven tuning (player_tuning.tres). Catches accidental balance
## drift from an editor save, and verifies the katana-window invariant. The .tres is the editable
## balance source; these tests pin the validated prototype values + the structural invariant.


func _tuning() -> PlayerTuning:
	return load("res://player_tuning.tres") as PlayerTuning


func test_tuning_resource_loads() -> void:
	assert_not_null(_tuning(), "player_tuning.tres loads as a PlayerTuning")


func test_validated_movement_values() -> void:
	var t := _tuning()
	assert_almost_eq(t.gravity, 1400.0, 0.001)
	assert_almost_eq(t.max_hspeed, 158.4, 0.001)
	assert_almost_eq(t.jump_strength, 480.0, 0.001)
	assert_almost_eq(t.terminal_fall_speed, 320.0, 0.001)
	assert_almost_eq(t.slide_speed, 400.0, 0.001)


func test_validated_combat_values() -> void:
	var t := _tuning()
	assert_eq(t.max_hp, 5)
	assert_eq(t.max_katana, 3)
	assert_almost_eq(t.hurt_iframe_s, 0.35, 0.0001)


func test_katana_hit_window_invariant() -> void:
	var t := _tuning()
	assert_lt(t.katana_hit_start_s, t.katana_hit_end_s, "hit window: start before end")
	assert_lt(t.katana_hit_end_s, t.katana_swing_duration_s, "hit window must fit inside the swing")
