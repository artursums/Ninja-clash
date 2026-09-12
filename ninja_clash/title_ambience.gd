extends Control

const BIRDS = preload("res://sprites/levels/sakura_temple/birds_4frame_native_56x9.png")
const LANTERNS := [Vector2(648, 125), Vector2(670, 88), Vector2(579, 211), Vector2(709, 245)]

var _elapsed := 0.0
var _birds: Array[Sprite2D] = []
var _lights: Array[Sprite2D] = []
var _mist: Array[Sprite2D] = []
var _motes: Array[Sprite2D] = []

func _ready() -> void:
	size = Vector2(800, 450)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var soft := GradientTexture2D.new()
	soft.width = 64
	soft.height = 64
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = Gradient.new()
	soft.gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	soft.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	for i in 3:
		var fog := _sprite(soft, Color(0.52, 0.58, 0.85, 0.1))
		fog.scale = Vector2(6.5 + i, 0.7 + i * 0.35)
		_mist.append(fog)
	var moon := _sprite(soft, Color(0.63, 0.7, 1.0, 0.12), true)
	moon.position = Vector2(715, 31)
	moon.scale = Vector2.ONE * 2.6
	for anchor in LANTERNS:
		var light := _sprite(soft, Color(1.0, 0.58, 0.22, 0.25), true)
		light.position = anchor
		light.scale = Vector2.ONE * 0.65
		_lights.append(light)
	for i in 7:
		var bird := _sprite(BIRDS, Color(0.48, 0.52, 0.68, 0.7 if i < 4 else 0.5))
		bird.hframes = 4
		bird.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bird.scale = Vector2.ONE * (0.7 if i < 4 else 0.5)
		_birds.append(bird)
	for i in 12:
		var mote := _sprite(soft, Color(1.0, 0.73, 0.36, 0.6), true)
		mote.scale = Vector2.ONE * 0.07
		_motes.append(mote)
	advance(0)

func _sprite(texture: Texture2D, tint: Color, additive: bool = false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if additive:
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = blend
	add_child(sprite)
	return sprite

func advance(delta: float) -> void:
	_elapsed += delta
	for i in _mist.size():
		_mist[i].position = Vector2(490 + sin(_elapsed * 0.055 + i * 2.1) * 120, 295 + i * 49 + sin(_elapsed * 0.09 + i) * 7)
	for i in _lights.size():
		_lights[i].modulate.a = 0.2 + 0.045 * sin(_elapsed * 2.3 + i * 1.7) + 0.025 * sin(_elapsed * 3.7 + i)
	for i in _birds.size():
		var distant := i >= 4
		var member := i - 4 if distant else i
		var travel := fposmod(_elapsed * (15.0 if distant else 23.0) + (80.0 if distant else 570.0), 1120.0)
		var x := 940.0 - travel + member * 22 if distant else travel - 140.0 - member * 24
		var y := (47.0 if distant else 82.0) + member * 7 + sin(_elapsed * 0.8 + i * 0.9) * 3
		_birds[i].position = Vector2(x, y)
		_birds[i].flip_h = distant
		# Short flapping bursts alternate with gliding, with staggered wing phases.
		var phase := fposmod(_elapsed + i * 0.37, 3.8)
		_birds[i].frame = int(phase * 7.0) % 4 if phase < 1.5 else 1
	for i in _motes.size():
		var phase := fposmod(_elapsed * (0.035 + i % 3 * 0.008) + i / 12.0, 1.0)
		_motes[i].position = Vector2(450 + (i * 43) % 320 + sin(_elapsed * 0.35 + i) * 12, 408 - phase * 170)
		_motes[i].modulate.a = sin(phase * PI) * (0.35 + 0.2 * sin(_elapsed * 1.2 + i))
