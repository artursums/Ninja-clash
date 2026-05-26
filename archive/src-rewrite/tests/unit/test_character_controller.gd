extends GutTest
## Tests for the Character Controller (src/core/player_character_body.gd). The physics MATH is
## unit-tested off the tree (gravity, intent interpolation, jump-cut, impulses, screen-wrap). One
## integration test adds a body to the live tree on the flat arena to verify real collision/landing.

const FLAT_ARENA := "res://src/gameplay/maps/flat_arena.tscn"


func _make_cc() -> PlayerCharacterBody:
	var cc: PlayerCharacterBody = autofree(PlayerCharacterBody.new())
	cc.config = CharacterControllerConfig.new()
	return cc


# --- Gravity -------------------------------------------------------------------

func test_gravity_accumulates() -> void:
	var cc := _make_cc()
	cc._apply_gravity(0.1)
	assert_almost_eq(cc.velocity.y, 120.0, 0.001, "1200 px/s² over 0.1 s")


func test_gravity_capped_at_terminal() -> void:
	var cc := _make_cc()
	cc.velocity.y = 590.0
	cc._apply_gravity(0.1)   # would be 710 uncapped
	assert_almost_eq(cc.velocity.y, 600.0, 0.001, "capped at terminal velocity")


# --- Horizontal intent ---------------------------------------------------------

func test_horizontal_converges_toward_intent() -> void:
	var cc := _make_cc()
	cc.set_horizontal_intent(120.0)
	cc._apply_horizontal_intent(1.0 / 60.0)   # one tick: step = 3000/60 = 50
	assert_almost_eq(cc.velocity.x, 50.0, 0.5)
	for _i in 10:
		cc._apply_horizontal_intent(1.0 / 60.0)
	assert_almost_eq(cc.velocity.x, 120.0, 0.001, "reaches target after a few ticks")


func test_horizontal_intent_clamped_to_max() -> void:
	var cc := _make_cc()
	cc.set_horizontal_intent(99999.0)
	assert_almost_eq(cc._horizontal_intent, 120.0, 0.001, "intent clamped to max_hspeed")


func test_horizontal_intent_nan_is_sanitised() -> void:
	var cc := _make_cc()
	cc.set_horizontal_intent(NAN)
	assert_eq(cc._horizontal_intent, 0.0, "NaN intent sanitised to 0")


# --- Jump / jump-cut / impulses ------------------------------------------------

func test_apply_jump_impulse_sets_upward_velocity() -> void:
	var cc := _make_cc()
	cc.apply_jump_impulse(480.0)
	assert_eq(cc.velocity.y, -480.0, "negative = up")


func test_cancel_jump_clamps_when_rising() -> void:
	var cc := _make_cc()
	cc.velocity.y = -480.0
	cc.cancel_jump()
	assert_eq(cc.velocity.y, -200.0, "clamped to jump-cut velocity")


func test_cancel_jump_noop_when_falling() -> void:
	var cc := _make_cc()
	cc.velocity.y = 300.0
	cc.cancel_jump()
	assert_eq(cc.velocity.y, 300.0, "no effect while falling")


func test_cancel_jump_noop_when_already_slow_rise() -> void:
	var cc := _make_cc()
	cc.velocity.y = -100.0   # already below the cut threshold magnitude
	cc.cancel_jump()
	assert_eq(cc.velocity.y, -100.0)


func test_apply_dodge_impulse_drives_whole_vector() -> void:
	var cc := _make_cc()
	cc.apply_dodge_impulse(Vector2(1.0, 0.0), 400.0)
	assert_almost_eq(cc.velocity.x, 400.0, 0.001)
	assert_almost_eq(cc.velocity.y, 0.0, 0.001)


func test_set_vertical_velocity() -> void:
	var cc := _make_cc()
	cc.set_vertical_velocity(-300.0)
	assert_eq(cc.velocity.y, -300.0)


# --- Screen-wrap ---------------------------------------------------------------

func test_screen_wrap_horizontal() -> void:
	var cc := _make_cc()
	cc.map = _wrap_map(true, false)
	cc.global_position = Vector2(-5.0, 100.0)
	cc._apply_screen_wrap()
	assert_almost_eq(cc.global_position.x, 475.0, 0.001)
	assert_almost_eq(cc.global_position.y, 100.0, 0.001, "vertical wrap off → y unchanged")


func test_screen_wrap_noop_without_map() -> void:
	var cc := _make_cc()
	cc.map = null
	cc.global_position = Vector2(-5.0, 100.0)
	cc._apply_screen_wrap()
	assert_almost_eq(cc.global_position.x, -5.0, 0.001, "no map → no wrap")


# --- Integration: real collision against the flat arena ------------------------

func test_body_falls_and_lands_on_flat_arena() -> void:
	var arena: Node = autofree((load(FLAT_ARENA) as PackedScene).instantiate())
	add_child(arena)
	var cc := PlayerCharacterBody.new()
	arena.add_child(cc)
	cc.global_position = Vector2(240.0, 200.0)   # above the floor (top at y≈254)
	await wait_seconds(0.7)                       # ~42 physics ticks — long enough to fall + settle
	assert_true(cc.is_on_floor(), "body lands on the solid floor")
	assert_between(cc.global_position.y, 244.0, 248.0, "rests with its 16px-tall hitbox on the floor")
	cc.queue_free()


func _wrap_map(h: bool, v: bool) -> MapResource:
	var m := MapResource.new()
	m.horizontal_wrap = h
	m.vertical_wrap = v
	m.playfield_width = 480.0
	m.playfield_height = 270.0
	return m
