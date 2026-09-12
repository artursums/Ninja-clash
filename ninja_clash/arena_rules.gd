extends RefCounted

const WIDTH := 880.0
const HEIGHT := 495.0
const SIZE := Vector2(WIDTH, HEIGHT)
const UI_SIZE := Vector2(800, 450)

static func wrap_position(point: Vector2) -> Vector2:
	# The physical world repeats at its actual dimensions. Padding creates unsupported
	# space beyond a floor and changes the arrival height during horizontal crossings.
	return Vector2(wrapf(point.x, 0.0, WIDTH), wrapf(point.y, 0.0, HEIGHT))

static func seam_offsets(rect: Rect2) -> Array[Vector2]:
	var horizontal: Array[float] = [0.0]
	var vertical: Array[float] = [0.0]
	if rect.position.x <= 0: horizontal.append(WIDTH)
	if rect.end.x >= WIDTH: horizontal.append(-WIDTH)
	if rect.position.y <= 0: vertical.append(HEIGHT)
	if rect.end.y >= HEIGHT: vertical.append(-HEIGHT)
	var result: Array[Vector2] = []
	for x in horizontal:
		for y in vertical:
			if x != 0 or y != 0:
				result.append(Vector2(x,y))
	return result
