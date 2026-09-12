class_name BotTuning
extends Resource

# Difficulty changes judgement and timing, never movement speed or weapon damage.
# Arrays are indexed by GENIN, CHUNIN and JONIN.
@export var reaction_s: Array[float] = [0.30, 0.22, 0.16]
@export var perception_s: Array[float] = [0.20, 0.14, 0.10]
@export var plan_min_s: Array[float] = [1.1, 0.9, 0.75]
@export var plan_max_s: Array[float] = [2.0, 1.7, 1.45]
@export var aim_error_px: Array[float] = [32.0, 20.0, 11.0]
@export var aim_windup_s: Array[float] = [0.30, 0.23, 0.17]
@export var throw_cd: Array[float] = [1.25, 0.95, 0.72]
@export var near_range: Array[float] = [100.0, 90.0, 80.0]
@export var far_range: Array[float] = [245.0, 225.0, 205.0]
@export var pressure_chance: Array[float] = [0.22, 0.34, 0.43]
@export var dodge_chance: Array[float] = [0.42, 0.61, 0.76]
@export var dodge_range: Array[float] = [145.0, 175.0, 205.0]
@export var deflect_chance: Array[float] = [0.22, 0.40, 0.57]
@export var guard_chance: Array[float] = [0.45, 0.62, 0.78]
@export var melee_windup: Array[float] = [0.34, 0.26, 0.19]
@export var melee_recovery: Array[float] = [1.05, 0.85, 0.68]
@export var pickup_range: Array[float] = [190.0, 240.0, 290.0]
