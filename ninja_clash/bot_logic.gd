extends RefCounted
## Geometry and combat rules shared by the tactical CPU and its regression tests.


# Head-stomp is a strict LAST RESORT. A bot may deliberately pursue or execute a head-stomp ONLY when
# it is fully disarmed — no shurikens (stash) AND no katana charges — AND there is no loose blade
# worth scavenging (re-arming always beats a desperation stomp). While it still has any shuriken,
# any katana charge, or a reachable dropped blade, it must never aim for the opponent's head.
static func should_stomp(stash: int, katana_charges: int, has_scavengeable_blade: bool) -> bool:
	return stash <= 0 and katana_charges <= 0 and not has_scavengeable_blade


static func aim_octant(offset: Vector2) -> Vector2:
	if offset.length_squared() < 0.01:
		return Vector2.RIGHT
	var angle := snappedf(offset.angle(), PI / 4.0)
	return Vector2(roundf(cos(angle)), roundf(sin(angle)))


# Relative motion rejects projectiles that pass nearby without intersecting the fighter.
static func impact_time(offset: Vector2, relative_velocity: Vector2, radius: float = 25.0) -> float:
	var speed_squared := relative_velocity.length_squared()
	if speed_squared < 1:
		return INF
	var closest := -offset.dot(relative_velocity) / speed_squared
	if closest < 0 or (offset + relative_velocity * closest).length() > radius:
		return INF
	return closest
