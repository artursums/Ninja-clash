extends Sprite2D
## Film-style katana slash trail — a 5-frame swept crescent sprite sheet (same approach as the
## clash-lightning FX: a horizontal strip, additive). Frames are baked white, so modulate tints the
## crescent to the fighter's clan colour. Plays OVER the blade swing (it doesn't replace it): the
## owning player drives the frame from swing progress so the trail sweeps in sync with the blade.

const SHEET := "res://sprites/fx/katana_slash_5frame_native_400x80.png"
const FRAMES := 5
const FRAME_PX := 80.0
# The hand/pivot baked into each frame (see generate_slash.py PIVOT); offset anchors it on the origin
# so the arc stays pinned to the hand and mirrors cleanly via a negative scale.x.
const PIVOT := Vector2(34.0, 46.0)

var _tint: Color = Color(0.7, 0.9, 1.0)


func _ready() -> void:
	texture = load(SHEET)
	hframes = FRAMES
	vframes = 1
	frame = 0
	centered = true
	offset = Vector2(FRAME_PX, FRAME_PX) * 0.5 - PIVOT   # put the baked hand pivot on the node origin
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR    # smooth (film-style), not pixelated
	z_index = 55                                         # above the blade + fighters
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	visible = false


func set_tint(c: Color) -> void:
	_tint = c


# Drive the slash for swing progress p∈[0,1] facing `dir` (+1 right / -1 left). The blade is drawn
# separately by the player; this is the trailing crescent over it.
func play(p: float, dir: int) -> void:
	visible = true
	position = Vector2(dir * 7.0, -1.0)        # anchored at the hand, same spot as the blade
	scale = Vector2(dir * 0.72, 0.72)          # tucked in so the arc grazes the blade edge, not ahead of it
	frame = clampi(int(p * FRAMES), 0, FRAMES - 1)
	modulate = _tint                           # per-frame fade is baked into the sheet


func stop() -> void:
	visible = false
