extends GutTest
## Unit tests for Movement (src/gameplay/player_movement.gd). Movement is driven against a STUB
## body (no physics needed, per the DI design): the stub records the CC commands Movement issues
## and exposes controllable is_on_floor / is_stationary / velocity. Covers walk, the A-button
## decision tree (reconciled: NO double jump), dodge + i-frame timing, jump-cut, coyote, and
## jump-buffer. Wall-jump (T5) and drop-through (T6) are not implemented yet.


## Records the commands Movement issues; lets the test control the body's reported state.
class StubBody:
	extends RefCounted
	var velocity := Vector2.ZERO
	var config := CharacterControllerConfig.new()
	var floor_state := false
	var stationary_state := false
	var jumps: Array = []
	var dodges: Array = []
	var cancels := 0
	var hintents: Array = []
	func is_on_floor() -> bool: return floor_state
	func is_stationary() -> bool: return stationary_state
	func apply_jump_impulse(s: float) -> void: jumps.append(s)
	func apply_dodge_impulse(d: Vector2, s: float) -> void: dodges.append({"dir": d, "speed": s})
	func cancel_jump() -> void: cancels += 1
	func set_horizontal_intent(v: float) -> void: hintents.append(v)


var _t: float = 0.0


func _make(stub: StubBody) -> PlayerMovement:
	var mv: PlayerMovement = autofree(PlayerMovement.new())
	mv.cc = stub
	mv.config = MovementConfig.new()
	_t = 1000.0
	mv.time_source = func() -> float: return _t
	return mv


# --- Walk ----------------------------------------------------------------------

func test_walk_sets_scaled_horizontal_intent() -> void:
	var stub := StubBody.new()
	var mv := _make(stub)
	mv._tick(1.0 / 60.0, Vector2(1.0, 0.0), false)
	assert_almost_eq(stub.hintents.back(), stub.config.max_hspeed_px_s, 0.001, "intent = stick.x * MAX_HSPEED")


func test_facing_follows_stick() -> void:
	var stub := StubBody.new()
	var mv := _make(stub)
	mv._tick(1.0 / 60.0, Vector2(-1.0, 0.0), false)
	assert_eq(mv.facing, -1)


# --- A-button decision tree ----------------------------------------------------

func test_ground_jump_when_on_floor_and_moving() -> void:
	var stub := StubBody.new()
	stub.floor_state = true
	stub.stationary_state = false
	var mv := _make(stub)
	mv.on_primary_action()
	assert_eq(stub.jumps, [480.0], "ground-jump at pinned JUMP_STRENGTH")
	assert_eq(stub.dodges.size(), 0)


func test_dodge_when_stationary() -> void:
	var stub := StubBody.new()
	stub.floor_state = true
	stub.stationary_state = true
	var mv := _make(stub)
	mv.on_primary_action()
	assert_eq(stub.dodges.size(), 1)
	assert_almost_eq((stub.dodges[0]["dir"] as Vector2).x, 1.0, 0.001, "neutral stick → dash in facing dir")
	assert_almost_eq(stub.dodges[0]["speed"], 400.0, 0.001)
	assert_eq(stub.jumps.size(), 0, "stationary A is a dodge, not a jump")


func test_dodge_direction_follows_stick() -> void:
	var stub := StubBody.new()
	stub.stationary_state = true
	var mv := _make(stub)
	mv._last_move = Vector2(0.0, -1.0)   # holding up
	mv.on_primary_action()
	assert_almost_eq((stub.dodges[0]["dir"] as Vector2).y, -1.0, 0.001, "dash straight up")


func test_no_double_jump_airborne_buffers_instead() -> void:
	var stub := StubBody.new()
	stub.floor_state = false
	stub.stationary_state = false
	var mv := _make(stub)
	mv.on_primary_action()
	assert_eq(stub.jumps.size(), 0, "no air-jump — double jump is cut")
	assert_gt(mv._jump_buffer_remaining, 0.0, "airborne press is buffered")


# --- Dodge timing windows ------------------------------------------------------

func test_iframe_is_subset_of_dodging_window() -> void:
	var stub := StubBody.new()
	stub.stationary_state = true
	var mv := _make(stub)
	mv.on_primary_action()                 # dodge at t=1000.0
	assert_true(mv.is_iframe_active(), "i-frames active at dodge start")
	assert_true(mv.is_dodging())
	_t = 1000.25                            # past 0.20 i-frame, within 0.30 total
	assert_false(mv.is_iframe_active(), "i-frames ended")
	assert_true(mv.is_dodging(), "still locked in dodge recovery")
	_t = 1000.35                            # past total
	assert_false(mv.is_dodging())


func test_cannot_redodge_while_dodging() -> void:
	var stub := StubBody.new()
	stub.stationary_state = true
	var mv := _make(stub)
	mv.on_primary_action()
	mv.on_primary_action()                 # still dodging → ignored
	assert_eq(stub.dodges.size(), 1)
	assert_eq(stub.jumps.size(), 0)


# --- Jump-cut ------------------------------------------------------------------

func test_jump_cut_when_rising_and_released() -> void:
	var stub := StubBody.new()
	stub.velocity = Vector2(0.0, -300.0)   # rising
	var mv := _make(stub)
	mv._tick(1.0 / 60.0, Vector2.ZERO, false)   # A not held
	assert_eq(stub.cancels, 1)


func test_no_jump_cut_when_held() -> void:
	var stub := StubBody.new()
	stub.velocity = Vector2(0.0, -300.0)
	var mv := _make(stub)
	mv._tick(1.0 / 60.0, Vector2.ZERO, true)    # A held
	assert_eq(stub.cancels, 0)


# --- Comfort: coyote + jump buffer ---------------------------------------------

func test_coyote_allows_ground_jump_after_walking_off() -> void:
	var stub := StubBody.new()
	var mv := _make(stub)
	stub.floor_state = true
	mv._tick(1.0 / 60.0, Vector2.ZERO, false)   # establish on-floor
	stub.floor_state = false
	mv._tick(1.0 / 60.0, Vector2.ZERO, false)   # walk off the ledge → coyote granted
	stub.stationary_state = false
	mv.on_primary_action()                       # within coyote window
	assert_eq(stub.jumps, [480.0], "coyote ground-jump fires while airborne")


func test_jump_buffer_fires_on_landing() -> void:
	var stub := StubBody.new()
	stub.floor_state = false
	stub.stationary_state = false
	var mv := _make(stub)
	mv.on_primary_action()                       # airborne press → buffered
	stub.floor_state = true
	mv._tick(1.0 / 60.0, Vector2.ZERO, false)    # landing → buffered jump fires
	assert_eq(stub.jumps.size(), 1)


# --- Death ---------------------------------------------------------------------

func test_set_dead_suppresses_all_input() -> void:
	var stub := StubBody.new()
	stub.floor_state = true
	stub.stationary_state = true
	var mv := _make(stub)
	mv.set_dead()
	mv.on_primary_action()
	mv._tick(1.0 / 60.0, Vector2(1.0, 0.0), false)
	assert_eq(stub.dodges.size(), 0)
	assert_eq(stub.jumps.size(), 0)
	assert_eq(stub.hintents.size(), 0, "dead body issues no movement intent")
