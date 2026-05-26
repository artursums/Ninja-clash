class_name CharacterControllerConfig
extends Resource
## External tuning for the Character Controller (DI'd in, so knobs live in data not logic —
## GDD Tuning Knobs + code-hygiene criterion). Defaults are the GDD's PLACEHOLDER values; the
## prototype-validated values get pinned here in Sprint 2 / T4 (Movement) after the playtest.
## See design/gdd/character-controller.md.

@export var gravity_px_s2: float = 1200.0            ## GDD range 800–1600
@export var terminal_velocity_px_s: float = 600.0    ## GDD range 400–800 (positive = down)
@export var max_hspeed_px_s: float = 120.0           ## GDD range 80–200
@export var horizontal_accel_px_s2: float = 3000.0   ## convergence toward intent; GDD 1000–5000
@export var jump_cut_velocity_px_s: float = 200.0    ## upward cap after jump-cut; GDD 100–400
@export var stationary_threshold_px_s: float = 5.0   ## below this |vx| on floor = stationary
@export var hitbox_width: float = 10.0
@export var hitbox_height: float = 16.0
