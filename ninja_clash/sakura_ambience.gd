# Layered atmospheric ambience for the Sakura Temple map. Builds a sense of spatial
# depth through three parallax/animation layers that all run on a REAL-time clock, so they
# keep breathing through the Engine.time_scale==0 clash hitstop (same trick as fx_anim.gd).
#
#   1. Lantern fire glow  — two flickering additive halos pinned over the wall lanterns,
#      with lazy rising embers. (z=1, drawn over the stone walls.)
#   2. Moonlight bloom     — a tight surface-brighten disc + a wide soft halo over the
#      background moon, slowly breathing. (z=-9, just in front of the sky image.)
#   3. Drifting birds      — small gull silhouettes that periodically cross the sky in
#      loose flocks, alternating direction, with sine bob + wing-flap. (z=-7, behind walls.)
#
# Coordinates are arena world-space (800x450). Lantern/moon screen anchors were measured
# from the wall sheet + background-image cover transform (see main.gd _make_wall "fill"
# and _apply_sky_background / sky_rect at x=80, scale 0.44199).
#
# Usage: instance, set z handling, add as a child of arena_root. Pure scenery — no
# collision, no gameplay, no signals.

extends Node2D

# --- Anchors (arena world-space, 800x450) ---
# Big foreground wall lanterns (measured from the wall sheet "fill" transform).
const LANTERNS: Array = [Vector2(32.0, 92.0), Vector2(768.0, 92.0)]
# Distant background lanterns — the two hanging pagoda lamps on the left of the
# background art (measured from the bg cover transform: scale 0.44199, x+80, y-15).
const DISTANT_LANTERNS: Array = [Vector2(136.0, 90.0), Vector2(137.0, 134.0)]
const MOON_POS: Vector2 = Vector2(503.0, 74.0)
const MOON_SCREEN_RADIUS: float = 25.0   # background moon disc radius on screen

# --- Colours ---
const LANTERN_COLOR: Color = Color(1.0, 0.62, 0.26)   # warm orange firelight
const EMBER_COLOR: Color = Color(1.0, 0.72, 0.34)
const MOON_COLOR: Color = Color(0.82, 0.88, 1.0)       # cool moonlight

# --- Bird flock pacing ---
const BIRD_SHEET: String = "res://sprites/levels/sakura_temple/birds_4frame_native_56x9.png"
const BIRD_FRAMES: int = 4
const BIRD_FLOCK_MIN_GAP: float = 7.0
const BIRD_FLOCK_MAX_GAP: float = 15.0

var _clock: float = 0.0          # real-time seconds since _ready
var _prev_clock: float = 0.0     # for real-delta integration (embers / bird motion)

# Layer 1 — lantern glows (one entry per lantern): core + halo sprites + per-lantern seed.
var _lanterns: Array = []
# Embers: pooled dicts {spr, x, y, vy, vx, t, life, lantern}.
var _embers: Array = []
var _glow_tex: Texture2D            # shared soft radial texture for cores/embers/halos

# Layer 2 — moon.
var _moon_surface: Sprite2D
var _moon_halo: Sprite2D

# Layer 3 — birds: dicts {spr, x, base_y, vx, bob_amp, bob_freq, bob_phase, flap_phase, scale}.
var _birds: Array = []
var _next_flock_t: float = 2.5      # first flock shortly after load
var _bird_tex: Texture2D


func _ready() -> void:
	_clock = Time.get_ticks_msec() / 1000.0
	_prev_clock = _clock
	_glow_tex = _make_radial_tex(Color(1, 1, 1, 1), 64)
	_build_moon()
	_build_lanterns()
	if ResourceLoader.exists(BIRD_SHEET):
		_bird_tex = load(BIRD_SHEET)


func _process(_delta: float) -> void:
	# Real-time clock so ambience animates through the clash hitstop (time_scale==0).
	var now: float = Time.get_ticks_msec() / 1000.0
	var rdt: float = clampf(now - _prev_clock, 0.0, 0.1)   # real delta, capped vs. hitches
	_prev_clock = now
	_clock = now

	_animate_lanterns()
	_animate_embers(rdt)
	_animate_moon()
	_animate_birds(rdt)


