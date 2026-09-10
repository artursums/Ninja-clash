# Layered atmospheric ambience for the Neo Tokyo map — a rainy synthwave night.
# Everything runs on a REAL-time clock so it keeps animating through the
# Engine.time_scale==0 clash hitstop (same trick as fx_anim.gd / sakura_ambience.gd).
#
# Depth layers, back to front:
#   - Sun bloom        — soft red/magenta halo over the background sun, slow breath. (z=-9)
#   - Neon accents     — small buzzing cyan/magenta glows over the cityscape.         (z=-8)
#   - Ground mist      — wide faint haze puffs drifting low across the arena.          (z=-7)
#   - Rain FAR / MID   — thin, faint, slow diagonal streaks behind the fighters.       (z=-6/-3)
#   - Rain NEAR        — brighter, faster foreground streaks in front of fighters.     (z=20)
#   - Lightning        — infrequent double-strike flash that lights up the whole rain. (z=40)
#
# Coordinates are arena world-space (800x450). Background anchors use the same cover
# transform as the sky image (scale 0.44199, x+80, y-15; see main.gd _apply_sky_background).
# Pure scenery — no collision, no gameplay, no signals.

extends Node2D

# --- Sun (background focal light, upper-centre) ---
const SUN_POS: Vector2 = Vector2(455.0, 78.0)
const SUN_COLOR: Color = Color(1.0, 0.26, 0.46)

# --- Neon sign accents: [world_pos, color]. Curated over the city's lit faces. ---
const NEON_ACCENTS: Array = [
	[Vector2(196.0, 339.0), Color(0.30, 0.85, 1.0)],   # cyan
	[Vector2(317.0, 205.0), Color(0.30, 0.85, 1.0)],   # cyan
	[Vector2(533.0, 236.0), Color(1.0, 0.32, 0.80)],   # magenta
	[Vector2(628.0, 339.0), Color(0.30, 0.85, 1.0)],   # cyan
	[Vector2(360.0, 405.0), Color(1.0, 0.32, 0.80)],   # magenta
	[Vector2(255.0, 360.0), Color(1.0, 0.42, 0.30)],   # warm red sign
]

# --- Wall-tower neon signs: [world_pos, color, scale]. The two side towers carry a
# vertical stack of magenta signs (未来都市 / 忍者 / サイバー); add the same purple glow
# over each so the walls buzz with neon too. Drawn in front of the walls (z=1).
# Positions measured from the wall sheet's "fill" transform (s=0.32328, body @225).
const WALL_NEON_COLOR: Color = Color(0.97, 0.34, 0.92)
const WALL_NEON: Array = [
	# Left tower (top tall sign / mid / bottom)
	[Vector2(42.0, 122.0), WALL_NEON_COLOR, Vector2(0.78, 1.20)],
	[Vector2(45.0, 250.0), WALL_NEON_COLOR, Vector2(0.70, 0.85)],
	[Vector2(37.0, 372.0), WALL_NEON_COLOR, Vector2(0.66, 0.92)],
	# Right tower (mirrored)
	[Vector2(757.0, 120.0), WALL_NEON_COLOR, Vector2(0.78, 1.20)],
	[Vector2(756.0, 251.0), WALL_NEON_COLOR, Vector2(0.70, 0.85)],
	[Vector2(763.0, 372.0), WALL_NEON_COLOR, Vector2(0.66, 0.92)],
]

# --- Rain layers: name -> [count, vy, slope, length, width, alpha, color, z] ---
# slope = horizontal/vertical velocity ratio (0 = straight-down vertical fall).
const RAIN_LAYERS: Array = [
	[170, 220.0, 0.0, 12.0, 0.6, 0.22, Color(0.74, 0.85, 1.0), -6],   # FAR
	[125, 360.0, 0.0, 18.0, 0.9, 0.38, Color(0.80, 0.90, 1.0), -3],   # MID
	[85,  540.0, 0.0, 28.0, 1.3, 0.60, Color(0.90, 0.96, 1.0), 20],   # NEAR (foreground)
]

const STREAK_H: float = 32.0   # streak texture height in px (length scaling baseline)

# --- Background hanging lamps: the two paper lanterns on the upper-left branch of
# the bg art. Warm amber glow, slow paper-lantern flicker. Drawn on the sky (z=-9).
# Screen anchors measured from the bg cover transform (scale 0.44199, x+80, y-15).
const BG_LAMP_COLOR: Color = Color(1.0, 0.55, 0.28)
const BG_LAMPS: Array = [Vector2(135.0, 104.0), Vector2(130.0, 200.0)]

