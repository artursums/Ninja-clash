class_name MovementConfig
extends Resource
## External tuning for Movement (DI'd in; knobs in data not logic). Defaults are the values
## PINNED from the validated prototype + the GDD (see design/gdd/movement.md Tuning Knobs +
## the Prototype Reconciliation block). Wall/drop-through knobs are present for Sprint 2 T5/T6.

# --- Jump (single jump only — no air-jump per the reconciliation) ---
@export var jump_strength: float = 480.0              ## prototype JUMP_STRENGTH

# --- Dodge (the signature verb; i-frame window is the game's key balance lever) ---
@export var dodge_dash_speed: float = 400.0           ## prototype SLIDE_SPEED
@export_range(0.10, 0.30, 0.01) var dodge_iframe_duration_s: float = 0.20
@export_range(0.20, 0.50, 0.01) var dodge_total_duration_s: float = 0.30
@export_range(0.15, 0.40, 0.01) var stick_neutral_threshold: float = 0.25

# --- Comfort ---
@export_range(0.05, 0.15, 0.001) var coyote_time_s: float = 0.083
@export_range(0.05, 0.15, 0.001) var jump_buffer_s: float = 0.083

# --- Wall verbs (Sprint 2 / T5) ---
@export var wall_jump_vertical_strength: float = 350.0
@export var wall_jump_horizontal_kick: float = 180.0
@export var wall_jump_cooldown_s: float = 0.3
@export var wall_slide_max_fall_speed: float = 100.0

# --- Drop-through (Sprint 2 / T6) ---
@export_range(0.35, 0.65, 0.01) var drop_through_threshold: float = 0.5
