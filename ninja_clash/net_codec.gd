class_name NetCodec
extends RefCounted
## Pure encode/decode helpers for the online layer (ADR-0003) — no scene-tree or autoload
## dependencies, so every wire format is unit-testable headless (GUT `-s` mode).
##
## Wire formats:
##  • Intent — the 10 sim actions of one player packed into two ints (held + just-pressed
##    bitmasks). The client sends these to the host every physics tick; the host feeds them
##    into PlayerInputRouter as slot 2's intent.
##  • Player snapshot — one Array per fighter with position/velocity/state/timed-window
##    phases, applied to a puppet player on the client.
##  • Projectile snapshot — one Array per live shuriken / blade wave.

## Sim action suffixes, index = bit position in the intent masks. MUST stay in sync with
## PlayerInputRouter.ACTIONS (asserted by the unit tests).
const ACTIONS := ["left", "right", "aim_up", "aim_down", "jump", "throw", "katana", "dodge", "slide", "defend"]

## Player snapshot array layout (indices).
enum P {
	SLOT, X, Y, VX, VY, FACING, ALIVE, HP, STASH, KATANA,
	GUARD, FLAGS, SWING_PHASE, CHARGE_PHASE, AIM_X, AIM_Y, HURT_LEFT, SIZE
}

## Player snapshot flag bits.
const F_SWINGING := 1
const F_DEFENDING := 2
const F_SLIDING := 4
const F_AIMING := 8
const F_WALL_GRAB := 16
const F_CHARGING := 32
const F_CHARGE_READY := 64
const F_GUARD_CD := 128

## Shuriken snapshot array layout.
enum S { ID, X, Y, VX, VY, STUCK, THROWER, RICOCHET, SIZE }

## Blade-wave snapshot array layout.
enum W { ID, X, Y, VX, VY, THROWER, SIZE }


## Pack per-action bools into an int bitmask, in ACTIONS order.
static func pack_mask(values: Dictionary) -> int:
	var mask: int = 0
	for i in ACTIONS.size():
		if values.get(ACTIONS[i], false):
			mask |= 1 << i
	return mask


## True when `action_suffix`'s bit is set in `mask`.
static func mask_has(mask: int, action_suffix: String) -> bool:
	var i: int = ACTIONS.find(action_suffix)
	return i >= 0 and (mask & (1 << i)) != 0


## Snapshot one live fighter into a plain Array (host side). `now` = host real-time seconds;
## timed windows are shipped as relative phases so the client can rebase them onto its clock.
static func encode_player(p: Node, now: float) -> Array:
	var arr: Array = []
	arr.resize(P.SIZE)
	arr[P.SLOT] = p.slot
	arr[P.X] = p.position.x
	arr[P.Y] = p.position.y
	arr[P.VX] = p.velocity.x
	arr[P.VY] = p.velocity.y
	arr[P.FACING] = p.facing
	arr[P.ALIVE] = p.alive
	arr[P.HP] = p.hp
	arr[P.STASH] = p.stash
	arr[P.KATANA] = p.katana_charges
	arr[P.GUARD] = p.guard_meter
	var flags: int = 0
	if p.is_swinging: flags |= F_SWINGING
	if p.is_defending: flags |= F_DEFENDING
	if p.is_sliding: flags |= F_SLIDING
	if p.is_aiming: flags |= F_AIMING
	if p.is_wall_grabbing: flags |= F_WALL_GRAB
	if p.katana_charging: flags |= F_CHARGING
	if p.katana_charge_ready: flags |= F_CHARGE_READY
	if now < p.guard_cooldown_until: flags |= F_GUARD_CD
	arr[P.FLAGS] = flags
	arr[P.SWING_PHASE] = (now - p.swing_start_t) if p.is_swinging else -1.0
	arr[P.CHARGE_PHASE] = (now - p.katana_press_t) if p.katana_charging else -1.0
	var aim: Vector2 = p._aim_locked_dir if p._aim_locked_dir != Vector2.ZERO else p.aim_dir
	arr[P.AIM_X] = aim.x
	arr[P.AIM_Y] = aim.y
	arr[P.HURT_LEFT] = maxf(0.0, p.hurt_iframe_until - now)
	return arr


## Apply a player snapshot Array onto a client-side puppet fighter. `now` = client real-time
## seconds. Timed windows (swing/charge/hurt/guard-cd) are rebased onto the client clock so the
## puppet's visual code reads them exactly like the host's own fields.
static func apply_player(p: Node, arr: Array, now: float) -> void:
	if arr.size() < P.SIZE:
		return
	var was_alive: bool = p.alive
	p.net_target_pos = Vector2(arr[P.X], arr[P.Y])
	p.net_has_target = true
	p.velocity = Vector2(arr[P.VX], arr[P.VY])
	p.facing = int(arr[P.FACING])
	p.alive = bool(arr[P.ALIVE])
	p.hp = int(arr[P.HP])
	p.stash = int(arr[P.STASH])
	p.katana_charges = int(arr[P.KATANA])
	p.guard_meter = float(arr[P.GUARD])
	var flags: int = int(arr[P.FLAGS])
	p.is_swinging = (flags & F_SWINGING) != 0
	p.is_defending = (flags & F_DEFENDING) != 0
	p.is_sliding = (flags & F_SLIDING) != 0
	p.is_aiming = (flags & F_AIMING) != 0
	p.is_wall_grabbing = (flags & F_WALL_GRAB) != 0
	p.katana_charging = (flags & F_CHARGING) != 0
	p.katana_charge_ready = (flags & F_CHARGE_READY) != 0
	p.guard_cooldown_until = (now + 1.0) if (flags & F_GUARD_CD) != 0 else 0.0
	if p.is_swinging and float(arr[P.SWING_PHASE]) >= 0.0:
		p.swing_start_t = now - float(arr[P.SWING_PHASE])
	if p.katana_charging and float(arr[P.CHARGE_PHASE]) >= 0.0:
		p.katana_press_t = now - float(arr[P.CHARGE_PHASE])
	var aim := Vector2(arr[P.AIM_X], arr[P.AIM_Y])
	p.aim_dir = aim
	p._aim_locked_dir = aim
	p.hurt_iframe_until = now + float(arr[P.HURT_LEFT])
	# Death/respawn transitions drive the local corpse-topple / cleanup visuals.
	if was_alive and not p.alive:
		p.death_time = now
		p.death_spin_dir = -1 if p.velocity.x < 0.0 else 1
	elif not was_alive and p.alive:
		p.death_time = -1.0
		if p.visual != null:
			p.visual.rotation = 0.0
			p.visual.modulate = Color.WHITE
		p.position = p.net_target_pos   # respawn snaps — never lerp across the arena


## Snapshot one shuriken (host side).
static func encode_shuriken(s: Node) -> Array:
	return [s.net_id, s.position.x, s.position.y, s.velocity_v.x, s.velocity_v.y,
			s.stuck, s.thrower_slot, s.ricocheted]


## Snapshot one blade wave (host side).
static func encode_wave(w: Node) -> Array:
	return [w.net_id, w.position.x, w.position.y, w.velocity_v.x, w.velocity_v.y, w.thrower_slot]
