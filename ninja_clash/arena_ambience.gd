extends Node2D

const Arena := preload("res://arena_rules.gd")
const DESIGN_SIZE := Vector2(960, 540)
const MAX_PARTICLES := 96
const STEP := 1.0 / 30.0
const CARS := preload("res://sprites/levels/neo_tokyo/flyingcars_4frame_native_80x10.png")
const BIRDS := preload("res://sprites/levels/sakura_temple/birds_4frame_native_56x9.png")

class LightLayer extends Node2D:
	var scene: Node2D
	func _draw() -> void:
		scene.draw_lights(self)

var theme := "cistern"
var lamp_anchors := PackedVector2Array()
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
	scale = Arena.SIZE / DESIGN_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme)
	for i in (MAX_PARTICLES if theme == "tokyo" else 24):
		_points.append(Vector2(rng.randf_range(0, DESIGN_SIZE.x), rng.randf_range(0, DESIGN_SIZE.y)))
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
	for anchor in lamp_anchors:
		# Fixture bases use arena coordinates; weather follows the panorama's design scale.
		_lamps.append(anchor / scale - Vector2(0, 8))
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
		var point := _points[i] + _speeds[i] * dt
		_points[i] = Vector2(wrapf(point.x, -16, DESIGN_SIZE.x + 16), wrapf(point.y, -16, DESIGN_SIZE.y + 16))
	var storm := fmod(_elapsed + 4.0, 14.0)
	_flash = 0.12 if theme == "tokyo" and (storm < 0.06 or (storm > 0.16 and storm < 0.21)) else 0.0
	queue_redraw()
	_light_layer.queue_redraw()

func _car_position(car: Dictionary) -> Vector2:
	return Vector2(wrapf(car.start + _elapsed * car.speed, -40, 1000), car.y + sin(_elapsed * 1.3 + car.phase) * 2).floor()

func draw_lights(layer: Node2D) -> void:
	var color := Color("7ee5ed") if theme == "tokyo" else Color("ffb568")
	for i in _lamps.size():
		var pulse := 0.65 + 0.09 * sin(_elapsed * 7.5 + i * 2) + 0.04 * sin(_elapsed * 17 + i)
		layer.draw_texture_rect(_glow, Rect2(_lamps[i] - Vector2(64, 64), Vector2(128, 128)), false, Color(color, pulse))
	var celestial: Vector2 = {"cistern": Vector2(482, 98), "sakura": Vector2(737, 65), "tokyo": Vector2(706, 67), "sky": Vector2(480, 170)}.get(theme)
	var sun_color := Color("fe628e") if theme == "tokyo" else Color("b8d6cf")
	layer.draw_texture_rect(_glow, Rect2(celestial - Vector2(110, 80), Vector2(220, 160)), false, Color(sun_color, 0.16))
	for i in 4:
		var x := wrapf(i * 280 + sin(_elapsed * 0.12 + i) * 65, -100, 1060)
		layer.draw_texture_rect(_glow, Rect2(x - 160, 408 + sin(_elapsed * 0.2 + i) * 12, 320, 42), false, Color(_tint, 0.07))
	for car in _cars:
		layer.draw_texture_rect(_glow, Rect2(_car_position(car) - Vector2(12, 2), Vector2(26, 12)), false, Color("39bce633"))

func _draw() -> void:
	if theme in ["sakura", "sky"]:
		for i in 4:
			var x := wrapf(i * 290.0 + _elapsed * (6 + i * 2), -260, 1120)
			var y := 50.0 + i * 43 if theme == "sky" else 38.0 + i * 24
			draw_texture_rect(_glow, Rect2(x, y, 260, 34 + i * 6), false, Color(0.85, 0.9, 1, 0.19))
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
	_draw_architecture()
	for index in _lamps.size():
		var point := _lamps[index].floor()
		if theme == "tokyo":
			draw_rect(Rect2(point-Vector2(5,10),Vector2(10,18)),Color("172836"))
			draw_rect(Rect2(point-Vector2(2,8),Vector2(4,12)),Color("a5f3ee"))
			draw_rect(Rect2(point+Vector2(-7,6),Vector2(14,2)),Color("597688"))
		else:
			var flicker := int(_elapsed * 12 + index * 3) % 4
			draw_rect(Rect2(point+Vector2(-2,-2),Vector2(4,10)),Color("66504a"))
			draw_rect(Rect2(point+Vector2(-5,-3),Vector2(10,3)),Color("c69b64"))
			draw_rect(Rect2(point+Vector2(-6,6),Vector2(12,2)),Color("4e4142"))
			var flame := PackedVector2Array([point+Vector2(-4,-4),point+Vector2(-5,-9),point+Vector2(-1,-16-flicker),point+Vector2(1,-10),point+Vector2(4,-13+flicker),point+Vector2(5,-6),point+Vector2(2,-3)])
			draw_colored_polygon(flame,Color("e77846"))
			draw_rect(Rect2(point+Vector2(-2,-10),Vector2(4,6)),Color("ffd078"))
			draw_rect(Rect2(point+Vector2(-1,-7),Vector2(2,3)),Color("fff4c7"))
			for ember in 3:
				var rise := fmod(_elapsed * 13 + ember * 11 + index * 7, 32)
				var spark := point+Vector2(roundf(sin(rise * 0.2 + index) * 4),-12-rise)
				draw_rect(Rect2(spark,Vector2(1,2)),Color(1,0.7,0.35,(1-rise/32)*0.6))
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
		draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.6, 0.75, 1, _flash))
		var bolt := PackedVector2Array([Vector2(760, 0), Vector2(728, 44), Vector2(746, 40), Vector2(701, 102)])
		draw_polyline(bolt, Color(0.75, 0.88, 1, 0.65), 1.5)

func _draw_architecture() -> void:
	if theme == "tokyo":
		for i in 3:
			var origin := Vector2(236+i*241,30+i%2*28)
			var cable := PackedVector2Array()
			for step in 17:
				cable.append(origin+Vector2(step*10,sin(step/16.0*PI)*18))
			draw_polyline(cable,Color("1b293a"),2)
		return
	var cloth: Color = {"cistern": Color("305e52"),"sakura": Color("75445f"),"sky": Color("7c7760")}.get(theme)
	for i in 4:
		var origin := Vector2(135+i*229,38+(i%2)*42)
		for link in 8:
			var link_origin := origin+Vector2(-1,link*6)
			draw_rect(Rect2(link_origin,Vector2(3,5)),Color("465052"))
			draw_rect(Rect2(link_origin+Vector2(1,1),Vector2(1,3)),Color("222f38"))
		var anchor := origin+Vector2(-10,48)
		draw_rect(Rect2(anchor+Vector2(-3,0),Vector2(26,3)),Color("827563"))
		for strip in 18:
			var shift := roundf(sin(_elapsed*1.5+i+strip*0.15)*(strip/18.0)*4)
			var width := 20.0 if strip < 15 else 20.0-(strip-14)*3
			draw_rect(Rect2(anchor+Vector2(shift,3+strip*2),Vector2(width,2)),cloth.darkened(strip%4*0.035))
			draw_rect(Rect2(anchor+Vector2(shift+3,3+strip*2),Vector2(2,2)),cloth.lightened(0.12))
		var sigil := anchor+Vector2(9,13)
		draw_rect(Rect2(sigil,Vector2(2,10)),cloth.lightened(0.28))
		draw_rect(Rect2(sigil+Vector2(-3,3),Vector2(2,5)),cloth.lightened(0.28))
		draw_rect(Rect2(sigil+Vector2(3,1),Vector2(2,5)),cloth.lightened(0.28))
