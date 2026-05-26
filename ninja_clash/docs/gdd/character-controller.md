# Character Controller

> **Status**: Approved
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-17
> **Implements Pillar**: Primary — *Game-Feel First*; Secondary — *Restraint over Spectacle*

## Overview

The Character Controller (CC) is the physics primitive layer for player
characters in Four Clans. It owns the body type and collision shape for
each player, applies velocity and gravity per physics tick, resolves
collisions against the Map (solid walls, one-way platforms, screen-wrap
boundaries), and exposes state queries that downstream systems (chiefly
Movement) consume to decide what the character should do next.

CC does not define player verbs — it provides the physics building blocks
Movement composes them from. CC knows "this body is on the ground" and
"this body is touching a wall on the right"; Movement knows "given those
facts, this A-button press is a jump." CC knows "the body's X position
just crossed the right edge"; Movement knows nothing — it just sees the
body continue moving with the same velocity, now on the left side.

CC is player-only. Projectiles have their own simpler physics (no ground
detection, no jump arc — just trajectory + collision against the Map),
defined in the Projectile GDD.

## Player Fantasy

The Character Controller should be **invisible to the player**, felt only as
the absence of friction in every movement decision Movement asks it to
execute. When the ninja jumps, the jump should land at exactly the apex
they aimed for. When the ninja walks off a ledge, gravity should take over
within a single frame — no "hang time" feeling glitchy, no "did I just
hover?" When the ninja runs full-speed into a wall, they should stop dead
at the pixel — no clipping, no sliding, no rubber-banding.

The physics should *never* surprise the player. Every collision should be
the collision the player expected from looking at the geometry. Every
screen-wrap should be the screen-wrap they planned. Every drop-through a
one-way platform should feel like falling, not like glitching.

This is *Game-Feel First* applied at the physics layer: pixel-perfect,
frame-perfect, predictable. The character body is a contract with the
player. Break the contract and the entire game's promise breaks with it.

## Detailed Design

### Core Rules

1. CC is implemented as a `CharacterBody2D` subclass (`PlayerCharacterBody`).
2. One instance per active player slot; instantiated by Round Flow at round start, freed at round end (or on death).
3. **Hitbox**: 10 wide × 16 tall pixels, centered horizontally on the body origin.
4. **Position**: stored as `Vector2` (float); render position snapped to integer pixel via `Sprite2D.position = position.round()`.
5. **Physics tick**: 60 Hz (`_physics_process` at Godot default).
6. **Velocity model**:
   - **Horizontal**: Movement sets a target velocity via `set_horizontal_intent(v: float)`. CC interpolates current velocity toward target at `HORIZONTAL_ACCEL_PX_S2` per second (very fast — effectively snappy with a 2-3 frame ramp).
   - **Vertical**: pure physics — gravity applied each tick; Movement can apply impulses via `apply_jump_impulse(strength)` or `set_vertical_velocity(v)`.
7. **Gravity**:
   - Constant base gravity `GRAVITY_PX_S2` applied every tick.
   - **Jump-cut**: when Movement calls `cancel_jump()` (A button released while moving upward), CC clamps `vertical_velocity = max(vertical_velocity, -JUMP_CUT_VELOCITY_PX_S)` — cuts the upward velocity short. (Godot Y-down convention: negative = up.)
8. **Collision layers** (Godot 32-bit system):

   | Layer | Name | Used by |
   |---|---|---|
   | 1 | Player | Player CC bodies |
   | 2 | Wall | Map solid tiles |
   | 3 | OneWay | Map one-way / drop-through tiles |
   | 4 | Projectile | Shuriken bodies |
   | 5 | Pickup | Reserved (v1.x) |

   **Player mask**: collides with Wall + OneWay + Projectile (NOT with other Players — TowerFall parity, see Edge Cases for rationale).

9. **State queries** (exposed for Movement to consume):
   - `is_on_floor() -> bool`
   - `is_on_wall() -> bool`
   - `wall_normal() -> Vector2` (which side touched: (-1, 0) = left wall, (+1, 0) = right wall)
   - `is_on_ceiling() -> bool`
   - `velocity -> Vector2` (current physics velocity)
   - `is_stationary() -> bool` (helper: `is_on_floor() and abs(velocity.x) < STATIONARY_THRESHOLD`)

