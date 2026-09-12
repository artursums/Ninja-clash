extends Node2D

const Art := preload("res://fighter_art.gd")
var _tint := Color(0.7, 0.9, 1.0)
var _progress := 0.0
var _outer := PackedVector2Array()
var _inner := PackedVector2Array()

func _ready() -> void:
	z_index = 2
	visible = false
	_outer.resize(9)
	_inner.resize(9)

func set_tint(color: Color) -> void:
	_tint = color

func play(progress: float, direction: int) -> void:
	_progress = progress
	visible = progress > 0.16 and progress < 0.78
	if not visible:
		return
	var hand := Art.sword_hand(progress)
	position = Vector2(hand.x * direction, hand.y)
	scale = Vector2(direction, 1)
	var start := Art.sword_angle(maxf(0.12, progress - 0.17))
	var end := Art.sword_angle(progress)
	for i in 9:
		var angle := lerpf(start, end, i / 8.0)
		_outer[i] = (Vector2.RIGHT.rotated(angle) * 29).round()
		_inner[i] = (Vector2.RIGHT.rotated(angle) * 24).round()
	queue_redraw()

func _draw() -> void:
	var strength := sin(clampf((_progress - 0.16) / 0.62, 0, 1) * PI)
	draw_polyline(_inner, Color(_tint, strength * 0.25), 4)
	draw_polyline(_outer, Color(_tint.lightened(0.45), strength * 0.8), 2)
	draw_rect(Rect2(_outer[8] - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 0.9, strength))

func stop() -> void:
	visible = false
