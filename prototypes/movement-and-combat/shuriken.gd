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
# Time-scale for shuriken physics. velocity / gravity / terminal stay in original units →
# trajectory SHAPE is preserved exactly; only flight TIME scales (lower = more slow-motion).
# 1.0 = real-time (the design-doc spec, projectile.md Formula 2). 0.525 flies ~1.3× faster
# than the old 0.40 — a quarter slower than the 0.70 trial (~315 px/s effective). Aim-assist
# + spin use the same scaled dt, so the assist curve in SPACE is unchanged. Dial toward 1.0
# for faster, more TowerFall-like arrows.
const FLIGHT_TIME_SCALE: float = 0.525
const HITBOX_SIZE := Vector2(14.0, 14.0)   # aim-assist forgiveness: collision slightly inflated past visible blade

# In-flight steering: subtle curve toward closest enemy in tight forward cone
const AIM_ASSIST_RANGE: float = 200.0          # max distance to assist toward
const AIM_ASSIST_CONE_DEG: float = 18.0        # enemy must be within ±18° of velocity
const AIM_ASSIST_ANGULAR_RATE: float = 0.375   # max rad/s of steering (~21 °/s) — halved again (was 0.75)
const AIM_ASSIST_MIN_SPEED: float = 60.0       # don't assist near-stationary shurikens

var velocity_v: Vector2 = Vector2.ZERO
var stuck: bool = false
var thrower_slot: int = 0
var throw_time: float = 0.0
var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("shurikens")
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
	# All time-based physics use scaled dt so the trajectory plays out in slow motion
	# while keeping the same arc shape (apex, range) as the original speed.
	var dt: float = delta * FLIGHT_TIME_SCALE
	velocity_v.y += GRAVITY * dt
	velocity_v.y = min(velocity_v.y, TERMINAL)
	_apply_aim_assist(dt)
	position += velocity_v * dt
	# Screen wrap — shurikens wrap too, so nothing is lost in the chasm
	if position.y > 470.0:
		position.y = -16.0
	elif position.y < -60.0:
		position.y = 460.0
	if _sprite != null:
		_sprite.rotation += SPIN_RATE_RAD_S * dt

# Subtle in-flight steering: rotate velocity toward closest enemy if they're in a tight forward cone.
# Speed magnitude is preserved (we only rotate direction), so gravity still does its job over time.
func _apply_aim_assist(delta: float) -> void:
	var speed: float = velocity_v.length()
	if speed < AIM_ASSIST_MIN_SPEED:
		return
	var vel_angle: float = velocity_v.angle()
	var best_target = null
	var best_dist: float = AIM_ASSIST_RANGE
	for p in get_tree().get_nodes_in_group("players"):
		if not p.alive or p.slot == thrower_slot:
			continue
		var to_p: Vector2 = p.global_position - global_position
		var d: float = to_p.length()
		if d > AIM_ASSIST_RANGE or d < 6.0:
			continue
		var angle_diff: float = absf(wrapf(to_p.angle() - vel_angle, -PI, PI))
		if rad_to_deg(angle_diff) > AIM_ASSIST_CONE_DEG:
			continue
		if d < best_dist:
			best_dist = d
			best_target = p
	if best_target == null:
		return
	# Rotate velocity toward target by at most AIM_ASSIST_ANGULAR_RATE * delta radians.
	var target_angle: float = (best_target.global_position - global_position).angle()
	var delta_angle: float = wrapf(target_angle - vel_angle, -PI, PI)
	var max_step: float = AIM_ASSIST_ANGULAR_RATE * delta
	var step: float = clamp(delta_angle, -max_step, max_step)
	var new_angle: float = vel_angle + step
	velocity_v = Vector2(cos(new_angle), sin(new_angle)) * speed

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

# Called by a player who hit this shuriken with a katana swing.
# Redirects the shuriken away in the swing direction with an upward arc; it then
# flies off and sticks where it lands so anyone can retrieve it. Ownership transfers
# to the deflector so a deflected kill is credited to them.
func deflect(by_slot: int, by_facing: int) -> void:
	if stuck:
		return
	thrower_slot = by_slot
	velocity_v = Vector2(by_facing * 260.0, -170.0)   # away in swing dir + upward arc
	throw_time = Time.get_ticks_msec() / 1000.0        # fresh immunity window for new owner
	stuck = false
	Audio.play("click")   # metallic ping

func _check_pickup() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if not p.alive:
			continue
		if p.stash >= 5:
			continue
		if global_position.distance_to(p.global_position) < Combat.pickup_radius_px + 12.0:
			p.stash += 1
			p.stash_changed.emit(p.slot, p.stash)
			queue_free()
			return
