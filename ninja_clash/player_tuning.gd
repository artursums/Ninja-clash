class_name PlayerTuning
extends Resource
## Data-driven gameplay tuning for the player (movement + katana/HP feel). Extracted from
## player.gd's hardcoded consts so balance is editable in the inspector and injectable in tests.
## Defaults below are the VALIDATED prototype numbers — editing player_tuning.tres changes balance
## without touching code. (Structural values — hitbox size, sprite frame indices — stay as consts
## in player.gd; they are not balance knobs.)

# --- Movement ---
@export var max_hspeed: float = 158.4
@export var jump_strength: float = 480.0
@export var gravity: float = 1400.0
@export var terminal_fall_speed: float = 320.0
@export var stomp_bounce_strength: float = 260.0       # upward pop the stomper gets off a head
@export var stomp_bounce_sideways: float = 150.0       # sideways shove away from the victim (anti-perch)
@export var stomp_bounce_lock_s: float = 0.12          # how long that sideways shove resists input
@export var stomp_cooldown_s: float = 0.45             # stomper can't stomp again within this window
@export var shuriken_pogo_bounce: float = 240.0
@export var down_throw_speed: float = 720.0
@export var shuriken_throw_recoil: float = 260.0
@export var death_knockback: float = 90.0
@export var death_topple_rate: float = 5.0

# --- Dodge / slide ---
@export var dodge_total_duration_s: float = 0.30
@export var slide_speed: float = 400.0
@export var slide_duration_s: float = 0.20
@export var slide_cooldown_s: float = 0.417
@export var slide_air_refresh_s: float = 0.5
@export var double_tap_window_s: float = 0.25

# --- Wall jump ---
@export var wall_jump_vstrength: float = 540.0
@export var wall_jump_hkick: float = 200.0
@export var wall_jump_lock_s: float = 0.10

# --- HP + katana melee ---
@export var max_hp: int = 5
@export var max_katana: int = 3
@export var start_shurikens: int = 3   # shurikens a fighter spawns holding (stash cap stays 5)
@export var hurt_iframe_s: float = 0.35
@export var katana_swing_duration_s: float = 0.32
@export var katana_cooldown_s: float = 0.2
@export var katana_hit_start_s: float = 0.05
@export var katana_hit_end_s: float = 0.22
@export var katana_range: float = 30.0
@export var katana_half_h: float = 18.0
@export var katana_visual_scale: float = 1.0
@export var katana_hit_knockback: float = 150.0
@export var katana_hit_pop: float = 70.0
@export var katana_hit_recoil_s: float = 0.10
