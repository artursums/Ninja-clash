extends RefCounted

enum Kind { NONE, MISDIRECTION, SEEKER, SWAP, RICOCHET }
const NAMES := ["", "REVERSE", "SEEKER", "PHASE SWAP", "RICOCHET"]
const COLORS := [Color.WHITE, Color("e87bff"), Color("f8d367"), Color("71eddd"), Color("ff9c54")]
const CHARGES := [0, 1, 2, 1, 2]
const REVERSE_SECONDS := 3.0
const SEEK_SECONDS := 2.0
const RICOCHET_SECONDS := 3.0
const MAX_BOUNCES := 3
const FONT := preload("res://fonts/PixelifySans.ttf")

static func terrain(tree: SceneTree) -> Array:
	var result: Array = []
	for body in tree.get_nodes_in_group("arena_solids") + tree.get_nodes_in_group("crumble_platforms"):
		if body.is_queued_for_deletion() or body.collision_layer == 0:
			continue
		for shape in body.get_children():
			if shape is CollisionShape2D and not shape.disabled and shape.shape is RectangleShape2D:
				result.append({"rect": Rect2(shape.global_position - shape.shape.size * 0.5, shape.shape.size), "body": body})
	return result

# Segment against an expanded rectangle; the entry normal determines a physical bounce.
static func sweep(from: Vector2, motion: Vector2, rect: Rect2) -> Dictionary:
	var enter := 0.0
	var leave := 1.0
	var normal := Vector2.ZERO
	for axis in 2:
		if absf(motion[axis]) < 0.00001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return {}
			continue
		var a: float = (rect.position[axis] - from[axis]) / motion[axis]
		var b: float = (rect.end[axis] - from[axis]) / motion[axis]
		var n := Vector2.ZERO
		n[axis] = -signf(motion[axis])
		if minf(a, b) >= enter:
			enter = minf(a, b)
			normal = n
		leave = minf(leave, maxf(a, b))
		if enter > leave:
			return {}
	if leave < 0 or enter > 1 or normal == Vector2.ZERO:
		return {}
	return {"fraction": maxf(0, enter), "normal": normal}

static func draw_icon(canvas: CanvasItem, kind: int, at: Vector2, size: float = 10.0) -> void:
	var color: Color = COLORS[kind]
	var s := size * 0.55
	match kind:
		Kind.MISDIRECTION:
			canvas.draw_line(at + Vector2(-s, -3), at + Vector2(s, -3), color, 2)
			canvas.draw_line(at + Vector2(-s, 3), at + Vector2(s, 3), color, 2)
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-s+4,-7), at+Vector2(-s,-3), at+Vector2(-s+4,1)]),color,2)
			canvas.draw_polyline(PackedVector2Array([at + Vector2(s-4,-1), at+Vector2(s,3), at+Vector2(s-4,7)]),color,2)
		Kind.SEEKER:
			canvas.draw_arc(at, s, 0, TAU, 16, color, 2)
			canvas.draw_line(at-Vector2(s+3,0),at+Vector2(s+3,0),color,1)
			canvas.draw_line(at-Vector2(0,s+3),at+Vector2(0,s+3),color,1)
		Kind.SWAP:
			canvas.draw_arc(at-Vector2(4,0),s,-PI/2,PI/2,12,color,2)
			canvas.draw_arc(at+Vector2(4,0),s,PI/2,PI*1.5,12,color,2)
		Kind.RICOCHET:
			canvas.draw_polyline(PackedVector2Array([at+Vector2(-s,4),at+Vector2(0,-s),at+Vector2(s,4)]),color,2)
			canvas.draw_line(at+Vector2(-s-2,-s-3),at+Vector2(s+2,-s-3),color,2)