# --- Flying cars: dense neon hovercar TRAFFIC across the far sky. Several stacked
# lanes, each with its own direction/speed/depth, kept full so the sky always buzzes
# (high-traffic feel). 4-frame thruster-pulse sheet, flip_h for direction.
const CAR_SHEET: String = "res://sprites/levels/neo_tokyo/flyingcars_4frame_native_80x10.png"
const CAR_FRAMES: int = 4
const CAR_LANES: int = 6              # horizontal traffic lanes over the upper sky
const CAR_PER_LANE_MIN: int = 3
const CAR_PER_LANE_MAX: int = 5
# Per-car neon tints (cyan / magenta / amber), chosen at random per spawn.
const CAR_TINTS: Array = [
	Color(0.45, 0.90, 1.0),
	Color(1.0, 0.42, 0.85),
	Color(1.0, 0.66, 0.35),
]

# --- Lightning pacing ---
const LIGHTNING_MIN_GAP: float = 8.0
const LIGHTNING_MAX_GAP: float = 18.0
# Bolt tints picked at random per strike (white / electric-cyan / pale violet).
const BOLT_COLORS: Array = [
	Color(1.0, 1.0, 1.0),
	Color(0.70, 0.90, 1.0),
	Color(0.86, 0.76, 1.0),
]

var _clock: float = 0.0
var _prev_clock: float = 0.0

var _glow_tex: Texture2D       # shared soft radial (sun / neon / mist)
var _streak_tex: Texture2D     # shared vertical rain streak

var _sun: Sprite2D
var _neon: Array = []          # dicts {spr, seed, base}
var _bg_lamps: Array = []      # dicts {halo, core, seed}
var _mist: Array = []          # dicts {spr, vx, w}
var _drops: Array = []         # dicts {spr, x, y, vy, slope}

var _cars: Array = []          # dicts {spr, x, base_y, vx, bob_*, anim_phase, lane_y}
var _car_tex: Texture2D

var _lightning: ColorRect
var _next_strike_t: float = 6.0
var _flash_t0: float = -100.0
var _bolts: Array = []          # dicts {node, t0, life, base_alpha}


func _ready() -> void:
	_clock = Time.get_ticks_msec() / 1000.0
	_prev_clock = _clock
	_glow_tex = _make_radial_tex(Color(1, 1, 1, 1), 64)
	_streak_tex = _make_streak_tex()
	_build_sun()
	_build_neon()
	_build_bg_lamps()
	_build_mist()
	_build_rain()
	_build_lightning()
	if ResourceLoader.exists(CAR_SHEET):
		_car_tex = load(CAR_SHEET)
		_build_cars()


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var rdt: float = clampf(now - _prev_clock, 0.0, 0.1)
	_prev_clock = now
	_clock = now

	_animate_sun()
	_animate_neon()
	_animate_bg_lamps()
	_animate_mist(rdt)
	_animate_rain(rdt)
	_animate_cars(rdt)
	_animate_lightning()


# === Sun bloom ===

func _build_sun() -> void:
	_sun = _make_glow_sprite(SUN_COLOR, -9)
	_sun.position = SUN_POS
	_sun.scale = Vector2.ONE * (95.0 / 32.0)   # ~95 px halo radius

func _animate_sun() -> void:
	var b: float = 0.5 + 0.5 * sin(_clock * (TAU / 9.0))   # slow 9s breath
	_sun.modulate.a = 0.26 + 0.10 * b
	_sun.scale = Vector2.ONE * ((95.0 / 32.0) * (1.0 + 0.04 * b))


# === Neon accents ===

func _build_neon() -> void:
	# Background city accents (behind the fighters).
	for e in NEON_ACCENTS:
		_add_neon(e[0], e[1], Vector2.ONE * (22.0 / 32.0), -8)
	# Wall-tower signs (in front of the walls).
	for e in WALL_NEON:
		_add_neon(e[0], e[1], e[2], 1)

func _add_neon(pos: Vector2, col: Color, scl: Vector2, z: int) -> void:
	var spr := _make_glow_sprite(col, z)
	spr.position = pos
	spr.scale = scl
	_neon.append({"spr": spr, "seed": float(_neon.size()) * 7.13, "col": col})

