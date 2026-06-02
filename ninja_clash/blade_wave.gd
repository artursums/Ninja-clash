## Charged katana "blade-wave" projectile (DEV-005).
##
## Released by holding the katana past the charge threshold (see player.gd). Unlike the shuriken it
## flies STRICTLY straight — no aim-assist steering, no gravity — despawns the instant it touches
## terrain, deals one heart to the first fighter it hits (then despawns), and is NOT retrievable.
## The launching player always spends one katana charge on release (handled in player.gd), so a miss
## or a blocked hit still costs the attempt — this projectile only models flight + the hit.
##
## Visual: the DEV-004 katana slash-trail art as the head sprite, tinted to the thrower's clan colour
## and rotated to the flight direction, plus a shuriken-style fading afterimage "comet" trail (copies
## of the head parked at progressively older positions). Modelled on shuriken.gd's trail.

extends Area2D

const SLASH_SHEET := "res://sprites/fx/katana_slash_5frame_native_400x80.png"
const SHEET_HFRAMES := 5
const HEAD_FRAME := 2                          # fullest crescent frame, used as the wave body
const HITBOX_SIZE := Vector2(22.0, 26.0)
# Comet trail: TRAIL_COUNT copies of the head sprite parked TRAIL_STRIDE history-steps apart, fading.
const TRAIL_COUNT := 4
const TRAIL_STRIDE := 3
const HISTORY_MAX := TRAIL_STRIDE * TRAIL_COUNT + 1
const TRAIL_ALPHAS := [0.5, 0.34, 0.22, 0.12]   # newest → oldest afterimage
const SCREEN_MARGIN := 48.0                     # despawn once this far past the 800×450 viewport

# --- Set by the thrower BEFORE add_child (so they are valid in _ready) ---
var velocity_v: Vector2 = Vector2.ZERO   # straight-line flight (direction × speed); never re-aimed
var thrower_slot: int = 0
var damage: int = 1
var lifetime_s: float = 2.5
var tint: Color = Color(0.7, 0.9, 1.0)

var _age: float = 0.0
var _dead: bool = false                  # guards the deferred queue_free against a double-hit
var _sprite: Sprite2D = null             # head crescent
var _trail: Array = []                   # TRAIL_COUNT afterimage Sprite2D, newest → oldest
var _pos_history: Array = []             # recent global positions, index 0 = most recent


func _ready() -> void:
	add_to_group("blade_waves")
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = HITBOX_SIZE
	col.shape = rect
	add_child(col)
	_setup_visuals()
	body_entered.connect(_on_body_entered)


# Build the head crescent + trailing afterimages from the DEV-004 slash strip, tinted to the clan
# colour, additive, rotated to the flight heading. Falls back to a bare untextured glow so a launch
# never crashes if the art is missing (placeholder per the task's out-of-scope note).
func _setup_visuals() -> void:
	var ang: float = velocity_v.angle()
	var tex: Texture2D = null
	if ResourceLoader.exists(SLASH_SHEET):
		tex = load(SLASH_SHEET)
	# Trail afterimages first so they draw UNDER the head (sibling order).
	for i in TRAIL_COUNT:
		var tr: Sprite2D = _make_sprite(tex, ang, 54)
		tr.modulate = Color(tint.r, tint.g, tint.b, TRAIL_ALPHAS[i])
		tr.visible = false   # shown once enough path history exists
		add_child(tr)
		_trail.append(tr)
	# Head crescent on top.
	_sprite = _make_sprite(tex, ang, 56)
	_sprite.modulate = tint
	add_child(_sprite)


func _make_sprite(tex: Texture2D, ang: float, z: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	if tex != null:
		s.texture = tex
		s.hframes = SHEET_HFRAMES
		s.frame = HEAD_FRAME
	s.centered = true
	s.rotation = ang
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth film-style crescent (matches slash_fx)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	return s


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Freeze during non-round states (countdown, round-end pause) — same as the shuriken.
	if not GameState.is_round_active():
		return
	position += velocity_v * delta   # strictly straight, no gravity / no steering
	_age += delta
	_record_history()
	_update_trail()
	if _age >= lifetime_s or _offscreen():
		_despawn()


func _offscreen() -> bool:
	return position.x < -SCREEN_MARGIN or position.x > 800.0 + SCREEN_MARGIN \
		or position.y < -SCREEN_MARGIN or position.y > 450.0 + SCREEN_MARGIN


func _record_history() -> void:
	_pos_history.push_front(global_position)
	if _pos_history.size() > HISTORY_MAX:
		_pos_history.resize(HISTORY_MAX)


# Park each afterimage at a progressively older recorded position; hide any without enough history
# yet, so the trail streams in after launch (identical scheme to shuriken.gd's comet trail).
func _update_trail() -> void:
	for i in _trail.size():
		var idx: int = TRAIL_STRIDE * (i + 1)
		var tr: Sprite2D = _trail[i]
		if idx < _pos_history.size():
			tr.global_position = _pos_history[idx]
			tr.visible = true
		else:
			tr.visible = false


func _on_body_entered(body: Node) -> void:
	if _dead or not GameState.is_round_active():
		return
	# Fighter hit: 1 heart via the standard damage path (guard/i-frames still apply — blockable and
	# dodgeable), then despawn. Never strikes the launcher or a corpse.
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.slot == thrower_slot or not body.alive:
			return
		var impact: Vector2 = velocity_v.normalized() * 220.0 + Vector2(0.0, -60.0)
		body.take_damage(damage, impact, thrower_slot)
		_despawn()
		return
	# Terrain: vanish on any wall/platform (no sticking, not pickup ammo).
	if body is StaticBody2D:
		_despawn()


func _despawn() -> void:
	if _dead:
		return
	_dead = true
	queue_free()
