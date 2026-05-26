class_name MapValidator
extends RefCounted
## Validates a MapResource against the shippable contract (design/gdd/map.md — Core Rule 9 +
## Edge Cases). Returns a list of problems ([] == valid) so callers can report them all at once.
##
## SCOPE NOTE (Sprint 2): the load-bearing trajectory-sweep recoverability sim (fire
## VALIDATOR_SAMPLE_ANGLES throws per spawn, assert each settles reachable) needs Projectile
## physics — it lands in Sprint 3 alongside the Projectile system. This covers the static,
## physics-free checks: spawn count, metadata completeness, and the designer assertion.

const REQUIRED_SPAWN_POINTS := 4


## Returns a list of human-readable problems. Empty == valid.
static func validate(map: MapResource) -> Array[String]:
	var errors: Array[String] = []
	if map == null:
		errors.append("MapResource is null")
		return errors
	if map.id == &"":
		errors.append("map id is empty")
	if map.display_name.is_empty():
		errors.append("display_name is empty")
	if map.spawn_points.size() != REQUIRED_SPAWN_POINTS:
		errors.append("expected %d spawn points, got %d" % [REQUIRED_SPAWN_POINTS, map.spawn_points.size()])
	if not map.recoverability_validated:
		errors.append("recoverability_validated must be true to ship (Core Rule 9)")
	var rpc := map.recommended_player_count
	if rpc.x < 1 or rpc.y > 4 or rpc.x > rpc.y:
		errors.append("recommended_player_count out of range: %s" % rpc)
	return errors


static func is_valid(map: MapResource) -> bool:
	return validate(map).is_empty()
