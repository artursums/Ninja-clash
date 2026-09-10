extends Node2D

const Arena := preload("res://arena_rules.gd")
const MAX_PARTICLES := 96
const STEP := 1.0 / 30.0
const CARS := preload("res://sprites/levels/neo_tokyo/flyingcars_4frame_native_80x10.png")
const BIRDS := preload("res://sprites/levels/sakura_temple/birds_4frame_native_56x9.png")

class LightLayer extends Node2D:
	var scene: Node2D
	func _draw() -> void:
		scene.draw_lights(self)

var theme := "cistern"
var _points := PackedVector2Array()
var _speeds := PackedVector2Array()
var _clock := 0.0
var _elapsed := 0.0
var _last_tick := 0
var _tint := Color("95dbba")
var _glow: GradientTexture2D
var _light_layer: LightLayer
var _lamps := PackedVector2Array()
var _cars: Array[Dictionary] = []
var _flash := 0.0

func _ready() -> void:
	z_index = -6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme)
	for i in (MAX_PARTICLES if theme == "tokyo" else 24):
		_points.append(Vector2(rng.randf_range(0, Arena.WIDTH), rng.randf_range(0, Arena.HEIGHT)))
		var drift := Vector2(rng.randf_range(3, 10), rng.randf_range(-8, -3))
		if theme == "sakura":
			drift = Vector2(rng.randf_range(12, 23), rng.randf_range(8, 16))
		elif theme == "tokyo":
			drift = Vector2(-38 - i % 3 * 12, 210 + i % 3 * 130)
		elif theme == "sky":
			drift = Vector2(rng.randf_range(15, 26), rng.randf_range(-4, 4))
		_speeds.append(drift)
	_tint = {"cistern": Color("95dbba"), "sakura": Color("f2bbd1"), "tokyo": Color("82bccc"), "sky": Color("f6e6b9")}.get(theme, Color.WHITE)
	_tint.a = 0.28 if theme == "tokyo" else 0.48
	_lamps = {
		"cistern": PackedVector2Array([Vector2(94, 244), Vector2(866, 244), Vector2(360, 307), Vector2(600, 307)]),
		"sakura": PackedVector2Array([Vector2(144, 166), Vector2(816, 166), Vector2(368, 231), Vector2(592, 231)]),
		"tokyo": PackedVector2Array([Vector2(145, 158), Vector2(848, 157), Vector2(316, 286), Vector2(670, 286), Vector2(480, 346)]),
		"sky": PackedVector2Array([Vector2(160, 166), Vector2(800, 166), Vector2(380, 310), Vector2(580, 310)]),
	}.get(theme, PackedVector2Array())
	_glow = GradientTexture2D.new()
	_glow.width = 64
	_glow.height = 64
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1, 0.5)
	_glow.gradient = Gradient.new()
	_glow.gradient.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	_light_layer = LightLayer.new()
	_light_layer.scene = self
	_light_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light_layer.material = blend
	_light_layer.show_behind_parent = true
	add_child(_light_layer)
	if theme == "tokyo":
		for lane in 6:
			for i in 4:
				_cars.append({"start": rng.randf_range(0, 240) + i * 250, "y": 55.0 + lane * 34,
					"speed": (24.0 + lane * 8) * (1 if lane % 2 == 0 else -1),
					"scale": 0.8 + lane * 0.14, "phase": rng.randf_range(0, 6.28)})
	_last_tick = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := minf((now - _last_tick) / 1000.0, 0.1)
	_last_tick = now
	if not is_visible_in_tree():
		return
	_clock += dt
	if _clock < STEP:
		return
	dt = _clock - fmod(_clock, STEP)
	_clock = fmod(_clock, STEP)
	_elapsed += dt
	for i in _points.size():
		_points[i] = Arena.wrap_position(_points[i] + _speeds[i] * dt, Vector2(16, 16))
	var storm := fmod(_elapsed + 4.0, 14.0)
	_flash = 0.12 if theme == "tokyo" and (storm < 0.06 or (storm > 0.16 and storm < 0.21)) else 0.0
	queue_redraw()
	_light_layer.queue_redraw()

