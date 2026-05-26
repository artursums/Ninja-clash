extends GutTest
## Unit tests for the Game State Manager (src/core/game_state_manager.gd).
## Covers the GDD acceptance criteria: every transition, signal ordering, pause + debounce,
## auto-pause, Settings return, and the MatchContext lifecycle. The GSM is exercised as a plain
## instance (not the autoload) with injected clock + pause sink — no live device or SceneTree,
## per ADR-0001 (input/state separation makes this testable).

const GSM := preload("res://src/core/game_state_manager.gd")
const S := GameStateManager.State   # enum alias for terser tests

var _pause_calls: Array = []
var _fake_time: float = 0.0


func _make_gsm() -> GameStateManager:
	var gsm: GameStateManager = autofree(GameStateManager.new())
	gsm.config = GameStateConfig.new()
	_fake_time = 1000.0
	gsm.time_source = func() -> float: return _fake_time
	_pause_calls = []
	gsm.pause_sink = func(p: bool) -> void: _pause_calls.append(p)
	return gsm


# --- State machine basics -------------------------------------------------------

func test_initial_state_is_boot() -> void:
	var gsm := _make_gsm()
	assert_eq(gsm.current_state, S.BOOT, "GSM starts in Boot")


func test_all_seven_states_reachable_from_boot() -> void:
	var gsm := _make_gsm()
	var visited := {S.BOOT: true}
	gsm.state_changed.connect(func(_f: int, t: int) -> void: visited[t] = true)
	assert_true(gsm.request_transition(S.MAIN_MENU))
	assert_true(gsm.request_transition(S.SETTINGS))
	assert_true(gsm.request_transition(S.MAIN_MENU))   # Settings returns to MainMenu
	assert_true(gsm.request_transition(S.MATCH_SETUP))
	assert_true(gsm.request_transition(S.IN_MATCH))
	assert_true(gsm.request_transition(S.PAUSED))
	assert_true(gsm.request_transition(S.IN_MATCH))
	assert_true(gsm.request_transition(S.MATCH_END))
	assert_eq(visited.size(), 7, "all 7 states reached via valid paths from Boot")


func test_invalid_transition_returns_false_and_does_not_change_state() -> void:
	var gsm := _make_gsm()
	assert_false(gsm.request_transition(S.IN_MATCH), "BOOT -> IN_MATCH is invalid")
	assert_eq(gsm.current_state, S.BOOT, "state unchanged after invalid request")


func test_signal_order_state_changing_before_mutation_changed_after() -> void:
	var gsm := _make_gsm()
	var log: Array = []
	gsm.state_changing.connect(func(_f: int, _t: int) -> void: log.append(["changing", gsm.current_state]))
	gsm.state_changed.connect(func(_f: int, _t: int) -> void: log.append(["changed", gsm.current_state]))
	gsm.request_transition(S.MAIN_MENU)
	assert_eq(log.size(), 2, "both signals fired once")
	assert_eq(log[0][0], "changing")
	assert_eq(log[0][1], S.BOOT, "current_state still BOOT when state_changing fires")
	assert_eq(log[1][0], "changed")
	assert_eq(log[1][1], S.MAIN_MENU, "current_state is MAIN_MENU when state_changed fires")


func test_reentrant_transition_is_rejected() -> void:
	var gsm := _make_gsm()
	gsm.request_transition(S.MAIN_MENU)
	var reentrant := [true]
	gsm.state_changing.connect(
		func(_f: int, _t: int) -> void: reentrant[0] = gsm.request_transition(S.IN_MATCH),
		CONNECT_ONE_SHOT
	)
	gsm.request_transition(S.MATCH_SETUP)   # fires state_changing → re-entrant attempt inside
	assert_false(reentrant[0], "re-entrant request_transition must be rejected")
	assert_eq(gsm.current_state, S.MATCH_SETUP, "outer transition still completed")


func test_transition_latency_under_one_frame() -> void:
	var gsm := _make_gsm()
	var start := Time.get_ticks_usec()
	gsm.request_transition(S.MAIN_MENU)
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
	assert_lt(elapsed_ms, 16.6, "a transition completes within one 60fps frame")


# --- Pause / unpause / debounce -------------------------------------------------

func test_pause_from_inmatch_pauses_and_freezes_sim() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.IN_MATCH
	assert_true(gsm.request_pause(1))
	assert_eq(gsm.current_state, S.PAUSED)
	assert_eq(_pause_calls, [true], "simulation frozen on pause")


