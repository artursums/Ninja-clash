# Projectile

> **Status**: In Design
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-17
> **Implements Pillar**: Primary — *Every Shuriken Matters*; Secondary — *Game-Feel First*, *Fairness Is Sacred*

## Overview

The Projectile system owns the physical existence of shurikens in Four
Clans — their motion through the air, their collision with walls, their
stick-and-stay behavior on solid surfaces, and their recoverability by
any player who walks within pickup range. Combat owns the throw input
(reading X-button presses, decrementing the player's stash) and the
gameplay rules (one-hit kill, catch hand-off to Movement during dodge
i-frames); Projectile owns everything between Combat creating a shuriken
and Combat picking it back up.

The system has one non-negotiable contract: every shuriken's lifecycle
must end in a recoverable state. A thrown shuriken either flies until it
hits a solid surface (stuck, recoverable), settles on a floor (resting,
recoverable), or wraps around the screen and continues until one of
those two outcomes. No shuriken can ever become permanently lost. This
contract is partner-enforced by Map's build-time recoverability
validator, which simulates Projectile's exact physics from every spawn
point at multiple angles — meaning Projectile's physics must be
deterministic AND the validator's simulation must mirror runtime
behavior exactly.

## Player Fantasy

Every shuriken in flight should feel like a *thing* — a discrete object
with weight, trajectory, and consequence. The thrower watches it leave
their hand and immediately becomes a spectator to their own commitment.
The target watches it arc toward them and reads what they have:
fraction-of-a-second to dodge, to wall-jump out of its line, or to
deflect with i-frames. Every other player on screen reads the throw
too — it's information, ammunition for someone else's read, currency
that just got spent.

When a shuriken hits a wall, it should land with a clean *thunk* — the
audio cue that says "that just happened, that's a thing now, someone
has to go get it." A stuck shuriken is a tactical artifact (per the
Map GDD's Player Fantasy): it marks where someone was, where someone
aimed, which lanes have been contested. A floor littered with three
recoverable shurikens after a round-opening volley creates immediate
decisions — who darts in first, who waits, who flanks. The geometry of
where shurikens land becomes the geometry of the next exchange.

This is *Every Shuriken Matters* expressed at the physics layer. The
shuriken IS the resource economy. Throw arc, wall-thunk, retrieval
lane — these are the verbs Combat is built on top of. Per *Restraint
over Spectacle*, the projectile itself stays understated: a clean
rotating sprite, no glow, no trail, no impact particles beyond a brief
dust puff. The drama is the throw, the dodge, and the silence after.

## Detailed Design

### Core Rules

1. Each shuriken is a Godot `Area2D` node (`ShurikenProjectile`) with a `CollisionShape2D` child. One instance per live shuriken in the world. Instantiated by Combat at throw time; freed by Combat at retrieval time.

2. Projectile is a **"dumb physics" layer**. It does NOT know:
   - Which player threw it (Combat tracks ownership for HUD; Projectile is owner-agnostic)
   - The stash count or any gameplay state
   - Whether a collision should kill or be caught (Combat decides)

   Projectile DOES know:
   - Its current position, velocity, and rotation
   - Whether it's `Flying` or `Stuck` (per States table)
   - Its `recoverable: bool` state (false in Flying, true in Stuck)

3. **Spawn**: when Combat instantiates a Projectile:
   - Combat passes: initial position (`Vector2`), initial direction (`Vector2` unit vector), and `SHURIKEN_THROW_VELOCITY` (px/s).
   - Projectile sets `velocity = direction.normalized() * SHURIKEN_THROW_VELOCITY`.
   - Projectile begins in **Flying** state at the next physics tick.

4. **Flying physics** (each `_physics_process` tick while Flying):
   - `velocity.y += SHURIKEN_GRAVITY_PX_S2 * delta` (gravity; Godot Y-down — positive y = down)
   - `velocity` is clamped to magnitude `≤ SHURIKEN_TERMINAL_VELOCITY_PX_S`
   - `position += velocity * delta` (manual Euler integration — **deterministic for validator parity**)
   - `rotation += SHURIKEN_SPIN_RATE_RAD_S * delta` (visual rotation only)
   - Position is then wrapped via Map's `wrapped_x` / `wrapped_y` if the loaded map's wrap flags are enabled. Velocity preserved.

5. **Wall collision** (Godot Area2D `body_entered` signal):
   - When the Area2D overlaps a body on the **Wall** collision layer (layer 2 per CC GDD): transition to **Stuck** state.
   - Capture `stuck_position = current position`, `stuck_normal = -velocity.normalized()` (inverse of impact velocity — approximate but visually correct; precision raycast deferred to Open Questions). Set `velocity = Vector2.ZERO`.
   - Visual: sprite rendered at `stuck_position`; rotation snapped to "stuck" orientation (perpendicular to wall via `stuck_normal`, embedded by `STICK_VISUAL_DEPTH_PX`).
   - Set `recoverable = true`.

6. **One-way platform collision**: per Map GDD Core Rule 5, shurikens **pass through unchanged** with conserved velocity. Implementation: Projectile's Area2D collision mask **excludes** the OneWay layer (layer 3). Projectile physically interacts only with Wall (layer 2) and Player (layer 1).

7. **Player collision** (Godot Area2D `body_entered` signal):
   - When the Area2D overlaps a body on the **Player** collision layer (layer 1 per CC GDD): emit signal `projectile_hit_player(projectile_id, player_body)`.
   - Projectile does **NOT** decide what happens next — Combat consumes this signal and:
     - Polls `player_body.get_node("PlayerMovement").is_iframe_active()` to decide catch-vs-kill
     - If kill: signals Movement → Dead state; frees this Projectile
     - If catch + stash < STASH_MAX: increments player's stash; frees this Projectile
     - If catch + stash == STASH_MAX: triggers **deflection** physics (Movement Edge Case row 8 contract; Combat owns the deflection math)
   - Projectile stays in Flying state until Combat issues free/transition. Projectile never decides outcomes.

8. **No separate "Resting" state**: "Floor" is a special orientation of Wall (the same collision layer). A shuriken that hits the floor goes Stuck identically to hitting a vertical wall. The visual sprite orients to match the surface normal. Data model has only 2 states (Flying, Stuck).

9. **Pickup detection** (each tick while Stuck):
   - For each player CC within `PICKUP_RADIUS_PX` of `stuck_position`:
     - If their stash < STASH_MAX, they are an **eligible candidate**.
   - Among eligible candidates: smallest distance to `stuck_position` wins. Ties broken by lowest `player_slot` (deterministic, per Pillar 2 fairness).
   - On pickup: emit `projectile_picked_up(projectile_id, player_slot)`. Combat handles stash increment + frees the Projectile.

10. **Recoverability invariant**: A Projectile in Flying must eventually transition to Stuck (or be consumed via Player collision). Map's build-time validator simulates this physics from each spawn point at `VALIDATOR_SAMPLE_ANGLES` directions. **Projectile MUST use the same integration formula** at runtime as the validator runs at build time — otherwise the validator's guarantee is invalidated. (Carried to Open Questions.)

11. **Screen-wrap**: identical handling to player CC per Map GDD Core Rule 6. The wrap formulas (Map's `wrapped_x`, `wrapped_y`) are applied after position update each tick. Velocity preserved.

12. **Ownership-agnostic**: Projectile does not track "who threw me." Combat owns stash accounting via the throw-side and pickup-side signals. Any player can pick up any recoverable shuriken regardless of who threw it.

13. **Lifecycle ends**: Projectile is freed **by Combat** after:
    - Pickup (Combat receives `projectile_picked_up`)
    - Kill (Combat receives `projectile_hit_player` and resolves kill)
    - Catch (same signal, catch branch)
    - Round end (Round Flow signals Combat → Combat frees all Projectiles for clean reset)

    Projectile **never** frees itself.

### States and Transitions

The Projectile FSM has only 2 states. All complexity comes from per-tick
logic within each state, not from state transitions.

| State | Entry | Exit | Behavior |
|---|---|---|---|
| `Flying` | Spawn (Rule 3 — Combat instantiates with position + direction) | Wall `body_entered` → `Stuck` (Rule 5); Player `body_entered` → emit `projectile_hit_player` (state unchanged unless Combat frees) | Gravity application, position integration, sprite rotation, screen-wrap. Collision detection via Godot Area2D signals. `recoverable = false`. |
| `Stuck` | Wall collision (Rule 5) sets `stuck_position`, `stuck_normal`, clears velocity | Pickup eligibility (Rule 9) → emit `projectile_picked_up` → Combat frees; round-end → Combat frees | Stationary at `stuck_position`. Pickup detection runs each tick (Rule 9). Visual rotation snapped per `stuck_normal`. `recoverable = true`. |

**Internal fields:**

| Field | Type | Initialized | Mutated by | Used for |
|---|---|---|---|---|
| `state` | enum (`Flying`, `Stuck`) | Spawn → Flying | Wall collision (Rule 5) | Behavior gate per tick |
| `velocity` | Vector2 | Spawn (`direction × SHURIKEN_THROW_VELOCITY`) | Per-tick gravity (Rule 4); cleared on Stuck (Rule 5) | Position integration |
| `stuck_position` | Vector2 | unset until Stuck | Set on wall collision | Pickup radius math (Rule 9) |
| `stuck_normal` | Vector2 | unset until Stuck | Set on wall collision | Visual orientation |
| `recoverable` | bool | `false` on Spawn | `true` on Stuck | Combat HUD; pickup eligibility |
| `projectile_id` | int | Spawn (Combat assigns) | Never (immutable) | Signal payload; HUD ownership tracking |

**Public queries:**
- `state -> State` (read-only)
- `recoverable -> bool` (read-only; convenience getter equivalent to `state == Stuck`)
- `position: Vector2` (inherited from Node2D)
- `stuck_position: Vector2` (read-only; meaningful only when `Stuck`)

**Signals emitted:**
- `projectile_hit_player(projectile_id: int, player_body: PhysicsBody2D)` — fires once on first overlap with Player layer
- `projectile_picked_up(projectile_id: int, player_slot: int)` — fires once when a player wins pickup eligibility (Rule 9)

Projectile does **not** emit a wall-collision signal. Combat doesn't need to know about wall sticks (audio/visual cues are Visual FX's concern, triggered by polling state transitions if needed).

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **Map** | Projectile reads Map's collision layers (Wall layer 2 for sticking via Area2D `body_entered`; OneWay layer 3 excluded from collision mask for pass-through per Map Core Rule 5). Calls Map's `wrapped_x` / `wrapped_y` formulas for screen-wrap (delegating per Map's Position wrap formula). | Map → Projectile |
| **Combat** | Combat instantiates Projectile (calls constructor with `position`, `direction`, `projectile_id`); connects to `projectile_hit_player` and `projectile_picked_up` signals; reads `Projectile.position` for HUD shuriken display; frees Projectile instances on round end. Combat owns the kill/catch/deflection decisions made on the `projectile_hit_player` signal. | Combat ↔ Projectile |
| **Movement** (indirect, via Combat) | Combat's signal handler for `projectile_hit_player` polls `player_body.get_node("PlayerMovement").is_iframe_active()` to gate kill-vs-catch. Projectile itself does **not** reference Movement. | indirect: Projectile → Combat → Movement |
| **Character Controller** (indirect, via Godot physics) | Projectile's Area2D overlaps CC's `CharacterBody2D` via Godot physics layers. Projectile reads no CC API directly. CC reads no Projectile API directly. The relationship is mediated entirely by Godot's collision layer/mask system. | Godot physics → Projectile signal |
| **Round Flow** (indirect, via Combat) | Round Flow signals Combat at round-end → Combat frees all Projectile instances. Projectile is owner-agnostic and doesn't know about rounds. | indirect: Round Flow → Combat → Projectile |

**Forward contracts (consumers exist but are undesigned):**

- **Visual FX** will subscribe to Projectile state transitions for animation cues (wall-thunk visual, pickup sparkle). Subscription mechanism is Visual FX's choice — polling `state` transitions or asking Projectile to expose new signals. Decision deferred to Visual FX GDD.
- **Audio** will react to wall-thunk and pickup events. Same subscription pattern as Visual FX. Decision deferred to Audio GDD.

If Visual FX or Audio require an event Projectile doesn't currently emit, the request comes back here and Projectile adds a signal — Projectile shouldn't pre-emptively emit signals nobody listens to.

## Formulas

Projectile's math is parabolic trajectory + distance-based pickup detection.
All defaults are starting offers for prototype iteration per Pillar 5.

### Formula 1: Throw direction resolution (Combat → Projectile interface)

Combat computes the throw direction from the player's stick at the moment
of X-button press, then passes it to Projectile's constructor. Same
pattern as Movement Formula 2 (dodge direction) for player mental-model
consistency.

```
function compute_throw_direction(stick: Vector2, facing: int) -> Vector2:
    if stick.length() >= STICK_AIM_THRESHOLD:
        return stick.normalized()
    else:
        return Vector2(facing, 0)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `stick` | Vector2 | length 0 – 1 | CouchInput deadzone output | Player's movement stick at moment of throw |
| `STICK_AIM_THRESHOLD` | float | 0.15 – 0.40 | tuning knob | Default **0.25**. Below this, throw defaults to facing direction |
| `facing` | int | -1, +1 | Movement's `facing` field | Last non-zero horizontal direction from Movement |

**Examples**:
- `stick = (0.7, -0.7)`, `facing = +1` → throw direction = `(0.707, -0.707)` (diagonal up-right).
- `stick = (0.0, 0.0)`, `facing = -1` → throw direction = `(-1, 0)` (horizontal left).
- `stick = (0.0, -0.9)`, `facing = +1` → throw direction = `(0, -1)` (pure upward).

### Formula 2: Per-tick physics integration (Flying state)

Each `_physics_process` tick, while Flying:

```
1. velocity.y += SHURIKEN_GRAVITY_PX_S2 * delta
2. if velocity.length() > SHURIKEN_TERMINAL_VELOCITY_PX_S:
       velocity = velocity.normalized() * SHURIKEN_TERMINAL_VELOCITY_PX_S
3. position += velocity * delta
4. rotation += SHURIKEN_SPIN_RATE_RAD_S * delta
5. if Map.horizontal_wrap: position.x = Map.wrapped_x(position.x, Map.playfield_width)
   if Map.vertical_wrap:   position.y = Map.wrapped_y(position.y, Map.playfield_height)
```

**Order matters**: gravity → terminal clamp → position update → rotation → wrap.
The wrap is **last** so collision detection and the next tick's gravity see
the post-wrap position.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `delta` | float (s) | ~0.0167 (1/60) | Godot `_physics_process` | Per-tick advance |
| `SHURIKEN_GRAVITY_PX_S2` | float | 200 – 1200 | tuning knob | Default **600 px/s²** (half of CC's `GRAVITY = 1200`; shurikens fall slower than ninjas — they're lighter) |
| `SHURIKEN_TERMINAL_VELOCITY_PX_S` | float | 200 – 600 | tuning knob | Default **400 px/s** (sane upper bound on shuriken speed; prevents wall-clipping at extreme velocities) |
| `SHURIKEN_SPIN_RATE_RAD_S` | float | 5 – 30 rad/s | tuning knob | Default **15 rad/s** (~2.4 full rotations per second — feels "fast spin") |

**Example**: Initial throw velocity = `(200, -100)` (rightward + upward). After 1 tick (16.7 ms):
- `velocity.y += 600 * 0.0167 ≈ -100 + 10 = -90` (slightly less upward)
- `velocity.length() ≈ 219` (under terminal); no clamp
- `position += (200, -90) * 0.0167 ≈ position + (3.3, -1.5)` (3.3 px right, 1.5 px up)
- Rotation advances ~0.25 rad (~14°)
- Wrap applied if position crosses edge

### Formula 3: Pickup eligibility + winner selection

Each tick while Stuck:

```
candidates := all PlayerCharacterBody instances with stash < STASH_MAX
eligible := [p for p in candidates
             if distance(p.position, stuck_position) <= PICKUP_RADIUS_PX]
if eligible.is_empty():
    return  # no pickup this tick
eligible.sort_by(key = lambda p: (distance(p.position, stuck_position), p.slot))
winner := eligible[0]
emit projectile_picked_up(projectile_id, winner.slot)
```

The sort uses a tuple key — first by distance (ascending), then by slot
(ascending) to deterministically resolve exact ties.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `stuck_position` | Vector2 | within playfield (480×270) | Set on Stuck transition (Rule 5) | Anchor point for pickup radius math |
| `PICKUP_RADIUS_PX` | float | 6 – 20 px | tuning knob | Default **12 px** (slightly larger than CC's 10×16 hitbox; allows feel of "grazing" the pickup) |
| `p.position` | Vector2 | from CC | CC | Player CC's center position |
| `STASH_MAX` | int | 3 | constant | Per Pillar 4 (Every Shuriken Matters), locked at 3 |
| `p.slot` | int | 1, 2, 3, 4 | CouchInput slot assignment | Deterministic tiebreak |

**Example**: Shuriken stuck at `(100, 50)`. Player 1 at `(95, 55)` (distance 7.07), stash 1/3. Player 3 at `(110, 50)` (distance 10), stash 0/3. Both eligible. Player 1 wins (closer). Signal fires `projectile_picked_up(projectile_id, 1)`.

### Formula 4: Closed-form trajectory (informational — validator parity)

For Map's build-time recoverability validator, the closed-form parabolic
trajectory (no collision, no terminal-velocity clamp):

```
At time t after throw (Flying, no collision, no clamp):
    velocity_t = Vector2(direction.x * V,
                          direction.y * V + G * t)
    position_t = position_0 + Vector2(direction.x * V * t,
                                       direction.y * V * t + 0.5 * G * t^2)
```

Where `V = SHURIKEN_THROW_VELOCITY` (Combat-owned) and `G = SHURIKEN_GRAVITY_PX_S2`.

| Variable | Type | Source | Description |
|---|---|---|---|
| `V` | float | Combat tuning knob `SHURIKEN_THROW_VELOCITY` | Combat will pin; estimate ~200 px/s for validator placeholder |
| `G` | float | Projectile tuning knob `SHURIKEN_GRAVITY_PX_S2` | Per Formula 2 (default 600) |
| `direction` | Vector2 | per-throw input | Per Formula 1 |
| `t` | float (s) | simulated time | Validator's time-step (typically 1/60 s for parity) |

This formula is **informational** — runtime always uses Euler (Formula 2).
Listed here so the validator implementer has the closed form for reference
/ cross-checking. **For perfect parity, the validator SHOULD use the same
per-tick Euler integration that runtime uses.** If closed-form is used,
validator must match runtime tolerances within `VALIDATOR_POSITION_EPSILON_PX`
(suggested 0.5 px). Carried to Open Questions.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Pickup eligibility across screen-wrap boundary | Pickup distance does NOT respect wrap in v1 — uses straight-line `distance(p.position, stuck_position)`. Player must approach from the same side as the stuck shuriken. | Simpler v1; flagged in Open Questions for playtest revisit if confusion appears at wrap edges |
| Shuriken passes through two players in one tick (stacked players) | Area2D `body_entered` fires once per overlap. Combat receives two `projectile_hit_player` signals (one per player) and resolves each independently. | Standard Godot signal semantics; Combat owns multi-hit logic |
| Two shurikens collide mid-air | Pass through each other. Projectile's collision mask includes only Wall + Player; OneWay and other Projectiles are excluded. | TowerFall behavior; shurikens are point particles to each other |
| Throw direction is `Vector2.ZERO` (defensive — impossible via Formula 1) | Cannot occur: Formula 1 always returns a unit vector (`stick.normalized()` or `Vector2(facing, 0)` with `facing ∈ {-1, +1}`). If somehow passed, Projectile defensively defaults to `Vector2(1, 0)`. | Defensive guard; should never trigger |
| Projectile spawns overlapping the thrower's CC body | Projectile fires `projectile_hit_player` against the thrower. **Combat decides** whether to ignore self-hits (requires Combat to track thrower per `projectile_id`). Projectile itself is owner-agnostic. | Forward contract for Combat GDD |
| Validator-vs-runtime trajectory divergence | The validator and runtime MUST use the same integration code (Formula 2). If closed-form (Formula 4) is used, validator must match runtime to `VALIDATOR_POSITION_EPSILON_PX` (suggested 0.5 px). If divergence exceeds epsilon, recoverability is violated. | Load-bearing — the 100% recoverability guarantee depends on parity. Carried to Open Questions |
| High-velocity tunneling through thin walls | Max distance per tick at terminal velocity = ~6.7 px (400 px/s × 16.7 ms). All Map tiles are ≥ 16 px wide (`TILE_SIZE = 16`). No tunneling possible within velocity bounds. Designer must not author sub-tile-thin walls (Map's validator should check). | Defensive: velocity clamping + tile-size invariant prevent the case |
| Pickup with exact floating-point distance tie between two players | Sort key `(distance, slot)` deterministically resolves: lower slot wins. | Per Pillar 2 (Fairness Is Sacred) — outcome is deterministic, never random |
| Combat manually frees Projectile mid-Flying (round-end) | Godot's `queue_free()` is safe. Projectile suppresses signal emission post-free (Godot handles this; emitted signals to a queued-free node are dropped). | Standard Godot lifecycle |
| Initial throw position outside playfield bounds | Map's `wrapped_x` / `wrapped_y` applied on first tick wraps the position into bounds. Subsequent physics is normal. | Wrap formula is robust to any input position |
| Shuriken sticks on a wall partially outside playfield (impossible — Map enforces) | Cannot occur — Map's validator requires walls within playfield bounds. If it somehow occurred, pickup detection would work but visual rendering could clip. | Validator owns prevention |
| Shuriken in perpetual fall (`vertical_wrap=true` + no floor) | Map's build-time validator catches this per Map Core Rule 9. At runtime on a validated map: cannot occur. If an unvalidated map is loaded, shuriken flies until manually freed (round-end). | Designer responsibility; validator enforcement |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| **Map** | Projectile depends on Map | Reads collision layers (Wall layer 2 for sticking; OneWay layer 3 excluded from mask). Uses Map's `wrapped_x`/`wrapped_y` formulas for screen-wrap. Map's `playfield_width`/`playfield_height` for wrap bounds. |
| **Combat** | Combat depends on Projectile | Instantiates Projectile (constructor with `position`, `direction`, `projectile_id`); connects to `projectile_hit_player` and `projectile_picked_up` signals; reads `Projectile.position`, `Projectile.recoverable`, `Projectile.state` for HUD and game logic; frees Projectile on round end and on resolved hits |
| **Movement** (indirect, via Combat) | no direct dependency | Combat's `projectile_hit_player` handler polls `Movement.is_iframe_active()` — Projectile does not call Movement directly |
| **Character Controller** (indirect, via Godot physics) | no direct dependency | Projectile's Area2D overlaps CC's `CharacterBody2D` via collision layer/mask system — no API calls between them |
| **Round Flow** (indirect, via Combat) | no direct dependency | Round Flow signals Combat at round-end; Combat frees all Projectiles |
| **Visual FX** (forward contract) | Visual FX will depend on Projectile | Will subscribe to state transitions or new signals for wall-thunk visual and pickup sparkle — Visual FX GDD decides subscription mechanism |
| **Audio** (forward contract) | Audio will depend on Projectile | Will react to wall-thunk and pickup events — Audio GDD decides subscription mechanism |

**External dependencies:**
- Godot 4.6 `Area2D` (with `body_entered` signal for overlap detection)
- Godot 4.6 `CollisionShape2D` (collision geometry)
- Godot 4.6 `_physics_process(delta)` (60 Hz fixed tick for integration)
- Godot 4.6 32-bit collision layer/mask system
- Map's build-time recoverability validator (CLI / editor plugin TBD per Map GDD)

**Bidirectional consistency notes:**

- `design/gdd/systems-index.md` correctly lists Projectile as depending on Map (Core Layer row 6); Combat's row already lists Projectile as a dep. **No updates needed.**
- `design/gdd/map.md` Interactions table already lists Projectile correctly. ✓
- `design/gdd/game-concept.md` Dependencies row for Combat lists Projectile. ✓
- Combat GDD does not exist yet. Its dependency on Projectile (with the specific signal connections specified in Rules 3, 7, 9, 13) will need to be honored when Combat is designed.
- Visual FX + Audio GDDs do not exist yet. They may add Projectile as a direct dep (vs accessing it indirectly via Combat) when designed. Flagged in Open Questions.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `SHURIKEN_GRAVITY_PX_S2` | 600 px/s² | 200 – 1200 | Steeper arcs; shorter horizontal range per throw; more floor pickups | Floatier shurikens; longer horizontal range; harder dodge reads |
| `SHURIKEN_TERMINAL_VELOCITY_PX_S` | 400 px/s | 200 – 600 | Faster maximum shuriken speed; tightens dodge reaction window | Slower max; more time to read incoming shurikens |
| `SHURIKEN_SPIN_RATE_RAD_S` | 15 rad/s | 5 – 30 | Faster visual spin; more "lethal-looking"; cosmetic | Slower spin; more "lazy" feel; cosmetic |
| `PICKUP_RADIUS_PX` | 12 px | 6 – 20 | Easier retrieval; less commitment to lining up perfectly | Tighter pickup feel; rewards precise positioning |
| `STICK_AIM_THRESHOLD` | 0.25 | 0.15 – 0.40 | Stick must be pushed harder for aimed throw (defaults to facing) | More sensitive — slight stick tilt aims (no default-facing) |
| `STICK_VISUAL_DEPTH_PX` | 4 px | 0 – 8 | Shuriken appears more embedded in wall (heavier stick visual) | Less embedded; shuriken hovers on wall surface |
| `VALIDATOR_POSITION_EPSILON_PX` | 0.5 px | 0.1 – 2.0 | Validator tolerates more runtime drift before flagging recoverability violation | Stricter parity required between validator + runtime |

**Referenced from other systems (not owned here):**
- `SHURIKEN_THROW_VELOCITY` (Combat-owned per concept doc) — Projectile receives as constructor parameter; recommended starting value ~200 px/s pending Combat GDD pin.
- `STASH_MAX` (Combat-owned, locked at 3 by Pillar 4) — Projectile reads via candidate player stash field for pickup eligibility (Formula 3).
- `TILE_SIZE` (Map constant, 16 px) — Projectile assumes Map tiles ≥ 16 px wide to prevent tunneling.
- `playfield_width`, `playfield_height` (Map per-instance) — Projectile uses for screen-wrap (Formula 2).
- CC's `GRAVITY_PX_S2` (1200) — Projectile's `SHURIKEN_GRAVITY` is half of this by default (shurikens lighter than ninjas).

**Interactions to watch:**

- `SHURIKEN_TERMINAL_VELOCITY_PX_S` × `TILE_SIZE`: max distance per tick = `TERMINAL / 60`. Must be < `TILE_SIZE` to prevent tunneling. At default (400 / 60 = 6.7 px) and `TILE_SIZE = 16`, safety margin = ~2.4×. Raising terminal above 960 px/s (16 × 60) would risk tunneling.
- `SHURIKEN_GRAVITY` × `SHURIKEN_THROW_VELOCITY` (Combat): determines parabolic arc shape. Skill expression on arc-reading depends on both.
- `PICKUP_RADIUS_PX` × CC hitbox (10×16 per CC GDD): radius slightly larger than hitbox gives "graze" feel. If too small, players must stand directly on the shuriken; too large feels magnetic.

**Not knobs**: physics tick rate (60 Hz fixed); collision layer indices (architectural); button mapping (locked per CouchInput); `STASH_MAX` (Pillar 4 locked at 3); shuriken sprite asset (art-direction decision, not designer-tunable).

**Concept doc updates required**:
1. `shuriken_wall_stick_duration_s` row is stale (currently "TBD or permanent until retrieved") — resolve to "**permanent until retrieved** *(resolved 2026-05-17 during Projectile GDD design)*"
2. `pickup_radius_px` row should change **Owner from Combat → Projectile**, note default 12 px *(updated 2026-05-17 during Projectile GDD design — pickup detection logic lives in Projectile per Rule 9)*

## Acceptance Criteria

### Spawn / lifecycle

- [ ] Combat-instantiated Projectile begins in Flying state at the next physics tick
- [ ] `velocity` at spawn = `direction.normalized() * SHURIKEN_THROW_VELOCITY`
- [ ] `state == Flying`, `recoverable == false` at spawn
- [ ] Projectile never frees itself; only Combat calls `queue_free()`

### Flying physics

- [ ] Per tick: `velocity.y += SHURIKEN_GRAVITY_PX_S2 * delta`
- [ ] Velocity magnitude is clamped to `SHURIKEN_TERMINAL_VELOCITY_PX_S`
- [ ] Position updates via Euler: `position += velocity * delta`
- [ ] Rotation advances at `SHURIKEN_SPIN_RATE_RAD_S` per second
- [ ] Order of operations preserved: gravity → clamp → position → rotation → wrap (verified via instrumented test)

### Wall collision + Stick

- [ ] `body_entered` on Wall layer (2) → transition to Stuck
- [ ] On Stuck transition: `stuck_position = current position`, `stuck_normal = computed from overlap`, `velocity = Vector2.ZERO`
- [ ] Visual: sprite snapped to `stuck_position`, rotation oriented per `stuck_normal`, embedded by `STICK_VISUAL_DEPTH_PX`
- [ ] `recoverable` becomes `true` on Stuck
- [ ] Stuck state has no per-tick physics updates (no gravity, no position change, no rotation)

### One-way platform pass-through

- [ ] OneWay layer (3) is NOT in Projectile's collision mask
- [ ] Shuriken trajectory continues unchanged when overlapping one-way platforms
- [ ] Velocity preserved across one-way intersection (no slowdown, no deflection)

### Player collision + signal

- [ ] `body_entered` on Player layer (1) → emit `projectile_hit_player(projectile_id, player_body)` exactly once per overlap
- [ ] Projectile state remains Flying (does NOT auto-transition on player hit)
- [ ] Combat is responsible for freeing or transitioning the Projectile after handling the signal
- [ ] Multiple simultaneous player overlaps fire one signal per player

### Pickup detection (Stuck)

- [ ] Each tick while Stuck: scans for `PlayerCharacterBody` within `PICKUP_RADIUS_PX` of `stuck_position`
- [ ] Player with `stash < STASH_MAX` and smallest distance wins
- [ ] Exact distance ties broken by lowest `player_slot` (deterministic)
- [ ] On winner determination: emit `projectile_picked_up(projectile_id, player_slot)` exactly once

### Screen-wrap

- [ ] After each tick's position update, position is wrapped via Map's `wrapped_x`/`wrapped_y` when Map's wrap flags are enabled
- [ ] Velocity preserved across wrap (no scale, no reset)
- [ ] Wrap does not interfere with subsequent collision detection

### Validator parity (load-bearing)

- [ ] Build-time validator and runtime use the same integration formula (Formula 2 — Euler)
- [ ] If validator uses closed-form (Formula 4): runtime position at time `t` matches closed-form to within `VALIDATOR_POSITION_EPSILON_PX` (0.5 px)
- [ ] All map shipping requires validator pass (per Map's CI gate)

### Performance

- [ ] Per-Projectile physics step: ≤0.2 ms per tick
- [ ] Up to 12 simultaneous Projectiles (4 players × 3 stash) in flight: total Projectile budget ≤ 2.4 ms/frame
- [ ] No heap allocations per Projectile per tick (reuse Vector2 buffers; signal payloads are primitives + Object refs)

### Cross-system integration

- [ ] Combat correctly polls `Movement.is_iframe_active()` on `projectile_hit_player` (Combat-side test)
- [ ] Combat increments stash on `projectile_picked_up`; player's stash never exceeds `STASH_MAX` (Combat-side test)
- [ ] Combat correctly deflects on `projectile_hit_player` when stash is full + i-frame active (Combat-side test)
- [ ] Map validator pass guarantees all spawn-angle trajectories settle in reachable positions (Map-side test, references Projectile's integration)

### Code hygiene

- [ ] All tuning knobs (Section G) exposed via config Resource
- [ ] No direct `InputEvent` reads in Projectile (input flows through Combat via CouchInput's `throw_pressed`)
- [ ] No hardcoded collision layer indices (use named constants)
- [ ] `projectile_id` is unique per instance (no collisions across rounds)
- [ ] All public queries (`state`, `recoverable`, `position`, `stuck_position`) documented with semantics
- [ ] Signal payloads are typed (`signal projectile_hit_player(projectile_id: int, player_body: PhysicsBody2D)`)
- [ ] Signal emission paths guard against post-`queue_free()` emission via `is_queued_for_deletion()` check (Godot's `queue_free` defers free to end-of-frame; signals emitted in the same frame just before free might still fire without the guard)

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| **Validator parity strategy**: share runtime integration code with build-time validator OR validator uses closed-form (Formula 4) within `VALIDATOR_POSITION_EPSILON_PX` tolerance. Pick one before Map's validator is implemented. | gameplay-programmer + tools-programmer | Before first map ships | TBD — leaning toward shared integration code (safer parity) |
| Pickup distance across screen-wrap currently uses straight-line distance (does NOT respect wrap). Players "just across" the wrap boundary cannot pick up. | game-designer | Post-MVP playtest if confusion observed | Defer to playtest; v1 = straight-line |
| **Combat-side thrower tracking**: Combat must decide whether to track thrower-of-projectile and ignore self-hits. TowerFall handles it implicitly (throw velocity carries arrow away fast). Pure-design choice for Combat GDD. | Combat GDD author | Before Combat GDD approved | Forward contract — Combat owns the decision |
| **Visual FX subscription mechanism**: does Projectile add a `projectile_wall_stuck` signal, or does Visual FX poll state transitions? Same decision applies to pickup-sparkle events. | Visual FX GDD author | Before Visual FX GDD approved | Defer to Visual FX GDD; Projectile adds signals on request |
| **Audio subscription mechanism**: same as Visual FX above. Audio GDD decides whether to subscribe to state transitions or new signals. | Audio GDD author | Before Audio GDD approved | Defer to Audio GDD |
| `design/gdd/game-concept.md` Tuning Knobs row for `shuriken_wall_stick_duration_s` is stale — should reflect "permanent until retrieved" resolution. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: concept doc updated |
| `design/gdd/game-concept.md` Tuning Knobs row for `pickup_radius_px` should change Owner from Combat → Projectile (and note default 12 px). | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: concept doc updated |
| `design/gdd/game-concept.md` Dependencies table Combat row was stale — caught during /design-review. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: Combat row in concept doc Dependencies table updated to include Projectile |
| Precise wall-normal computation for `stuck_position`: current Rule 5 uses `-velocity.normalized()` (simple approximation). Could be more accurate via raycast from prior position to overlap point. | gameplay-programmer | During implementation if visual jank observed | Defer — approximation should be visually acceptable; revisit if needed |
| `SHURIKEN_THROW_VELOCITY` final value is Combat-owned per concept doc — Projectile recommends ~200 px/s starting value based on TowerFall-style arc readability with `SHURIKEN_GRAVITY = 600`. Final pin in Combat GDD. | Combat GDD author | Before Combat GDD approved | Forward recommendation |
| Initial tuning values are placeholders. Real values require MVP playtest iteration per Pillar 5. Highest-impact: `SHURIKEN_GRAVITY_PX_S2`, `SHURIKEN_THROW_VELOCITY` (Combat), `PICKUP_RADIUS_PX`. | game-designer + Projectile implementer | MVP playtest cycles | Defer to playtest |
| Sprite asset (the actual shuriken art): placeholder geometry for MVP; final art per art bible. | art-director | Pre-alpha art pass | Deferred |