func _car_position(car: Dictionary) -> Vector2:
	return Vector2(wrapf(car.start + _elapsed * car.speed, -40, 1000), car.y + sin(_elapsed * 1.3 + car.phase) * 2).floor()

func draw_lights(layer: Node2D) -> void:
	var color := Color("ffbd76") if theme == "sakura" else Color(_tint, 1)
	for i in _lamps.size():
		var pulse := 0.48 + 0.06 * sin(_elapsed * 2.5 + i * 2)
		layer.draw_texture_rect(_glow, Rect2(_lamps[i] - Vector2(38, 38), Vector2(76, 76)), false, Color(color, pulse))
	var celestial: Vector2 = {"cistern": Vector2(482, 98), "sakura": Vector2(737, 65), "tokyo": Vector2(706, 67), "sky": Vector2(480, 170)}.get(theme)
	var sun_color := Color("fe628e") if theme == "tokyo" else Color("b8d6cf")
	layer.draw_texture_rect(_glow, Rect2(celestial - Vector2(110, 80), Vector2(220, 160)), false, Color(sun_color, 0.16))
	for i in 4:
		var x := wrapf(i * 280 + sin(_elapsed * 0.12 + i) * 65, -100, 1060)
		layer.draw_texture_rect(_glow, Rect2(x - 160, 408 + sin(_elapsed * 0.2 + i) * 12, 320, 42), false, Color(_tint, 0.07))
	for car in _cars:
		layer.draw_texture_rect(_glow, Rect2(_car_position(car) - Vector2(12, 2), Vector2(26, 12)), false, Color("39bce633"))

func _draw() -> void:
	for car in _cars:
		var frame := int(_elapsed * 8 + car.phase) % 4
		var rect := Rect2(_car_position(car), Vector2(20, 10) * car.scale)
		if car.speed < 0:
			rect.position.x += rect.size.x
			rect.size.x = -rect.size.x
		draw_texture_rect_region(CARS, rect, Rect2(frame * 20, 0, 20, 10), Color(0.8, 0.9, 1, 0.85))
	if theme in ["sakura", "sky"]:
		for i in 7:
			var x := wrapf(_elapsed * 31 - i * 19 + 180, -180, 1180)
			var y: float = 87 + abs(i - 3) * 5 + sin(_elapsed * 2 + i * 0.5) * 3
			draw_texture_rect_region(BIRDS, Rect2(x, y, 14, 9), Rect2((int(_elapsed * 7) + i) % 4 * 14, 0, 14, 9), Color(0.65, 0.65, 0.78, 0.7))
	for point in _lamps:
		var color := Color("ffce87") if theme == "sakura" else Color(_tint, 1)
		draw_rect(Rect2(point - Vector2(4, 9), Vector2(8, 17)), Color("22283a"))
		draw_rect(Rect2(point - Vector2(2, 5), Vector2(4, 9)), color)
		draw_rect(Rect2(point + Vector2(-6, -10), Vector2(12, 2)), Color("79605e"))
	for i in _points.size():
		var point := _points[i].floor()
		if theme == "tokyo":
			draw_line(point, point + Vector2(-2 - i % 3, 7 + i % 3 * 5), Color(_tint, 0.14 + i % 3 * 0.08), 1)
		elif theme == "sakura":
			point.x += roundf(sin(_elapsed * 1.4 + i) * 4)
			draw_rect(Rect2(point, Vector2(3, 2)), _tint)
		else:
			draw_rect(Rect2(point, Vector2(2, 2)), _tint)
	if theme == "cistern":
		for x in [105.0, 728.0]:
			for strand in 3:
				var points := PackedVector2Array()
				for step in 28:
					points.append(Vector2(x + strand * 4 + sin(step * 0.7 + _elapsed * 2 + strand) * 2, 95 + step * 10))
				draw_polyline(points, Color(0.5, 0.95, 0.88, 0.12), 1)
	if _flash > 0:
		draw_rect(Rect2(Vector2.ZERO, Arena.SIZE), Color(0.6, 0.75, 1, _flash))
		var bolt := PackedVector2Array([Vector2(760, 0), Vector2(728, 44), Vector2(746, 40), Vector2(701, 102)])
		draw_polyline(bolt, Color(0.75, 0.88, 1, 0.65), 1.5)
