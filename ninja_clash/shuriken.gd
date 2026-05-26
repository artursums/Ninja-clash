# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the throw-dodge-retrieve loop with 1-hit-kill feel fun in 2P local?
# Date: 2026-05-18
#
# Shuriken Area2D — per-clan colored 9-frame sprite strip.
# Frames cycle a spinning blade while flying, lay a fading comet trail behind it,
# and snap to an impact pose when it sticks. Strip is chosen from the thrower's
# clan color (GameState.get_clan().sprite) — no runtime tint needed.

extends Area2D

const GRAVITY := 600.0
const TERMINAL := 400.0

# --- Sprite sheet: shuriken_<color>_9frame_native_144x16.png ---
# Frames 0-3 spinning blade (loops in flight) · 4-7 fading comet-trail afterimages
# (4 = newest/closest, 7 = oldest/farthest) · 8 = impact / stuck-in-surface pose.
const SHEET_HFRAMES := 9
const SPIN_FRAME_COUNT := 4          # frames 0..3 = one quarter-turn = a full visual spin (4-point star)
const TRAIL_FRAME_BASE := 4          # first trail frame index (stage 1, closest to the blade)
const IMPACT_FRAME := 8
# Spin playback in SCALED flight-time so it stays coupled to the slow-mo flight.
# 46 ≈ the old 18 rad/s feel (~6 visual spins/sec on-screen).
const SPIN_FPS := 46.0
# Comet trail: TRAIL_COUNT afterimages sampled every TRAIL_STRIDE recorded positions back.
const TRAIL_COUNT := 4
const TRAIL_STRIDE := 3
const HISTORY_MAX := TRAIL_STRIDE * TRAIL_COUNT + 1   # 13 positions kept
# Time-scale for shuriken physics. velocity / gravity / terminal stay in original units →
# trajectory SHAPE is preserved exactly; only flight TIME scales (lower = more slow-motion).
# 1.0 = real-time (the design-doc spec, projectile.md Formula 2). 0.525 flies ~1.3× faster
# than the old 0.40 — a quarter slower than the 0.70 trial (~315 px/s effective). Aim-assist
# + spin use the same scaled dt, so the assist curve in SPACE is unchanged. Dial toward 1.0
# for faster, more TowerFall-like arrows.
const FLIGHT_TIME_SCALE: float = 0.4725
const HITBOX_SIZE := Vector2(14.0, 14.0)   # aim-assist forgiveness: collision slightly inflated past visible blade

# In-flight "lazy sight" steering: the blade curves toward the nearest enemy in a WIDE
# forward arc, capped to a gentle turn rate. It re-aims at the foe's CURRENT spot every
# frame, so when they jump or reposition the trajectory adapts and bends after them — but
# the turn cap means a big/sudden dodge (too high, too far) still slips it. Preferential,
# not a homing missile. Direction-agnostic: horizontal, vertical and diagonal throws
# all track the same way.
const AIM_ASSIST_RANGE: float = 300.0          # max distance it will track a foe
const AIM_ASSIST_CONE_DEG: float = 60.0        # foe must be within ±60° of heading (wide enough to follow a jump)
const AIM_ASSIST_ANGULAR_RATE: float = 1.47    # max turn (rad/s, in flight-time) — was 2.1, cut 30% (weaker trajectory assist)
const AIM_ASSIST_MIN_SPEED: float = 60.0       # don't assist a near-stationary blade
const AIM_ASSIST_DURATION: float = 0.8         # only steer for this long after the throw — a blade that has
                                               # been flying/looping for a while flies DUMB (no surprise curves)

var velocity_v: Vector2 = Vector2.ZERO
var max_fall: float = TERMINAL   # per-shuriken vertical-speed cap; a straight-down throw raises it
var stuck: bool = false
var thrower_slot: int = 0
var throw_time: float = 0.0
var consumed: bool = false              # picked up / caught exactly once (guards the deferred-free race)
var ricocheted: bool = false            # bounced in a clash → spent: can't damage, only be caught/passed through
var _clash_cooldown_until: float = 0.0  # brief gap after a shuriken-vs-shuriken clash
var _sprite: Sprite2D = null            # head blade
var _trail: Array = []                  # TRAIL_COUNT afterimage Sprite2D, newest→oldest
var _pos_history: Array = []            # recent global positions, index 0 = most recent
var _spin_t: float = 0.0                # accumulated scaled flight-time → spin frame

