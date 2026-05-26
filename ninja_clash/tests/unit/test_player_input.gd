extends GutTest
## Tests for PlayerInputRouter (player_input_router.gd) — the input/state-separation layer.
## We set the captured snapshot directly and verify the intent-building + snapshot reads (the
## online-facing transform), which needs no live device. This is also the first GUT suite in
## ninja_clash, proving the test harness runs here for ongoing hardening.


func _router() -> PlayerInputRouter:
	return autofree(PlayerInputRouter.new())   # not in tree → no auto-capture; we set the snapshot


func test_get_intent_move_x_from_held() -> void:
	var r := _router()
	r._held = {"p1_right": true}
	assert_eq(r.get_intent(1).move.x, 1.0)
	r._held = {"p1_left": true}
	assert_eq(r.get_intent(1).move.x, -1.0)
	r._held = {"p1_left": true, "p1_right": true}
	assert_eq(r.get_intent(1).move.x, 0.0, "opposing inputs cancel")


func test_get_intent_aim_axis_is_y_down() -> void:
	var r := _router()
	r._held = {"p1_aim_up": true}
	assert_eq(r.get_intent(1).move.y, -1.0, "up is negative Y (Godot Y-down)")
	r._held = {"p1_aim_down": true}
	assert_eq(r.get_intent(1).move.y, 1.0)


func test_get_intent_buttons_held_vs_pressed() -> void:
	var r := _router()
	r._held = {"p2_jump": true}
	r._pressed = {"p2_throw": true}
	var i := r.get_intent(2)
	assert_true(i.jump_held)
	assert_false(i.jump_pressed)
	assert_true(i.throw_pressed)
	assert_false(i.throw_held)


func test_get_intent_is_per_slot() -> void:
	var r := _router()
	r._held = {"p1_jump": true}   # slot 1 only
	assert_true(r.get_intent(1).jump_held)
	assert_false(r.get_intent(2).jump_held, "slot 2 not affected by slot 1's input")


func test_held_and_pressed_read_the_snapshot() -> void:
	var r := _router()
	r._held = {"p1_dodge": true}
	r._pressed = {"p1_jump": true}
	assert_true(r.held("p1_dodge"))
	assert_false(r.held("p1_jump"))
	assert_true(r.pressed("p1_jump"))
	assert_false(r.pressed("p1_dodge"))
	assert_false(r.held("p1_unknown"), "unknown action defaults to false")
