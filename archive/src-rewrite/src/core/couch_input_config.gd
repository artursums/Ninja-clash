class_name CouchInputConfig
extends Resource
## External, editable tuning for Couch Input (DI'd into the system so knobs live in data, not
## logic — satisfies the GDD Tuning Knobs table + the "tuning knobs in config" code-hygiene
## criterion). Default instance: src/core/couch_input_config.tres. Tests inject their own.

## Radial stick deadzone: below this magnitude, stick input is treated as zero. GDD range 0.15–0.30.
@export_range(0.15, 0.30, 0.01) var deadzone: float = 0.20

## Menu navigation debounce window, seconds — caps held-D-pad cycling. GDD range 0.15–0.40.
@export_range(0.15, 0.40, 0.01) var menu_nav_debounce_s: float = 0.25

## Analog magnitude that triggers a discrete menu_direction on a rising edge. GDD range 0.35–0.65.
@export_range(0.35, 0.65, 0.01) var menu_discrete_threshold: float = 0.5

## Hard player cap. Hard-locked to 4 in v1 (below 4 breaks MatchSetup logic).
@export var max_controllers: int = 4

## Reconnect-priority mode. Only "lowest_reserved" is implemented in v1.
@export var slot_reconnect_priority_mode: StringName = &"lowest_reserved"

## Dev-only keyboard fallback. Disabled in shipping builds.
@export var debug_keyboard_input: bool = false
