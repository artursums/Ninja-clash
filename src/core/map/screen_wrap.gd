class_name ScreenWrap
extends RefCounted
## Pure coordinate-wrap helpers (design/gdd/map.md — Formula: Position wrap). Used by Movement
## and Projectile to wrap entities across playfield edges. The double-fmod-plus-size idiom wraps
## negative coordinates into a positive range (GDScript fmod alone does not).

const INTERNAL_WIDTH := 480.0
const INTERNAL_HEIGHT := 270.0
const TILE_SIZE := 16


## Wrap `value` into the range [0, size). Correct for negative and multi-wrap inputs.
static func wrap_axis(value: float, size: float) -> float:
	return fmod(fmod(value, size) + size, size)


## Wrap a position using a map's per-axis wrap flags. Axes with wrap disabled pass through.
static func wrap_position(pos: Vector2, map: MapResource) -> Vector2:
	var p := pos
	if map.horizontal_wrap:
		p.x = wrap_axis(p.x, map.playfield_width)
	if map.vertical_wrap:
		p.y = wrap_axis(p.y, map.playfield_height)
	return p
