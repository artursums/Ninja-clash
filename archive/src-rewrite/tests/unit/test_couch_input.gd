extends GutTest
## Unit tests for Couch Input (src/core/couch_input.gd). Drives the internal event handlers
## directly (no live device, per ADR-0001): slot join/lifecycle, layer gating, gameplay signals,
## stick deadzone, move intent, and menu-nav debounce. The deferred clan-select state machine
## is not covered here (see the SCOPE NOTE in couch_input.gd).

const S := GameStateManager.State

var _fake_time: float = 0.0


func _make_ci() -> CouchInputSystem:
	var ci: CouchInputSystem = autofree(CouchInputSystem.new())
	ci.config = CouchInputConfig.new()
	_fake_time = 1000.0
	ci.time_source = func() -> float: return _fake_time
	return ci   # defaults: layer = MENU, state = BOOT


# --- Slot assignment ------------------------------------------------------------

func test_press_any_button_joins_next_free_slot() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)
	assert_eq(ci.active_slots(), [1] as Array[int], "first joiner takes slot 1")


func test_join_assigns_lowest_free_slot_in_device_order() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)   # slot 1
	ci._on_button_event(3, JOY_BUTTON_A, true)   # slot 2
	assert_eq(ci.active_slots(), [1, 2] as Array[int])


func test_fifth_controller_is_ignored() -> void:
	var ci := _make_ci()
	for device in [10, 11, 12, 13]:
		ci._on_button_event(device, JOY_BUTTON_A, true)
	assert_eq(ci.active_slots(), [1, 2, 3, 4] as Array[int], "four slots filled")
	ci._on_button_event(14, JOY_BUTTON_A, true)   # 5th
	assert_eq(ci.active_slots(), [1, 2, 3, 4] as Array[int], "5th controller ignored")


func test_unassigned_press_in_gameplay_does_not_join() -> void:
	var ci := _make_ci()
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)   # gameplay layer
	ci._on_button_event(7, JOY_BUTTON_A, true)
	assert_eq(ci.active_slots(), [] as Array[int], "joining only happens in the menu layer")


# --- Layer switching + gameplay signal routing ----------------------------------

func test_layer_switches_to_gameplay_only_in_match() -> void:
	var ci := _make_ci()
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	assert_eq(ci.current_layer, CouchInputSystem.Layer.GAMEPLAY)
	ci._on_state_changed(S.IN_MATCH, S.PAUSED)
	assert_eq(ci.current_layer, CouchInputSystem.Layer.MENU, "Paused is a menu layer")


func test_throw_pressed_emits_in_gameplay_with_slot() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)        # join slot 1 (menu)
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)   # gameplay
	watch_signals(ci)
	ci._on_button_event(7, JOY_BUTTON_X, true)
	assert_signal_emitted_with_parameters(ci, "throw_pressed", [1])


func test_primary_action_pressed_in_gameplay() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	watch_signals(ci)
	ci._on_button_event(7, JOY_BUTTON_A, true)
	assert_signal_emitted_with_parameters(ci, "primary_action_pressed", [1])
	assert_true(ci.get_intent(1).primary_held, "primary_held tracks the A button")


func test_a_button_is_menu_confirm_in_menu_layer() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)   # join (consumes this press)
	watch_signals(ci)
	ci._on_button_event(7, JOY_BUTTON_A, true)   # second A in menu → confirm
	assert_signal_emitted_with_parameters(ci, "menu_confirm", [1])


func test_b_button_is_menu_cancel_in_menu_layer() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)   # join
	watch_signals(ci)
	ci._on_button_event(7, JOY_BUTTON_B, true)
	assert_signal_emitted_with_parameters(ci, "menu_cancel", [1])


func test_pause_requested_carries_device_id() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)        # join slot 1
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	watch_signals(ci)
	ci._on_button_event(7, JOY_BUTTON_START, true)
	assert_signal_emitted_with_parameters(ci, "pause_requested", [7])


