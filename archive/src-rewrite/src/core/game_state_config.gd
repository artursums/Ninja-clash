class_name GameStateConfig
extends Resource
## External, editable tuning for the Game State Manager. Injected into the GSM (DI) so the
## knobs live in data, not in the state-machine logic — satisfies the GDD Tuning Knobs table
## and the "tuning knobs in a config file, not hardcoded" code-hygiene criterion.
## Default instance: src/core/game_state_config.tres. Tests inject their own.

## Per-controller pause/unpause debounce window, in seconds. GDD safe range 0.5–2.0.
@export_range(0.5, 2.0, 0.05) var pause_debounce_s: float = 1.0

## If true, the simulation auto-pauses when every controller is unplugged mid-match.
@export var auto_pause_on_all_controllers_unplugged: bool = true

## States from which a pause request is honored. Values are GameStateManager.State enum ints.
## Default = [IN_MATCH]. (Enum order: BOOT 0, MAIN_MENU 1, SETTINGS 2, MATCH_SETUP 3,
## IN_MATCH 4, PAUSED 5, MATCH_END 6 — kept as ints here to avoid a cyclic class reference.)
@export var states_permitting_pause: Array[int] = [4]

## States from which Settings is reachable. Default = [MAIN_MENU, PAUSED, MATCH_END].
@export var states_permitting_settings: Array[int] = [1, 5, 6]