func _ready() -> void:
	add_to_group("shurikens")
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = HITBOX_SIZE
	col.shape = rect
	add_child(col)
	_setup_visuals()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)   # shuriken-vs-shuriken clashes

# Load the thrower clan's pre-colored 9-frame strip and build the head blade plus
# the trail afterimages. Falls back to the plain tinted star if the strip is
# somehow missing, so a throw never crashes.
func _setup_visuals() -> void:
	var clan: Dictionary = GameState.get_clan(thrower_slot)
	var sprite_name: String = clan.get("sprite", "cyan")
	var path: String = "res://sprites/shurikens/shuriken_%s_9frame_native_144x16.png" % sprite_name
	if not ResourceLoader.exists(path):
		# Fallback: old single-frame star, tinted (keeps the prototype runnable).
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://sprites/shuriken.svg")
		_sprite.centered = true
		_sprite.modulate = Color(clan.color).lightened(0.25)
		add_child(_sprite)
		return
	var tex: Texture2D = load(path)
	# Trail afterimages added first so they draw UNDER the head blade (sibling order).
	for i in TRAIL_COUNT:
		var t: Sprite2D = Sprite2D.new()
		t.texture = tex
		t.hframes = SHEET_HFRAMES
		t.frame = TRAIL_FRAME_BASE + i      # 4 = closest/brightest … 7 = farthest/faintest
		t.centered = true
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.visible = false                   # shown once enough path history exists
		add_child(t)
		_trail.append(t)
	# Head blade on top.
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = SHEET_HFRAMES
	_sprite.frame = 0
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

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
	velocity_v.y = min(velocity_v.y, max_fall)
	_apply_aim_assist(dt)
	position += velocity_v * dt
	# Screen wrap — shurikens wrap too, so nothing is lost in the chasm. Clearing
	# the path history on a wrap stops the comet trail from streaking across the
	# whole screen between the old and new sides.
	if position.y > 470.0:
		position.y = -16.0
		_pos_history.clear()
	elif position.y < -60.0:
		position.y = 460.0
		_pos_history.clear()
	_advance_spin(dt)
	_record_history()
	_update_trail()

# Cycle the head blade through the 4 spin frames (in scaled flight-time).
func _advance_spin(dt: float) -> void:
	if _sprite == null or _sprite.hframes <= 1:
		return   # fallback star has no spin frames
	_spin_t += dt
	_sprite.frame = int(_spin_t * SPIN_FPS) % SPIN_FRAME_COUNT

func _record_history() -> void:
	_pos_history.push_front(global_position)
	if _pos_history.size() > HISTORY_MAX:
		_pos_history.resize(HISTORY_MAX)

# Park each afterimage at a progressively older recorded position; hide any that
# don't have enough history yet (so the trail fades in after a throw).
func _update_trail() -> void:
	for i in _trail.size():
		var idx: int = TRAIL_STRIDE * (i + 1)
		var t: Sprite2D = _trail[i]
		if idx < _pos_history.size():
			t.global_position = _pos_history[idx]
			t.visible = true
		else:
			t.visible = false

func _hide_trail() -> void:
	for t in _trail:
		t.visible = false
	_pos_history.clear()

# In-flight steering: rotate velocity toward the closest enemy in a forward cone — but
# ONLY one we can actually SEE. A wall or platform between us blocks the assist, so the
# blade never curves down into the very platform it was thrown over toward a hidden,
# lower foe. Speed is preserved (we only rotate), so gravity still arcs the throw.
func _apply_aim_assist(delta: float) -> void:
	# Only help shortly after the throw. Past that window the blade flies ballistically, so
	# an old / screen-wrapped / long-falling shuriken never makes a surprise mid-air turn.
	if Time.get_ticks_msec() / 1000.0 - throw_time > AIM_ASSIST_DURATION:
		return
	var speed: float = velocity_v.length()
	if speed < AIM_ASSIST_MIN_SPEED:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
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
		if _terrain_blocks_sight(space, p):
			continue   # foe is behind cover — don't steer into the wall/platform
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

