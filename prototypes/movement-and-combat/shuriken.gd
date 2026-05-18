# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Shuriken Area2D projectile.
# Two states: Flying (gravity-driven trajectory) and Stuck (rest, pickup-eligible).
# When Flying: detects player overlap → calls Player.hit_by_shuriken.
# When Flying: detects wall overlap → enters Stuck.
# When Stuck: per-tick check for nearby players with stash < 3 → pickup.

extends Area2D

const GRAVITY := 600.0
const TERMINAL := 400.0
const SIZE := Vector2(8.0, 8.0)

var velocity_v: Vector2 = Vector2.ZERO
var stuck: bool = false
var thrower_slot: int = 0
var throw_time: float = 0.0

func _ready() -> void:
	# Build collision shape
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = SIZE
	col.shape = rect
	add_child(col)
	# Build visual
	var vis: ColorRect = ColorRect.new()
	vis.size = SIZE
	vis.position = -SIZE / 2.0
	vis.color = Color(0.95, 0.95, 0.35, 1.0)
	add_child(vis)
	# Hook overlap signals
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if stuck:
		_check_pickup()
		return
	# Flying: integrate
	velocity_v.y += GRAVITY * delta
	velocity_v.y = min(velocity_v.y, TERMINAL)
	position += velocity_v * delta

func _on_body_entered(body: Node) -> void:
	if stuck:
		return
	if body is StaticBody2D:
		# Wall / floor — stick
		stuck = true
		velocity_v = Vector2.ZERO
	elif body is CharacterBody2D and body.has_method("hit_by_shuriken"):
		var should_free: bool = body.hit_by_shuriken(self)
		if should_free:
			queue_free()

func _check_pickup() -> void:
	# Find nearest eligible player within pickup radius
	for p in get_tree().get_nodes_in_group("players"):
		if not p.alive:
			continue
		if p.stash >= 3:
			continue
		if global_position.distance_to(p.global_position) < Combat.pickup_radius_px + 12.0:
			# +12 to account for player half-width
			p.stash += 1
			p.emit_signal("stash_changed", p.slot, p.stash)
			queue_free()
			return