func _animate_neon() -> void:
	for N in _neon:
		var s: float = N["seed"]
		# Mostly steady, with a fast shimmer + an occasional brief brown-out (neon buzz).
		var shimmer: float = 0.78 + 0.12 * sin(_clock * 5.0 + s) + 0.06 * sin(_clock * 17.0 + s * 3.0)
		var brownout: float = 1.0
		var phase: float = fmod(_clock * 0.5 + s, 6.0)
		if phase < 0.12:
			brownout = 0.25 + 0.75 * (phase / 0.12)   # quick flicker dropout & recover
		var spr: Sprite2D = N["spr"]
		spr.modulate.a = clampf(shimmer * brownout, 0.1, 1.0)


# === Background hanging lamps ===

func _build_bg_lamps() -> void:
	for pos in BG_LAMPS:
		var halo := _make_glow_sprite(BG_LAMP_COLOR, -9)
		halo.position = pos
		halo.scale = Vector2.ONE * 0.55
		var core := _make_glow_sprite(BG_LAMP_COLOR.lightened(0.25), -9)
		core.position = pos
		core.scale = Vector2.ONE * 0.28
		_bg_lamps.append({"halo": halo, "core": core, "seed": float(_bg_lamps.size()) * 9.4})

func _animate_bg_lamps() -> void:
	for L in _bg_lamps:
		var s: float = L["seed"]
		# Lazy paper-lantern flicker (same incommensurate rates as the Sakura lamps).
		var f: float = 0.6 \
			+ 0.16 * sin(_clock * 4.4 + s) \
			+ 0.10 * sin(_clock * 7.6 + s * 2.0) \
			+ 0.07 * sin(_clock * 1.72 + s * 0.5)
		var halo: Sprite2D = L["halo"]
		var core: Sprite2D = L["core"]
		halo.modulate.a = clampf(f * 0.6, 0.1, 0.7)
		halo.scale = Vector2.ONE * (0.55 + 0.10 * f)
		core.modulate.a = clampf((0.5 + 0.4 * f) * 0.6, 0.15, 0.7)


# === Ground mist ===

func _build_mist() -> void:
	for i in 3:
		var spr := _make_glow_sprite(Color(0.50, 0.62, 0.85), -7)
		# Wide, flat puff (stretched radial) low in the arena.
		spr.scale = Vector2(7.0, 1.6)
		spr.position = Vector2(randf_range(0.0, 800.0), randf_range(330.0, 410.0))
		spr.modulate.a = randf_range(0.05, 0.10)
		_mist.append({"spr": spr, "vx": randf_range(6.0, 14.0) * (1.0 if i % 2 == 0 else -1.0), "w": 7.0 * 32.0})

func _animate_mist(rdt: float) -> void:
	for M in _mist:
		var spr: Sprite2D = M["spr"]
		spr.position.x += M["vx"] * rdt
		var half: float = M["w"] * 0.5
		if spr.position.x > 800.0 + half:
			spr.position.x = -half
		elif spr.position.x < -half:
			spr.position.x = 800.0 + half


# === Rain ===

func _build_rain() -> void:
	for layer in RAIN_LAYERS:
		var count: int = layer[0]
		var vy: float = layer[1]
		var slope: float = layer[2]
		var length: float = layer[3]
		var width: float = layer[4]
		var alpha: float = layer[5]
		var color: Color = layer[6]
		var z: int = layer[7]
		for i in count:
			var spr := Sprite2D.new()
			spr.texture = _streak_tex
			spr.centered = true
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp 2D pixel streak
			spr.z_index = z
			spr.scale = Vector2(width, length / STREAK_H)
			spr.modulate = Color(color.r, color.g, color.b, alpha)
			var dvy: float = vy * randf_range(0.85, 1.15)
			spr.rotation = atan2(slope * dvy, dvy)   # align streak with fall direction
			add_child(spr)
			_drops.append({
				"spr": spr,
				"x": randf_range(-30.0, 830.0),
				"y": randf_range(-60.0, 460.0),
				"vy": dvy,
				"slope": slope,
			})

func _animate_rain(rdt: float) -> void:
	for d in _drops:
		d["y"] += d["vy"] * rdt
		d["x"] += d["slope"] * d["vy"] * rdt
		if d["y"] > 470.0:
			d["y"] = randf_range(-60.0, -5.0)
			d["x"] = randf_range(-30.0, 830.0)
		elif d["x"] < -60.0:
			d["x"] = 830.0
		d["spr"].position = Vector2(d["x"], d["y"])


