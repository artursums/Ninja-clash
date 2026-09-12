extends RefCounted

const START := 0.025
const END := 0.285
const REACH := 46.0
const HALF_HEIGHT := 27.0

static func active(elapsed: float) -> bool:
	return elapsed >= START and elapsed <= END

static func intersects(origin: Vector2, facing: int, previous: Vector2, current: Vector2) -> bool:
	var a := previous - origin
	var b := current - origin
	a.x *= facing
	b.x *= facing
	var box := Rect2(-3, -HALF_HEIGHT, REACH + 3, HALF_HEIGHT * 2)
	if box.has_point(b):
		return true
	# Sweeping the travelled segment avoids missed parries between physics ticks.
	var delta := b - a
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.0001:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return false
		else:
			var first := (box.position[axis] - a[axis]) / delta[axis]
			var last := (box.end[axis] - a[axis]) / delta[axis]
			enter = maxf(enter, minf(first, last))
			leave = minf(leave, maxf(first, last))
			if enter > leave:
				return false
	return true
