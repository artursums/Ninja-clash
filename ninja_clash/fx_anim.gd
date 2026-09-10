# One-shot sprite-strip FX (strike flash, clash lightning, ...). Plays its frames
# once on REAL time so it keeps animating even while Engine.time_scale is 0 during
# a clash hitstop, then frees itself.
#
# Usage (from a spawner):
#   var fx := Sprite2D.new()
#   fx.set_script(load("res://fx_anim.gd"))
#   fx.frame_count = 5; fx.fps = 12.0
#   fx.texture = load(strip_path)
#   fx.position = world_pos; fx.scale = Vector2(2, 2); fx.z_index = 50
#   parent.add_child(fx)

extends Sprite2D

var frame_count: int = 5      # frames in the horizontal strip
var fps: float = 12.0         # playback speed (real-time)

var _start_t: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	hframes = frame_count
	vframes = 1
	frame = 0
	_start_t = Time.get_ticks_msec() / 1000.0

func _process(_delta: float) -> void:
	# Real-time clock — unaffected by Engine.time_scale, so the animation runs
	# through the clash freeze instead of stalling with the rest of the scene.
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_t
	var f: int = int(elapsed * fps)
	if f >= frame_count:
		queue_free()
		return
	frame = f
