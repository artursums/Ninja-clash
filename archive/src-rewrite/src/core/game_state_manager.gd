class_name GameStateManager
extends Node
## Top-level state machine for Four Clans. Owns the canonical game state, every transition
## between states, the per-match MatchContext, and pause/unpause with per-controller debounce.
## Registered as the `GameState` autoload at runtime; also instantiable for unit tests
## (inject `config`, `time_source`, and `pause_sink` — no live device or SceneTree needed).
## See design/gdd/game-state-manager.md.
##
## Per ADR-0001 this system is driven by intent/requests, never by direct device reads.

## The seven top-level modes. Order is referenced by GameStateConfig (kept in sync there):
## BOOT 0 · MAIN_MENU 1 · SETTINGS 2 · MATCH_SETUP 3 · IN_MATCH 4 · PAUSED 5 · MATCH_END 6.
enum State { BOOT, MAIN_MENU, SETTINGS, MATCH_SETUP, IN_MATCH, PAUSED, MATCH_END }

## Pre-transition: fired before current_state changes. Subscribers run cleanup (Core Rule 6).
signal state_changing(from_state: State, to_state: State)
## Post-transition: fired after current_state changes. Subscribers run enter logic (Core Rule 6).
signal state_changed(from_state: State, to_state: State)
## Fired whenever the GSM freezes (true) or unfreezes (false) the simulation.
signal simulation_pause_changed(is_paused: bool)

## Structural transition table — which targets are reachable from each source state.
## Settings entry/exit are further gated below (config.states_permitting_settings + return rule).
const _ALLOWED_TRANSITIONS := {
	State.BOOT: [State.MAIN_MENU],
	State.MAIN_MENU: [State.MATCH_SETUP, State.SETTINGS],
	State.SETTINGS: [State.MAIN_MENU, State.PAUSED, State.MATCH_END],
	State.MATCH_SETUP: [State.IN_MATCH, State.MAIN_MENU],
	State.IN_MATCH: [State.MATCH_END, State.PAUSED],
	State.PAUSED: [State.IN_MATCH, State.MAIN_MENU, State.SETTINGS],
	State.MATCH_END: [State.MATCH_SETUP, State.MAIN_MENU, State.SETTINGS],
}

## Injected tuning (DI). Default is a fresh config; the runtime autoload loads the .tres in _ready.
var config: GameStateConfig = GameStateConfig.new()
## Injected clock (DI) so debounce is testable. Returns seconds.
var time_source: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
## Injected pause hook (DI) so tests never pause the test runner. Default drives SceneTree.paused.
var pause_sink: Callable

var current_state: State = State.BOOT
var match_context: MatchContext = null
var return_to_state: State = State.MAIN_MENU   # where Settings returns to (Core Rule 9)
var boot_failed: bool = false

var _in_transition: bool = false
var _last_pause_request: Dictionary = {}   # controller_id:int -> float (last request time)


func _init() -> void:
	pause_sink = _default_pause_sink


func _ready() -> void:
	# Runtime (autoload) only: load the external config override if present. Unit tests run the
	# class outside the tree, so _ready does not fire and the injected config is preserved.
	var cfg_path := "res://src/core/game_state_config.tres"
	if ResourceLoader.exists(cfg_path):
		var loaded: Resource = load(cfg_path)
		if loaded is GameStateConfig:
			config = loaded


func _default_pause_sink(is_paused: bool) -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = is_paused


## Request a state transition. Returns true if honored. Validates against the transition table
## (+ Settings gating); invalid requests log a warning and change nothing (Core Rule 5).
## Rejects re-entrant calls from a state_changing/-ed subscriber — those must use call_deferred.
func request_transition(target: State) -> bool:
	if _in_transition:
		push_warning("GSM: re-entrant request_transition(%s) rejected; use call_deferred." % State.keys()[target])
		return false
	if not _is_valid_transition(current_state, target):
		push_warning("GSM: invalid transition %s -> %s rejected." % [State.keys()[current_state], State.keys()[target]])
		return false

	_in_transition = true
	var from_state: State = current_state
	state_changing.emit(from_state, target)   # pre: subscribers see the OLD state
	current_state = target
	_apply_enter_effects(from_state, target)
	state_changed.emit(from_state, target)     # post: subscribers see the NEW state
	_in_transition = false
	return true


func _is_valid_transition(from_state: State, target: State) -> bool:
	var allowed: Array = _ALLOWED_TRANSITIONS.get(from_state, [])
	if not allowed.has(target):
		return false
	# Settings is reachable only from configured states (tuning knob).
	if target == State.SETTINGS and not config.states_permitting_settings.has(int(from_state)):
		return false
	# Settings may only exit back to where it was entered from (Core Rule 9).
	if from_state == State.SETTINGS and target != return_to_state:
		return false
	return true


func _apply_enter_effects(from_state: State, to_state: State) -> void:
	# MatchContext lifecycle (Core Rule 3 + acceptance criteria).
	match to_state:
		State.MAIN_MENU:
			match_context = null                       # discard on return to menu
		State.MATCH_SETUP:
			if match_context == null:                   # fresh match; "Play Again" reuses the existing one
				match_context = MatchContext.new()
		State.SETTINGS:
			return_to_state = from_state                # remember where to return
	# Pause control: freeze on entering Paused; unfreeze when leaving Paused for gameplay or menu
	# (but NOT when opening Settings over a paused match — the match stays frozen underneath).
	if to_state == State.PAUSED:
		_set_simulation_paused(true)
	elif from_state == State.PAUSED and (to_state == State.IN_MATCH or to_state == State.MAIN_MENU):
		_set_simulation_paused(false)


func _set_simulation_paused(is_paused: bool) -> void:
	pause_sink.call(is_paused)
	simulation_pause_changed.emit(is_paused)


## Pause request routed from Couch Input — honored only from a pause-permitting state (default
## InMatch) and only past the controller's debounce window. Invalid requests are rejected
## SILENTLY (no log) — pause spam on a couch is expected (Core Rule 7).
func request_pause(controller_id: int) -> bool:
	if not config.states_permitting_pause.has(int(current_state)):
		return false
	if not _pause_eligible(controller_id):
		return false
	_last_pause_request[controller_id] = time_source.call()
	return request_transition(State.PAUSED)


## Unpause request from any controller (also debounced). Honored only from Paused (Core Rule 8).
func request_unpause(controller_id: int) -> bool:
	if current_state != State.PAUSED:
		return false
	if not _pause_eligible(controller_id):
		return false
	_last_pause_request[controller_id] = time_source.call()
	return request_transition(State.IN_MATCH)


func _pause_eligible(controller_id: int) -> bool:
	var last: float = _last_pause_request.get(controller_id, -INF)
	return (time_source.call() - last) >= config.pause_debounce_s


## Called by Couch Input when every controller unplugs during a match. Auto-pauses with a
## synthetic source if the config allows (Edge Case: "dog tripped over the wires"). Bypasses
## debounce — it is not spam. Returns true if it paused.
func notify_all_controllers_disconnected() -> bool:
	if not config.auto_pause_on_all_controllers_unplugged:
		return false
	if current_state != State.IN_MATCH:
		return false
	return request_transition(State.PAUSED)


## The Boot system reports a fatal preload failure: stay in Boot, never advance into a broken
## state; the UI shows a non-dismissible error overlay (Edge Cases).
func report_boot_failure() -> void:
	boot_failed = true
	push_error("GSM: boot failed (asset preload). Staying in Boot; show error overlay.")