func test_unpause_resumes_and_unfreezes() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.IN_MATCH
	gsm.request_pause(1)
	_fake_time += 2.0   # advance past the debounce window
	assert_true(gsm.request_unpause(1))
	assert_eq(gsm.current_state, S.IN_MATCH)
	assert_eq(_pause_calls, [true, false], "simulation resumed on unpause")


func test_pause_rejected_outside_inmatch_silently() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.MAIN_MENU
	assert_false(gsm.request_pause(1))
	assert_eq(gsm.current_state, S.MAIN_MENU)
	assert_eq(_pause_calls, [], "no pause side effect from an invalid pause request")


func test_debounce_blocks_same_controller_within_window() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.IN_MATCH
	assert_true(gsm.request_pause(1))               # records t for controller 1
	assert_false(gsm.request_unpause(1), "same controller within debounce window is rejected")
	assert_eq(gsm.current_state, S.PAUSED, "still paused")


func test_debounce_allows_different_controller() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.IN_MATCH
	assert_true(gsm.request_pause(1))
	assert_true(gsm.request_unpause(2), "a different controller is not debounced")
	assert_eq(gsm.current_state, S.IN_MATCH)


# --- Auto-pause -----------------------------------------------------------------

func test_auto_pause_when_all_controllers_disconnected() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.IN_MATCH
	assert_true(gsm.notify_all_controllers_disconnected())
	assert_eq(gsm.current_state, S.PAUSED)
	assert_eq(_pause_calls, [true])


func test_auto_pause_disabled_by_config() -> void:
	var gsm := _make_gsm()
	gsm.config.auto_pause_on_all_controllers_unplugged = false
	gsm.current_state = S.IN_MATCH
	assert_false(gsm.notify_all_controllers_disconnected())
	assert_eq(gsm.current_state, S.IN_MATCH)


# --- Settings return ------------------------------------------------------------

func test_settings_returns_to_origin_and_blocks_other_exits() -> void:
	var gsm := _make_gsm()
	gsm.request_transition(S.MAIN_MENU)
	assert_true(gsm.request_transition(S.SETTINGS))
	assert_eq(gsm.return_to_state, S.MAIN_MENU, "remembers where it was entered from")
	assert_false(gsm.request_transition(S.MATCH_END), "Settings exits only to its origin")
	assert_true(gsm.request_transition(S.MAIN_MENU))
	assert_eq(gsm.current_state, S.MAIN_MENU)


func test_settings_from_paused_returns_to_paused() -> void:
	var gsm := _make_gsm()
	gsm.current_state = S.PAUSED
	assert_true(gsm.request_transition(S.SETTINGS))
	assert_eq(gsm.return_to_state, S.PAUSED)
	assert_true(gsm.request_transition(S.PAUSED))
	assert_eq(gsm.current_state, S.PAUSED)


# --- MatchContext lifecycle -----------------------------------------------------

func test_match_context_created_on_match_setup_not_before() -> void:
	var gsm := _make_gsm()
	gsm.request_transition(S.MAIN_MENU)
	assert_null(gsm.match_context, "no context before MatchSetup")
	gsm.request_transition(S.MATCH_SETUP)
	assert_not_null(gsm.match_context, "context created on entry to MatchSetup")


func test_match_context_persists_through_inmatch_and_matchend() -> void:
	var gsm := _make_gsm()
	gsm.request_transition(S.MAIN_MENU)
	gsm.request_transition(S.MATCH_SETUP)
	var ctx := gsm.match_context
	gsm.request_transition(S.IN_MATCH)
	assert_true(gsm.match_context == ctx, "same context during InMatch")
	gsm.request_transition(S.MATCH_END)
	assert_true(gsm.match_context == ctx, "same context during MatchEnd")


func test_play_again_preserves_match_context() -> void:
	var gsm := _make_gsm()
	gsm.request_transition(S.MAIN_MENU)
	gsm.request_transition(S.MATCH_SETUP)
	gsm.request_transition(S.IN_MATCH)
	gsm.request_transition(S.MATCH_END)
	var ctx := gsm.match_context
	gsm.request_transition(S.MATCH_SETUP)   # "Play Again"
	assert_true(gsm.match_context == ctx, "Play Again reuses the same MatchContext")


func test_back_to_menu_discards_match_context() -> void:
	var gsm := _make_gsm()
	gsm.request_transition(S.MAIN_MENU)
	gsm.request_transition(S.MATCH_SETUP)
	gsm.request_transition(S.IN_MATCH)
	gsm.request_transition(S.MATCH_END)
	gsm.request_transition(S.MAIN_MENU)     # "Back to Menu"
	assert_null(gsm.match_context, "context discarded on return to MainMenu")
