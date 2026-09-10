extends Node2D

# Non-colliding atmosphere for Verdant Cistern. Everything is drawn behind the fighters and
# platforms: water shimmer, slow mist, and paired firefly motes that keep the arena symmetrical.

const W := 800.0
const H := 450.0

var _t: float = 0.0
var _motes: Array = []


func _ready() -> void:
	z_index = -6
	var rng := RandomNumberGenerator.new()
	rng.seed = 90731
	for i in range(22):
		var side := -1.0 if i % 2 == 0 else 1.0
		_motes.append({
			"base": Vector2(400.0 + side * rng.randf_range(86.0, 332.0), rng.randf_range(72.0, 348.0)),
			"phase": rng.randf_range(0.0, TAU),
			"radius": rng.randf_range(1.1, 2.4),
			"amp": rng.randf_range(5.0, 16.0),
		})
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_draw_waterfall_glow()
	_draw_mist_bands()
	_draw_motes()


func _draw_waterfall_glow() -> void:
	for x in [366.0, 400.0, 434.0]:
		var width := 1.5 if x != 400.0 else 2.5
		var color := Color(0.55, 1.0, 0.9, 0.12 if x != 400.0 else 0.18)
		for strand in range(3):
			var pts := PackedVector2Array()
			for step in range(36):
				var y := 48.0 + step * 9.5
				var sway := sin(_t * 1.8 + step * 0.43 + strand * 1.7) * (2.4 if x != 400.0 else 4.2)
				pts.append(Vector2(x + (strand - 1) * 5.0 + sway, y))
			draw_polyline(pts, color, width)


func _draw_mist_bands() -> void:
	for i in range(5):
		var y := 116.0 + i * 54.0
		var drift := fmod(_t * (9.0 + i * 2.0), 96.0)
		var alpha := 0.045 + i * 0.006
		for x in range(-96, 832, 96):
			draw_rect(Rect2(Vector2(float(x) + drift, y + sin(_t + i) * 2.0), Vector2(68.0, 2.0)), Color(0.55, 1.0, 0.88, alpha))
			draw_rect(Rect2(Vector2(W - float(x) - drift - 68.0, y + 12.0 - sin(_t + i) * 2.0), Vector2(68.0, 1.0)), Color(0.55, 1.0, 0.88, alpha * 0.7))


func _draw_motes() -> void:
	for m in _motes:
		var base: Vector2 = m["base"]
		var phase: float = m["phase"]
		var amp: float = m["amp"]
		var r: float = m["radius"]
		var p := base + Vector2(sin(_t * 1.1 + phase) * amp, cos(_t * 0.8 + phase) * amp * 0.45)
		var pulse := 0.55 + 0.45 * sin(_t * 3.2 + phase)
		draw_circle(p, r * (1.0 + pulse * 0.35), Color(0.76, 1.0, 0.68, 0.12))
		draw_circle(p, r, Color(0.77, 1.0, 0.66, 0.34 + pulse * 0.22))