func test_signals_tagged_with_the_correct_slot() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)   # slot 1
	ci._on_button_event(3, JOY_BUTTON_A, true)   # slot 2
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	watch_signals(ci)
	ci._on_button_event(3, JOY_BUTTON_X, true)   # device 3 = slot 2
	assert_signal_emitted_with_parameters(ci, "throw_pressed", [2], 0)
	assert_signal_emit_count(ci, "throw_pressed", 1, "tagged slot 2 only, not slot 1")


# --- Stick deadzone (pure function) ---------------------------------------------

func test_stick_zero_at_rest() -> void:
	var ci := _make_ci()
	assert_eq(ci._process_stick(Vector2(0.1, 0.0)), Vector2.ZERO, "below deadzone → zero")


func test_stick_full_deflection_is_unit() -> void:
	var ci := _make_ci()
	assert_almost_eq(ci._process_stick(Vector2(1.0, 0.0)).length(), 1.0, 0.001)


func test_stick_scales_smoothly_between() -> void:
	var ci := _make_ci()
	# raw 0.6, deadzone 0.2 → scale (0.6-0.2)/(1-0.2) = 0.5
	assert_almost_eq(ci._process_stick(Vector2(0.6, 0.0)).length(), 0.5, 0.01)


func test_stick_clamps_above_one() -> void:
	var ci := _make_ci()
	assert_almost_eq(ci._process_stick(Vector2(2.0, 0.0)).length(), 1.0, 0.001)


func test_move_intent_from_stick_in_gameplay() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	ci._on_motion_event(7, JOY_AXIS_LEFT_X, 1.0)
	assert_almost_eq(ci.get_intent(1).move.x, 1.0, 0.001)


func test_dpad_overrides_stick_for_move() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	ci._on_motion_event(7, JOY_AXIS_LEFT_X, 0.5)        # partial stick
	ci._on_button_event(7, JOY_BUTTON_DPAD_RIGHT, true) # d-pad wins
	assert_eq(ci.get_intent(1).move, Vector2(1.0, 0.0))


# --- Disconnect / reconnect lifecycle -------------------------------------------

func test_disconnect_in_menu_releases_slot() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)   # slot 1, state BOOT (non-match)
	ci._on_connection_changed(7, false)
	assert_eq(ci.active_slots(), [] as Array[int], "slot released immediately in a non-match state")


func test_disconnect_in_match_reserves_slot_and_signals() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	watch_signals(ci)
	ci._on_connection_changed(7, false)
	assert_eq(ci.active_slots(), [] as Array[int], "device unassigned")
	assert_signal_emitted_with_parameters(ci, "controller_disconnected", [1])
	assert_signal_emitted(ci, "all_controllers_disconnected")


func test_reconnect_reclaims_lowest_reserved_slot() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)        # slot 1
	ci._on_state_changed(S.MATCH_SETUP, S.IN_MATCH)
	ci._on_connection_changed(7, false)               # slot 1 reserved
	ci._on_connection_changed(99, true)               # a different device reconnects
	assert_eq(ci.active_slots(), [1] as Array[int], "new device reclaims reserved slot 1")


# --- Menu navigation debounce ---------------------------------------------------

func test_menu_direction_is_debounced() -> void:
	var ci := _make_ci()
	ci._on_button_event(7, JOY_BUTTON_A, true)   # join slot 1 (menu layer)
	watch_signals(ci)
	ci._on_button_event(7, JOY_BUTTON_DPAD_RIGHT, true)    # first → emits
	ci._on_button_event(7, JOY_BUTTON_DPAD_RIGHT, false)   # release
	ci._on_button_event(7, JOY_BUTTON_DPAD_RIGHT, true)    # within debounce → swallowed
	assert_signal_emit_count(ci, "menu_direction", 1, "second press within debounce is swallowed")
	_fake_time += 0.3                                       # past 0.25 s window
	ci._on_button_event(7, JOY_BUTTON_DPAD_RIGHT, false)
	ci._on_button_event(7, JOY_BUTTON_DPAD_RIGHT, true)    # now eligible again
	assert_signal_emit_count(ci, "menu_direction", 2)