# === Layer 1: lantern fire glow + embers ===

func _build_lanterns() -> void:
	# Big foreground wall lanterns: bright, drawn over the walls (z=1), with embers.
	_add_lanterns(LANTERNS, 1.55, 0.8, 1.0, true, 1)
	# Distant background pagoda lamps: small + dimmer, sit on the sky image (z=-9),
	# no embers (too far away for sparks to read).
	_add_lanterns(DISTANT_LANTERNS, 0.6, 0.3, 0.6, false, -9)

func _add_lanterns(positions: Array, halo_base: float, core_base: float, bright: float, embers: bool, z: int) -> void:
	for i in positions.size():
		var pos: Vector2 = positions[i]
		var halo := _make_glow_sprite(LANTERN_COLOR, z)
		halo.position = pos
		var core := _make_glow_sprite(LANTERN_COLOR.lightened(0.25), z)
		core.position = pos
		_lanterns.append({
			"halo": halo, "core": core, "pos": pos,
			"seed": float(_lanterns.size()) * 13.7,
			"halo_base": halo_base, "core_base": core_base, "bright": bright, "embers": embers,
		})

func _animate_lanterns() -> void:
	for L in _lanterns:
		var s: float = L["seed"]
		# Layered sines at incommensurate rates => organic candle flicker.
		# Rates 2.5x slower than the first pass (felt too fast/twitchy in-game).
		var f: float = 0.62 \
			+ 0.16 * sin(_clock * 4.4 + s) \
			+ 0.11 * sin(_clock * 7.6 + s * 2.0) \
			+ 0.07 * sin(_clock * 1.72 + s * 0.5)
		var br: float = L["bright"]
		var halo: Sprite2D = L["halo"]
		var core: Sprite2D = L["core"]
		halo.modulate.a = clampf(f * br, 0.12, 1.0)
		halo.scale = Vector2.ONE * (float(L["halo_base"]) + 0.18 * f)
		core.modulate.a = clampf((0.55 + 0.4 * f) * br, 0.2, 1.0)
		core.scale = Vector2.ONE * (float(L["core_base"]) + 0.06 * f)
		# Occasionally birth an ember from this lantern (foreground lanterns only).
		if L["embers"] and randf() < 0.10:
			_spawn_ember(L["pos"])

func _spawn_ember(origin: Vector2) -> void:
	var spr := _make_glow_sprite(EMBER_COLOR, 1)
	spr.position = origin
	spr.scale = Vector2(0.12, 0.12)
	_embers.append({
		"spr": spr,
		"x": origin.x + randf_range(-3.0, 3.0),
		"y": origin.y,
		"vy": randf_range(-26.0, -16.0),     # drifts upward
		"vx": randf_range(-6.0, 6.0),
		"t": 0.0,
		"life": randf_range(1.1, 2.0),
		"sway": randf_range(8.0, 16.0),
		"phase": randf() * TAU,
	})

func _animate_embers(rdt: float) -> void:
	var keep: Array = []
	for e in _embers:
		e["t"] += rdt
		if e["t"] >= e["life"]:
			e["spr"].queue_free()
			continue
		e["y"] += e["vy"] * rdt
		e["x"] += (e["vx"] + sin(_clock * 3.0 + e["phase"]) * e["sway"]) * rdt
		var spr: Sprite2D = e["spr"]
		spr.position = Vector2(e["x"], e["y"])
		var k: float = e["t"] / e["life"]               # 0..1 life progress
		spr.modulate.a = (1.0 - k) * 0.9
		spr.scale = Vector2.ONE * (0.16 - 0.06 * k)
		keep.append(e)
	_embers = keep


# === Layer 2: moonlight bloom ===

