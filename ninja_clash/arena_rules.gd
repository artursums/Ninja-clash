extends RefCounted

const WIDTH := 960.0
const HEIGHT := 540.0
const SIZE := Vector2(WIDTH, HEIGHT)
const UI_SIZE := Vector2(800, 450)

# Keep simulation coordinates independent of the fixed overview camera and UI.
static func wrap_position(point: Vector2, margin: Vector2) -> Vector2:
	if point.x < -margin.x or point.x >= WIDTH + margin.x:
		point.x = wrapf(point.x, -margin.x, WIDTH + margin.x)
	if point.y < -margin.y or point.y >= HEIGHT + margin.y:
		point.y = wrapf(point.y, -margin.y, HEIGHT + margin.y)
	return point