10. **Movement commands** (called by Movement):
    - `set_horizontal_intent(v: float)` — target horizontal velocity
    - `apply_jump_impulse(strength: float)` — sets vertical velocity to `-strength` (upward)
    - `cancel_jump()` — applies jump-cut clamp
    - `apply_dodge_impulse(direction: Vector2, strength: float)` — sets velocity for a dodge dash
    - `set_vertical_velocity(v: float)` — sets vertical velocity directly (used by Movement for wall-slide cap per Rule 6) *(consistency fix added 2026-05-17 during Movement GDD design — method was already documented in Rule 6 but missing from this list)*
    - `drop_through_request()` — temporarily disables OneWay collision for 1 physics tick

11. **Screen-wrap**:
    - After `move_and_slide()`, CC checks if position is outside `[0, playfield_width)` on X (and Y if vertical wrap enabled).
    - If outside, position is wrapped via Map's `wrapped_x` / `wrapped_y` formula; velocity preserved.
    - No event emitted — wrap is silent.

12. **One-way platform handling**: Godot's native one-way collision (`CollisionShape2D.one_way_collision = true` on Map's one-way tiles). Drop-through is implemented via `drop_through_request()` which excludes the OneWay layer from `platform_floor_layers` for 1 physics tick. **CC itself re-enables OneWay collision at the end of that tick — the call is self-resetting**; callers do not need to invoke a corresponding "restore" method.