# True when solid terrain (a wall/platform StaticBody2D) sits between us and the target —
# i.e. the foe is NOT in line of sight, so we must not steer toward them.
func _terrain_blocks_sight(space: PhysicsDirectSpaceState2D, target: Node) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	q.exclude = [get_rid()]
	q.collide_with_areas = false   # only solid bodies can block sight (not other shurikens)
	var hit: Dictionary = space.intersect_ray(q)
	# Clear sight = nothing hit, or the first thing hit is the target itself (a body, not terrain).
	return not hit.is_empty() and hit.collider is StaticBody2D

func _on_body_entered(body: Node) -> void:
	if stuck or consumed:
		return
	if not GameState.is_round_active():
		return
	if body is CharacterBody2D and body.has_method("hit_by_shuriken"):
		var should_free: bool = body.hit_by_shuriken(self)
		if should_free:
			consumed = true
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
		_hide_trail()
		if _sprite != null and _sprite.hframes > 1:
			_sprite.frame = IMPACT_FRAME                  # stuck-in-surface pose (impact streaks)
		elif _sprite != null:
			_sprite.rotation = randf_range(-0.35, 0.35)   # fallback star: just tilt it

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
	_pos_history.clear()   # restart the comet trail from the new heading
	Audio.play("click")   # metallic ping

# Two flying shurikens meet — they spark and ricochet apart (the same clash lightning
# the katanas throw). Pure flair + a small ricochet; no time-freeze (projectiles cross
# often, so a hitstop here would be too much). The lower-id blade resolves the pair so
# the spark and the velocity swap happen exactly once.
func _on_area_entered(area: Node) -> void:
	if stuck or not area.is_in_group("shurikens"):
		return
	if area.stuck:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < _clash_cooldown_until:
		return
	if get_instance_id() < area.get_instance_id():
		_do_shuriken_clash(area, t)

func _do_shuriken_clash(other, t: float) -> void:
	var midpoint: Vector2 = (global_position + other.global_position) * 0.5
	# Ricochet each away from the other along the line between them, keeping its speed.
	var n: Vector2 = global_position - other.global_position
	if n.length() < 0.01:
		n = Vector2(1.0, 0.0)
	n = n.normalized()
	var s_self: float = maxf(velocity_v.length(), 150.0)
	var s_other: float = maxf(other.velocity_v.length(), 150.0)
	velocity_v = n * s_self
	other.velocity_v = -n * s_other
	# Both blades are now spent ricochets — harmless, catch-only (no more kills off a clash).
	ricocheted = true
	other.ricocheted = true
	_clash_cooldown_until = t + 0.25
	other._clash_cooldown_until = t + 0.25
	_spawn_clash_spark(midpoint)
	Audio.play("click")   # metallic ping

func _spawn_clash_spark(pos: Vector2) -> void:
	var path: String = "res://sprites/fx/clash_lightning_5frame_native_160x32.png"
	if not ResourceLoader.exists(path):
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.set_script(load("res://fx_anim.gd"))
	fx.frame_count = 5
	fx.fps = 16.0
	fx.texture = load(path)
	fx.position = pos
	fx.scale = Vector2(1.1, 1.1)
	fx.z_index = 60
	get_parent().add_child(fx)

func _check_pickup() -> void:
	if consumed:
		return   # already collected; queue_free is deferred, so don't count it twice
	for p in get_tree().get_nodes_in_group("players"):
		if not p.alive:
			continue
		if p.stash >= 5:
			continue
		if global_position.distance_to(p.global_position) < Combat.pickup_radius_px + 12.0:
			consumed = true
			p.stash += 1
			p.stash_changed.emit(p.slot, p.stash)
			queue_free()
			return