# === Flying cars ===

# Pre-populate every lane so the sky is already busy at load. Upper lanes read as
# "far" (small / slow / dim), lower lanes as "near" (big / fast / bright) for parallax.
func _build_cars() -> void:
	# All cars share ONE z strictly behind every level component (the
	# level-components.png platforms at z=0, ladder deco at z=-5, torii gates at
	# z=-6) so traffic always reads as a far background layer — never pasted in
	# front of a platform/gate. Still in front of the city neon (-8) and sky (-9).
	for lane in CAR_LANES:
		var dir: float = 1.0 if lane % 2 == 0 else -1.0       # alternating lane direction
		var depth: float = 0.5 + float(lane) * 0.12           # far (top) -> near (bottom)
		var lane_y: float = 48.0 + float(lane) * 32.0         # 48 .. 208 px up high
		var z: int = -7
		var n: int = randi_range(CAR_PER_LANE_MIN, CAR_PER_LANE_MAX)
		for i in n:
			# Spread the lane's cars across the full width (+jitter) so none line up.
			var x: float = randf_range(-120.0, 920.0)
			_spawn_car(lane_y, dir, depth, z, x)

func _spawn_car(lane_y: float, dir: float, depth: float, z: int, x: float) -> void:
	var spr := Sprite2D.new()
	spr.texture = _car_tex
	spr.hframes = CAR_FRAMES
	spr.vframes = 1
	spr.frame = 0
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index = z
	spr.scale = Vector2(depth, depth)
	spr.flip_h = dir < 0.0
	var tint: Color = CAR_TINTS[randi() % CAR_TINTS.size()]
	spr.modulate = Color(tint.r, tint.g, tint.b, clampf(0.42 + depth * 0.42, 0.4, 0.92))
	add_child(spr)
	var speed: float = (32.0 + depth * 64.0) * randf_range(0.9, 1.1)   # far slower, near faster
	_cars.append({
		"spr": spr,
		"x": x,
		"base_y": lane_y + randf_range(-6.0, 6.0),
		"vx": dir * speed,
		"bob_amp": randf_range(1.0, 3.5),
		"bob_freq": randf_range(0.7, 1.5),
		"bob_phase": randf() * TAU,
		"anim_phase": randf() * 10.0,
		"lane_y": lane_y,
	})

func _animate_cars(rdt: float) -> void:
	for c in _cars:
		c["x"] += c["vx"] * rdt
		var y: float = c["base_y"] + sin(_clock * c["bob_freq"] + c["bob_phase"]) * c["bob_amp"]
		var spr: Sprite2D = c["spr"]
		spr.position = Vector2(c["x"], y)
		spr.frame = int(_clock * 8.0 + c["anim_phase"]) % CAR_FRAMES
		# Recycle past the far edge: re-enter from the opposite side after a random
		# gap, re-jittered, so the lane keeps flowing without ever emptying out.
		if c["vx"] > 0.0 and c["x"] > 940.0:
			_recycle_car(c, randf_range(-320.0, -110.0))
		elif c["vx"] < 0.0 and c["x"] < -140.0:
			_recycle_car(c, randf_range(900.0, 1120.0))

func _recycle_car(c: Dictionary, x: float) -> void:
	c["x"] = x
	c["base_y"] = c["lane_y"] + randf_range(-6.0, 6.0)
	c["bob_phase"] = randf() * TAU
	c["anim_phase"] = randf() * 10.0
	var spr: Sprite2D = c["spr"]
	var tint: Color = CAR_TINTS[randi() % CAR_TINTS.size()]
	spr.modulate = Color(tint.r, tint.g, tint.b, spr.modulate.a)


# === Lightning ===

func _build_lightning() -> void:
	# Full-screen sky flash. Faint cool tint so the bolts read as the bright accent.
	_lightning = ColorRect.new()
	_lightning.color = Color(0.78, 0.86, 1.0, 0.0)
	_lightning.position = Vector2.ZERO
	_lightning.size = Vector2(800.0, 450.0)
	_lightning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning.z_index = 38
	add_child(_lightning)