13. **No body-body collision between players**: enforced via collision mask (Player layer doesn't include itself). Players visually overlap when in the same position; no physical interaction.

14. **Slot identity**: each `PlayerCharacterBody` instance exposes a `slot: int` field (1-4) set at instantiation by Round Flow. Immutable for the lifetime of the instance. Read by Combat to identify which player is involved in a collision (e.g., `player_body.slot`). *(added 2026-05-17 during Combat GDD design — Combat needs to identify slot from the collision body)*

### States and Transitions

CC tracks minimal state. Movement owns verb-level state machines
(idle/walk/jump/dodge/etc.); CC just exposes physics queries.

| Internal flag | When set | When cleared | Used for |
|---|---|---|---|
| `drop_through_active` | `drop_through_request()` called | After 1 physics tick | Temporarily ignore OneWay collision |
| `recently_wrapped` | After position wrap | After 1 physics tick | Diagnostic only (not exposed externally) |

CC has no observable state machine of its own.

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **Map** | CC reads collision data via Godot's physics layers (Walls on layer 2, OneWay on layer 3); queries `MapResource.playfield_width` and `horizontal_wrap` flags for screen-wrap | Map → CC |
| **Movement** | Calls `set_horizontal_intent`, `apply_jump_impulse`, `cancel_jump`, `apply_dodge_impulse`, `drop_through_request`; reads state queries (`is_on_floor`, `is_on_wall`, `velocity`) | Movement ↔ CC |
| **Clan Cosmetics** | Reads CC's `position` + facing direction to render costume + emblem; subscribes to CC for hit reactions | CC → Clan Cosmetics |
| **Combat** | Reads CC's `slot` field (Rule 14) to identify which player was hit on `projectile_hit_player` signal. Reads CC's `position` for throw spawn computation. Combat does NOT call any kill method on CC — kill flows through `Movement.set_dead()` instead; CC is freed by Round Flow shortly after death. *(updated 2026-05-17 during Combat GDD design — original row said "Combat calls a kill method on CC" which was stale)* | CC ↔ Combat |
| **Visual FX** | Reads CC's velocity + `is_on_floor` for animation state inputs (walk vs idle vs falling) | CC → Visual FX |
| **Round Flow** | Instantiates CC at round start (one per slot, at the assigned spawn point); frees CC at round end or on death | Round Flow → CC |

## Formulas

### Gravity application

Each physics tick:

```
vertical_velocity += GRAVITY_PX_S2 * delta
vertical_velocity  = min(vertical_velocity, TERMINAL_VELOCITY_PX_S)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `delta` | float | ~0.0167 (1/60) | Godot `_physics_process` | Tick duration |
| `GRAVITY_PX_S2` | float | 800 – 1600 | tuning knob | Gravity (default 1200 px/s²) |
| `TERMINAL_VELOCITY_PX_S` | float | 400 – 800 | tuning knob | Cap on downward velocity (default 600 px/s) |
| `vertical_velocity` | float | (-∞, +`TERMINAL_VELOCITY`) | CC internal | Positive = down (Godot Y-down convention) |

### Horizontal velocity interpolation (snappy with brief ramp)

```
target = horizontal_intent                                  # set by Movement
diff   = target - current_horizontal_velocity
step   = sign(diff) * min(abs(diff), HORIZONTAL_ACCEL_PX_S2 * delta)
current_horizontal_velocity += step
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `target` | float | -`MAX_HSPEED` to +`MAX_HSPEED` | Movement | Target horizontal velocity (px/s) |
| `HORIZONTAL_ACCEL_PX_S2` | float | 1000 – 5000 | tuning knob | Convergence rate (default 3000 → ~2-3 frame ramp to max speed) |
| `MAX_HSPEED` | float | 80 – 200 | tuning knob | Cap on horizontal velocity (default 120 px/s) |

### Jump-cut

Called by Movement when A is released during upward motion:

```
if vertical_velocity < -JUMP_CUT_VELOCITY_PX_S:
    vertical_velocity = -JUMP_CUT_VELOCITY_PX_S
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `JUMP_CUT_VELOCITY_PX_S` | float | 100 – 400 | tuning knob | Cap on upward velocity post-cut (default 200 px/s) |

Held jump → full impulse, full apex. Released early → clamped to lower upward
velocity, shorter arc. Standard TowerFall / Mario jump-cut.

### Screen-wrap (delegates to Map)

After `move_and_slide()` each tick:

```
if horizontal_wrap_enabled:
    position.x = wrapped_x(position.x, playfield_width)
if vertical_wrap_enabled:
    position.y = wrapped_y(position.y, playfield_height)
```

Uses Map's `wrapped_x` / `wrapped_y` formulas — no new math here.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Player spawns inside a wall (level designer error) | Map's build-time validator catches this. At runtime, CC trusts spawn validity; if violated, Godot's `move_and_slide` pushes the body out on next tick | Validator owns the prevention |
| Two players spawn at the same position | Allowed. They visually overlap; no body collision between players | Per Core Rule 13 (TowerFall parity) |
| Velocity > playfield width per frame (extremely fast) | Wrap formula uses modulo — works at any speed. Position is correct post-wrap regardless of how many widths crossed | Math is robust |
| Player on a one-way platform requests `drop_through_request`, but a solid tile is below | They fall through the one-way, then land on the solid on the next tick | Sequential physics; correct natural behavior |
| `apply_jump_impulse` called while already airborne | CC applies the impulse unconditionally (no `is_on_floor` check in CC). | CC is dumb, Movement is smart. Movement is responsible for gating "can I jump?" — this enables Movement to implement double-jump cleanly by calling impulse twice |
| `cancel_jump` called while falling (vertical velocity ≥ 0) | No effect (clamp condition not met) | Per the formula, only upward velocity gets clamped |
| `set_horizontal_intent` called with NaN or infinity | CC defensively clamps to `[-MAX_HSPEED, +MAX_HSPEED]` before applying | Cheap defensive guard |
| Player position somehow exceeds 2× playfield_width before wrap (e.g., teleport bug) | Wrap formula's modulo handles arbitrary out-of-bounds. Position is correct after wrap | Math is robust |
| Physics tick takes >16.6 ms (frame hitch) | Godot accumulates `delta`; physics runs multiple ticks per frame to catch up. Determinism preserved | Standard Godot behavior |
| Multiple players occupy exactly the same pixel | Allowed. No collision. Visually overlapping is acceptable in 4-player chaos | Per Core Rule 13 |
| Player drops through a one-way and immediately wall-touches mid-fall | `drop_through_active` only suppresses OneWay collision; Wall collision still resolves normally | Layered correctly via collision masks |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| **Map** | CC depends on Map | Reads collision data via Godot physics layers (Walls layer 2, OneWay layer 3); queries `MapResource.playfield_width` + `horizontal_wrap` flags |
| **Movement** | Movement depends on CC | Calls movement commands (`set_horizontal_intent`, `apply_jump_impulse`, `cancel_jump`, `apply_dodge_impulse`, `drop_through_request`); reads state queries (`is_on_floor`, `is_on_wall`, `wall_normal`, `velocity`) |
| **Clan Cosmetics** | Clan Cosmetics depends on CC | Reads `position` + facing direction to render costume + emblem; subscribes for hit reactions |
| **Combat** | Combat depends on CC | Receives collision signal when Projectile body hits Player body; calls kill method on CC; reads CC `position` for hit-stop trigger |
| **Round Flow** | Round Flow depends on CC | Instantiates `PlayerCharacterBody` instances at round start at assigned spawn points; frees them at round end or on death |
| **Visual FX** | Visual FX depends on CC | Reads `velocity` + `is_on_floor` + `is_on_wall` as inputs to the animation state machine (walk/idle/falling/sliding) |

**External dependencies:**
- Godot 4.6 `CharacterBody2D` (built-in platformer body)
- Godot 4.6 `move_and_slide()` (collision resolution)
- Godot 4.6 `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()`, `get_wall_normal()` (state queries)
- Godot 4.6 `CollisionShape2D.one_way_collision` (one-way platform support)
- Godot 4.6 32-bit collision layer/mask system

**Bidirectional consistency** (resolved 2026-05-17):

- `design/gdd/systems-index.md` updated: Combat, Round Flow, and Visual FX rows + Dependency Map Feature/Presentation entries now include Character Controller.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `GRAVITY_PX_S2` | 1200 px/s² | 800 – 1600 | Heavier feel; faster falls; shorter jump airtime | Lighter feel; longer hang time; more dodge time in air |
| `TERMINAL_VELOCITY_PX_S` | 600 px/s | 400 – 800 | Faster maximum falls; harder to catch falling players | Slower falls; falling players easier to track |
| `MAX_HSPEED` | 120 px/s | 80 – 200 | Faster traversal; smaller-feeling maps | Slower; more time to react to threats |
| `HORIZONTAL_ACCEL_PX_S2` | 3000 px/s² | 1000 – 5000 | Snappier turns and starts (closer to instant) | Smoother feel with more momentum (Mario-like) |
| `JUMP_CUT_VELOCITY_PX_S` | 200 px/s | 100 – 400 | Less aggressive jump-cut (released jumps still go fairly high) | More aggressive cut (short jumps are very short) |
| `STATIONARY_THRESHOLD` | 5 px/s | 1 – 20 | More forgiving "stationary" detection (dodge triggers more often) | Stricter "stationary" (must be near-zero velocity for A-as-dodge) |
| Hitbox width | 10 px | 8 – 14 | Larger target = easier to hit | Smaller target = harder to hit, more dodge room |
| Hitbox height | 16 px | 12 – 20 | Taller target = easier hit from above | Shorter = harder hit but feels weirdly small visually |

**Interactions to watch:**

- `GRAVITY` × `JUMP_CUT_VELOCITY`: jump-cut effectiveness depends on gravity. Raising both keeps the cut window similar.
- `MAX_HSPEED` × `HORIZONTAL_ACCEL`: with high accel, the speed feels effectively instant. With low accel, max speed matters less.
- `STATIONARY_THRESHOLD` × `MAX_HSPEED`: threshold should be very small relative to `MAX_HSPEED` (always <10%).

**Not knobs**: physics tick rate (60 Hz fixed), collision layer indices (architectural).

## Acceptance Criteria

### Functional

- [ ] CC instantiates at given spawn position; position is correct on first physics tick
- [ ] Gravity applies each tick; vertical velocity increases by `GRAVITY_PX_S2 × delta`
- [ ] Terminal velocity caps falling speed at `TERMINAL_VELOCITY_PX_S`
- [ ] `set_horizontal_intent(target)` causes horizontal velocity to converge toward `target` at `HORIZONTAL_ACCEL_PX_S2` per second
- [ ] `apply_jump_impulse(strength)` sets vertical velocity to `-strength` immediately (same tick)
- [ ] `cancel_jump` clamps vertical velocity to `-JUMP_CUT_VELOCITY_PX_S` only when already upward; no-op if falling
- [ ] `apply_dodge_impulse(direction, strength)` sets velocity to `direction.normalized() * strength`
- [ ] `drop_through_request` lets CC fall through one-way platforms for 1 physics tick, then re-enables OneWay collision

### State queries

- [ ] `is_on_floor()` returns `true` when standing on solid; `false` in air
- [ ] `is_on_wall()` returns `true` when body is touching a wall on left or right
- [ ] `wall_normal()` returns `(-1, 0)` for left wall, `(+1, 0)` for right wall
- [ ] `is_on_ceiling()` returns `true` when hitting ceiling during upward motion
- [ ] `is_stationary()` returns `true` when `is_on_floor() and abs(velocity.x) < STATIONARY_THRESHOLD`

### Collision

- [ ] Player body collides with Walls (layer 2) from all sides
- [ ] Player body collides with OneWay (layer 3) only from above (cannot pass up through, can drop down through with `drop_through_request`)
- [ ] Player body does NOT collide with other Players (layer 1 not in mask)
- [ ] Player body collides with Projectiles (layer 4) → triggers Combat's hit signal

### Screen-wrap

- [ ] Position exiting left edge wraps to right with same Y + velocity preserved
- [ ] Position exiting right edge wraps to left with same Y + velocity preserved
- [ ] Vertical wrap works analogously when `vertical_wrap = true`
- [ ] Wrap does not break collision detection (post-wrap collision is correctly resolved)

### Performance

- [ ] Single CC physics step completes within ≤0.3 ms per CC per tick
- [ ] 4 CCs simultaneously: total CC physics budget ≤1.2 ms per frame
- [ ] Memory footprint per CC instance < 5 KB

### Rendering

- [ ] Visual sprite renders at `position.round()` (integer pixel); sub-pixel float position is preserved internally for accumulation across ticks

### Code hygiene

- [ ] No magic numbers for collision layer indices (use named constants)
- [ ] All tuning knobs (Section G) exposed in a config Resource, not hardcoded
- [ ] No direct `InputEvent` reads in CC (input is consumed by CouchInput → Movement → CC)
- [ ] All public methods documented with their expected inputs and side effects

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Coyote time (jump grace period after walking off a ledge): does CC support a "you can still jump for N frames after `is_on_floor` becomes false"? Standard platformer comfort. | Movement GDD author | Before Movement GDD approved | TBD — likely yes (3–5 frames) |
| Jump buffer (jump press accepted slightly before landing): N-frame window where a press just-before-landing triggers a jump on landing. Another standard comfort. | Movement GDD author | Before Movement GDD approved | TBD |
| Wall-jump trigger: does CC need a dedicated `apply_wall_jump_impulse` or does Movement call `apply_jump_impulse` with a horizontal kick after detecting `is_on_wall`? | Movement GDD author | Before Movement GDD approved | Likely Movement-side (no special CC method) |
| Hit-reaction on kill: when a Projectile collides with a player CC, does CC freeze velocity? Continue normally until Movement reacts? Vanish? | Combat + Movement GDD authors | Before Combat GDD approved | Likely Combat triggers a kill state in Movement; CC is freed by Round Flow shortly after |
| Pixel-snap flicker on very slow movement: integer-pixel snap could cause visual jitter when velocity is between -0.5 and +0.5 px/frame. Hysteresis? Sub-pixel sprite offset? | Visual FX GDD author + technical-artist | Before Visual FX GDD approved | Defer to Visual FX layer (sprite-render concern, not physics) |
| Initial tuning values are placeholder. Real values require playtest iteration (Movement is the primary tuning driver per concept Pillar 5). | game-designer + Movement GDD author | During MVP prototype playtest | Defer to playtest |
| `apply_dodge_impulse` direction default: if Movement passes `Vector2.ZERO`, should dodge be vertical-only? facing-direction? prevented? | Movement GDD author | Before Movement GDD approved | Movement-side decision; CC just applies whatever vector it gets |
