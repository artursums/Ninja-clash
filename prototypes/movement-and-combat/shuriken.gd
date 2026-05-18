# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Shuriken Area2D — sprite-based 4-pointed star, spins while flying.
# Tinted with thrower's clan color (from GameState).

extends Area2D

const GRAVITY := 600.0
const TERMINAL := 400.0
const SPIN_RATE_RAD_S := 18.0
const HITBOX_SIZE := Vector2(10.0, 10.0)

var velocity_v: Vector2 = Vector2.ZERO
var stuck: bool = false
var thrower_slot: int = 0
var throw_time: float = 0.0
var _sprite: Sprite2D = null

func _ready() -> void:
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = HITBOX_SIZE
	col.shape = rect
	add_child(col)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://sprites/shuriken.svg")
	_sprite.centered = true
	# Tint sprite with thrower's clan color (slightly brightened so it pops)
	var clan: Dictionary = GameState.get_clan(thrower_slot)
	_sprite.modulate = Color(clan.color).lightened(0.25)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Freeze during non-round states (countdown, round-end pause)
	if not GameState.is_round_active():
		return
	if stuck:
		_check_pickup()
		return
	velocity_v.y += GRAVITY * delta
	velocity_v.y = min(velocity_v.y, TERMINAL)
	position += velocity_v * delta
	# Screen wrap (TowerFall) — shurikens wrap too, so nothing is lost in the chasm
	if position.y > 470.0:
		position.y = -16.0
	elif position.y < -60.0:
		position.y = 460.0
	if _sprite != null:
		_sprite.rotation += SPIN_RATE_RAD_S * delta

func _on_body_entered(body: Node) -> void:
	if stuck:
		return
	if not GameState.is_round_active():
		return
	if body is CharacterBody2D and body.has_method("hit_by_shuriken"):
		var should_free: bool = body.hit_by_shuriken(self)
		if should_free:
			queue_free()
		return
	if body is StaticBody2D:
		# About to stick — check for overlapping players first (player kill wins)
		for overlapping in get_overlapping_bodies():
			if overlapping == body:
				continue
			if overlapping is CharacterBody2D and overlapping.has_method("hit_by_shuriken"):
				var should_free: bool = overlapping.hit_by_shuriken(self)
				if should_free:
					queue_free()
					return
		stuck = true
		velocity_v = Vector2.ZERO
		if _sprite != null:
			_sprite.rotation = randf_range(-0.35, 0.35)

func _check_pickup() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if not p.alive:
			continue
		if p.stash >= 3:
			continue
		if global_position.distance_to(p.global_position) < Combat.pickup_radius_px + 12.0:
			p.stash += 1
			p.stash_changed.emit(p.slot, p.stash)
			queue_free()
			return
