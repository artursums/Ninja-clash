class_name PlayerCharacterBody
extends CharacterBody2D
## The physics primitive layer for a player (design/gdd/character-controller.md). It applies
## gravity + horizontal-intent interpolation each tick, resolves collision against the Map, wraps
## across screen edges, and exposes state queries. It defines NO verbs — Movement composes verbs
## by calling the command methods and reading the state queries. One instance per active slot.
##
## Per ADR-0001 this reads NO input directly — Movement (driven by CouchInput intent) drives it.

# --- Collision layers (1-based indices; GDD Core Rule 8). No magic numbers elsewhere. ---
const LAYER_PLAYER := 1
const LAYER_WALL := 2
const LAYER_ONEWAY := 3
const LAYER_PROJECTILE := 4

## Injected tuning (DI). Round Flow loads the .tres and injects before adding to the tree.
var config: CharacterControllerConfig = CharacterControllerConfig.new()
## The current map — used for screen-wrap. Set by Round Flow on spawn. Null = no wrap.
var map: MapResource = null
## Immutable slot identity (1-4), set by Round Flow at instantiation. Read by Combat (GDD Rule 14).
var slot: int = 0

var _horizontal_intent: float = 0.0
var _drop_through_active: bool = false


func _ready() -> void:
	# Player on its own layer; collides with walls, one-ways, and projectiles — never other players.
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(LAYER_PLAYER, true)
	set_collision_mask_value(LAYER_WALL, true)
	set_collision_mask_value(LAYER_ONEWAY, true)
	set_collision_mask_value(LAYER_PROJECTILE, true)
	_build_collision_shape()


func _physics_process(delta: float) -> void:
	step(delta)


## One integration tick. Public so Movement can drive it explicitly if it disables auto-physics.
func step(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_intent(delta)
	move_and_slide()
	_apply_screen_wrap()
	# Drop-through is self-resetting: re-enable one-way collision the tick after it was requested.
	if _drop_through_active:
		set_collision_mask_value(LAYER_ONEWAY, true)
		_drop_through_active = false


# === Movement commands (called by Movement; CC is "dumb" — it does not gate them) ===

## Target horizontal velocity (px/s). Defensively sanitised + clamped to [-max, +max].
func set_horizontal_intent(v: float) -> void:
	if is_nan(v) or is_inf(v):
		v = 0.0
	_horizontal_intent = clampf(v, -config.max_hspeed_px_s, config.max_hspeed_px_s)


## Launch upward: sets vertical velocity to -strength this tick (no is_on_floor check — Movement gates).
func apply_jump_impulse(strength: float) -> void:
	velocity.y = -strength


## Jump-cut: clamp upward velocity when A is released mid-rise. No-op while falling.
func cancel_jump() -> void:
	if velocity.y < -config.jump_cut_velocity_px_s:
		velocity.y = -config.jump_cut_velocity_px_s


## Dodge dash: drive the whole velocity vector. Movement decides the direction (ZERO → no motion).
func apply_dodge_impulse(direction: Vector2, strength: float) -> void:
	velocity = direction.normalized() * strength


## Set vertical velocity directly (e.g. Movement's wall-slide cap).
func set_vertical_velocity(v: float) -> void:
	velocity.y = v


## Fall through one-way platforms for one physics tick (self-resetting; see step()).
func drop_through_request() -> void:
	_drop_through_active = true
	set_collision_mask_value(LAYER_ONEWAY, false)


# === State queries (consumed by Movement / Visual FX) ===

## Wall side touched: (-1,0)=left wall, (+1,0)=right wall (points TOWARD the wall, per GDD Rule 9 —
## the negation of Godot's surface normal, which points away).
func wall_normal() -> Vector2:
	return -get_wall_normal()


## On floor + horizontal velocity below the stationary threshold (used for A-as-dodge resolution).
func is_stationary() -> bool:
	return is_on_floor() and absf(velocity.x) < config.stationary_threshold_px_s


# === Internal integration steps (factored out so the math is unit-testable off the tree) ===

func _apply_gravity(delta: float) -> void:
	velocity.y += config.gravity_px_s2 * delta
	velocity.y = minf(velocity.y, config.terminal_velocity_px_s)


func _apply_horizontal_intent(delta: float) -> void:
	var target := clampf(_horizontal_intent, -config.max_hspeed_px_s, config.max_hspeed_px_s)
	var diff := target - velocity.x
	var step_amount := signf(diff) * minf(absf(diff), config.horizontal_accel_px_s2 * delta)
	velocity.x += step_amount


func _apply_screen_wrap() -> void:
	if map == null:
		return
	global_position = ScreenWrap.wrap_position(global_position, map)


func _build_collision_shape() -> void:
	if get_node_or_null(^"CollisionShape2D") != null:
		return
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(config.hitbox_width, config.hitbox_height)
	cs.shape = rect
	add_child(cs)