func _build_moon() -> void:
	# Wide soft halo behind/around the moon (the light bloom).
	_moon_halo = _make_glow_sprite(MOON_COLOR, -9)
	_moon_halo.position = MOON_POS
	_moon_halo.scale = Vector2.ONE * (MOON_SCREEN_RADIUS * 2.6 / 32.0)  # tex radius=32px
	# Tight disc that brightens the moon surface itself.
	_moon_surface = _make_glow_sprite(MOON_COLOR.lightened(0.15), -9)
	_moon_surface.position = MOON_POS
	_moon_surface.scale = Vector2.ONE * (MOON_SCREEN_RADIUS * 1.15 / 32.0)

func _animate_moon() -> void:
	# Slow ~7s breath, gentle so it reads as a steady glow rather than a pulse.
	var b: float = 0.5 + 0.5 * sin(_clock * (TAU / 7.0))
	_moon_halo.modulate.a = 0.22 + 0.10 * b
	_moon_halo.scale = Vector2.ONE * ((MOON_SCREEN_RADIUS * 2.6 / 32.0) * (1.0 + 0.05 * b))
	_moon_surface.modulate.a = 0.30 + 0.12 * b


# === Layer 3: drifting birds ===

func _animate_birds(rdt: float) -> void:
	# Spawn a new flock on schedule.
	if _clock >= _next_flock_t:
		_spawn_flock()
		_next_flock_t = _clock + randf_range(BIRD_FLOCK_MIN_GAP, BIRD_FLOCK_MAX_GAP)
	var keep: Array = []
	for b in _birds:
		b["x"] += b["vx"] * rdt
		var y: float = b["base_y"] + sin(_clock * b["bob_freq"] + b["bob_phase"]) * b["bob_amp"]
		var spr: Sprite2D = b["spr"]
		spr.position = Vector2(b["x"], y)
		spr.frame = int(_clock * 9.0 + b["flap_phase"]) % BIRD_FRAMES
		# Cull once fully past the far edge (vx sign tells travel direction).
		if (b["vx"] > 0.0 and b["x"] > 900.0) or (b["vx"] < 0.0 and b["x"] < -100.0):
			spr.queue_free()
			continue
		keep.append(b)
	_birds = keep

func _spawn_flock() -> void:
	if _bird_tex == null:
		return
	var go_right: bool = randf() < 0.5
	var vx: float = randf_range(34.0, 52.0) * (1.0 if go_right else -1.0)
	var start_x: float = -70.0 if go_right else 870.0
	var lead_y: float = randf_range(55.0, 150.0)   # high in the sky, above the action
	var n: int = randi_range(2, 5)
	for i in n:
		var spr := Sprite2D.new()
		spr.texture = _bird_tex
		spr.hframes = BIRD_FRAMES
		spr.vframes = 1
		spr.frame = 0
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = -7
		# Loose V/echelon: each follower trails behind and a touch lower.
		var depth: float = randf_range(0.85, 1.5)    # parallax-ish size variation
		spr.scale = Vector2(depth, depth)
		spr.flip_h = not go_right
		spr.modulate = Color(1, 1, 1, clampf(0.45 + depth * 0.35, 0.4, 0.95))
		add_child(spr)
		var trail: float = float(i) * 18.0 * (1.0 if go_right else -1.0)
		_birds.append({
			"spr": spr,
			"x": start_x - trail,
			"base_y": lead_y + float(i) * randf_range(5.0, 9.0),
			"vx": vx * randf_range(0.92, 1.08),
			"bob_amp": randf_range(2.0, 5.0),
			"bob_freq": randf_range(1.4, 2.2),
			"bob_phase": randf() * TAU,
			"flap_phase": randf() * 10.0,
			"scale": depth,
		})


# === Helpers ===

# Soft radial texture: opaque-ish centre fading to transparent at the rim. Used for
# every additive glow (lanterns, embers, moon) so they composite as light, not sprites.
func _make_radial_tex(c: Color, size: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 1.0),
		Color(c.r, c.g, c.b, 0.5),
		Color(c.r, c.g, c.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex

# Additive-blended radial glow Sprite2D, centred, parented to this node, given z.
func _make_glow_sprite(c: Color, z: int) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = _glow_tex
	spr.centered = true
	spr.modulate = c
	spr.z_index = z
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat
	add_child(spr)
	return spr
