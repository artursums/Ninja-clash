extends RefCounted
## Pure, side-effect-free decision helpers for the bot AI (player.gd `_bot_think`). Kept static and
## dependency-free (no scene tree, no autoloads) so the decision rules are unit-testable in isolation;
## player.gd supplies the runtime facts (counts, geometry) and applies the resulting intent.


# Head-stomp is a strict LAST RESORT. A bot may deliberately pursue or execute a head-stomp ONLY when
# it is fully disarmed — no shurikens (stash) AND no katana charges — AND there is no loose blade
# worth scavenging (re-arming always beats a desperation stomp). While it still has any shuriken,
# any katana charge, or a reachable dropped blade, it must never aim for the opponent's head.
static func should_stomp(stash: int, katana_charges: int, has_scavengeable_blade: bool) -> bool:
	return stash <= 0 and katana_charges <= 0 and not has_scavengeable_blade


# Plant the guard (block) as a survival fallback: there's an incoming threat the bot can't dodge
# (dodge on cooldown) and it has enough guard meter left to be worth committing (blocking on a
# near-empty meter just breaks the guard instantly). Costs guard meter, not a katana charge.
static func should_guard(has_incoming: bool, dodge_on_cooldown: bool, guard_meter: float, min_meter: float) -> bool:
	return has_incoming and dodge_on_cooldown and guard_meter >= min_meter


# Choose a platform to contest for HIGH GROUND. Returns the index into `platforms` (Rect2 array,
# each rect in world space with position = top-left) of the nearest perch that sits meaningfully
# ABOVE both the foe (so we can rain shurikens down) and ourselves (so it's an actual height gain),
# or -1 when no such perch exists. "Above" = smaller Y. Pure: takes plain geometry, no scene tree.
static func pick_high_ground(platforms: Array, self_pos: Vector2, foe_pos: Vector2, margin: float) -> int:
	var best: int = -1
	var best_d: float = 1e9
	for i in platforms.size():
		var r: Rect2 = platforms[i]
		var top: float = r.position.y
		if top >= foe_pos.y - margin:
			continue                     # not meaningfully above the foe
		if top >= self_pos.y - 4.0:
			continue                     # not above us either → no height gained
		var cx: float = r.position.x + r.size.x * 0.5
		var hd: float = absf(cx - self_pos.x)
		if hd < best_d:
			best_d = hd
			best = i
	return best