func _animate_lightning() -> void:
	# Schedule the next storm strike (a flash + a chaotic burst of background bolts).
	if _clock >= _next_strike_t:
		_trigger_strike()
		_next_strike_t = _clock + randf_range(LIGHTNING_MIN_GAP, LIGHTNING_MAX_GAP)

	# Flash envelope: sharp attack, two decaying spikes (strike + after-strike).
	var fe: float = _clock - _flash_t0
	var fa: float = 0.0
	if fe >= 0.0 and fe < 0.7:
		fa = 0.62 * exp(-fe / 0.04) + 0.34 * exp(-max(0.0, fe - 0.11) / 0.05)
	_lightning.color.a = clampf(fa, 0.0, 0.72)

	# Per-bolt flicker fade; cull when spent. (Bolt t0 may be in the future => held dark.)
	var keep: Array = []
	for b in _bolts:
		var node: Node2D = b["node"]
		var e: float = _clock - b["t0"]
		if e < 0.0:
			node.modulate.a = 0.0
			keep.append(b)
			continue
		if e > b["life"]:
			node.queue_free()
			continue
		var ba: float = 1.0 * exp(-e / 0.05) + 0.55 * exp(-max(0.0, e - 0.09) / 0.045)
		node.modulate.a = clampf(ba, 0.0, 1.0) * b["base_alpha"]
		keep.append(b)
	_bolts = keep

func _trigger_strike() -> void:
	_flash_t0 = _clock
	for i in randi_range(1, 3):
		_spawn_bolt(randf() * 0.10)
	# ~40% of strikes are a multi-flicker storm cluster — extra delayed bolts.
	if randf() < 0.4:
		for j in randi_range(1, 2):
			_spawn_bolt(0.10 + randf() * 0.28)

# Build one chaotic jagged bolt (main streak + 0-2 branches) as a faded container.
func _spawn_bolt(delay: float) -> void:
	var node := Node2D.new()
	node.z_index = -7                      # far in the background, behind the fighters
	node.modulate = Color(1, 1, 1, 0.0)
	var col: Color = BOLT_COLORS[randi() % BOLT_COLORS.size()]
	var far: bool = randf() < 0.5
	var w: float = randf_range(1.0, 1.7) if far else randf_range(1.8, 3.0)
	var base_alpha: float = randf_range(0.45, 0.7) if far else randf_range(0.8, 1.0)
	var sx: float = randf_range(120.0, 680.0)
	var y_end: float = randf_range(150.0, 320.0)
	var pts: PackedVector2Array = _jagged(Vector2(sx, randf_range(-10.0, 8.0)), y_end)
	node.add_child(_make_line(pts, w, col))
	# Branches fork off a random interior node, drifting to one side.
	for k in randi_range(0, 2):
		if pts.size() < 4:
			break
		var idx: int = randi_range(2, pts.size() - 2)
		var bias: float = 1.0 if randf() < 0.5 else -1.0
		node.add_child(_make_line(_branch(pts[idx], randf_range(45.0, 120.0), bias), w * 0.6, col))
	add_child(node)
	_bolts.append({"node": node, "t0": _clock + delay, "life": 0.5, "base_alpha": base_alpha})

# Jagged top-to-bottom polyline: steps down with random horizontal zig-zag.
func _jagged(start: Vector2, y_end: float) -> PackedVector2Array:
	var pts := PackedVector2Array([start])
	var p: Vector2 = start
	while p.y < y_end:
		p = Vector2(p.x + randf_range(-22.0, 22.0), p.y + randf_range(14.0, 30.0))
		pts.append(p)
	return pts

# Shorter offshoot from a fork point, drifting toward `bias` (-1 left / +1 right).
func _branch(start: Vector2, length: float, bias: float) -> PackedVector2Array:
	var pts := PackedVector2Array([start])
	var p: Vector2 = start
	var travelled: float = 0.0
	while travelled < length:
		var dy: float = randf_range(10.0, 22.0)
		p = Vector2(p.x + bias * randf_range(4.0, 24.0) + randf_range(-6.0, 6.0), p.y + dy)
		pts.append(p)
		travelled += dy
	return pts

func _make_line(pts: PackedVector2Array, w: float, col: Color) -> Line2D:
	var ln := Line2D.new()
	ln.points = pts
	ln.width = w
	ln.default_color = col
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ln.material = mat
	return ln


# === Helpers ===

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

# Vertical rain streak — crisp flat 2D look: a short fade-in tail at the top,
# then a solid bright body. NEAREST-filtered on the sprites so edges stay sharp.
func _make_streak_tex() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 1.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 3
	tex.height = int(STREAK_H)
	return tex

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
