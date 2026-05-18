# Combat

> **Status**: In Design
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-17
> **Implements Pillar**: Primary — *Every Shuriken Matters*; Secondary — *Fairness Is Sacred*, *Game-Feel First*

## Overview

The Combat system is where Four Clans becomes a game. It owns the rules
that turn Projectile's physics into a kill economy: each player's stash
of shurikens, the throw input that converts a stash slot into a flying
projectile, the catch logic that lets a perfect dodge become a refill,
the deflection that protects a full-stash player, and the kill
resolution that ends a round. Combat sits in the Feature layer and
depends on every MVP system below it — it is the system that ties
Movement, Projectile, Map, CouchInput, and CC into actual gameplay.

Combat does not own physics (Projectile does), input routing (CouchInput
does), or player verbs (Movement does). It owns the *gameplay* — the
rules that say "this shuriken belongs to player 2, has been thrown,
will kill on contact unless caught, and contributes to round-end when
it does." Every kill in Four Clans flows through Combat. Every stash
counter, every throw, every catch, every deflection, every elimination
is a Combat decision. Round Flow doesn't know about projectiles — it
only knows that Combat told it player 3 just eliminated player 1.

## Player Fantasy

Combat is where every other system pays off. Movement gave you the
verbs; Projectile gave you the physics; Map gave you the geometry.
Combat is where it all becomes a kill — or a near-miss, or a clean
catch, or the moment you realize you're out of shurikens with a hostile
ninja closing on you.

The one-hit kill is the game's signature moment. Per the concept doc,
"a single shuriken hit to any body part kills instantly." There is no
HP bar, no regen, no second chances. When a shuriken connects, the
round shifts immediately and irrevocably. The kill should feel clean,
not punishing — the player who got hit had a fair read; the player who
landed it earned it. *Fairness Is Sacred* is the contract: every
player has the same shurikens, the same dodge, the same reach. The
kill is attribution, not luck.

The stash is the second emotional anchor. Per *Every Shuriken Matters*,
"scarcity drives choice; retrieval rewards positioning." Each shuriken
in your stash is a question you haven't answered yet. Each shuriken
in the air is a question you've answered and now have to live with.
The catch — plucking an incoming shuriken from the air with a
perfectly timed dodge — is the apex of this economy: a single moment
that can refill your stash, deny the thrower's commitment, and pivot
the exchange. TowerFall lives or dies on the catch; so does Four
Clans. *Game-Feel First* at the meta layer means every Combat moment
is exact — the kill is instant, the catch is satisfying, the
elimination is final. The player who died knows why; the player who
killed knows they did it.

## Detailed Design

### Core Rules

1. Combat is a Godot autoload singleton (`Combat`). One instance per game session.

2. Combat tracks per-player stash in `stash_by_slot: dict[int, int]` (slot 1-4 → current count 0-3).

3. Combat tracks per-projectile ownership in `thrower_by_projectile: dict[int, OwnerRecord]` where `OwnerRecord = (thrower_slot: int, throw_time: float)`. Used for self-hit immunity and HUD ownership display.

4. Combat assigns monotonically-increasing `projectile_id` per throw. Persists for the round; resets each round.

5. **Throw** (on `throw_pressed(slot)` from CouchInput):
   1. **Gate**: if `stash_by_slot[slot] == 0` OR player's Movement `is_dead`: ignore. **No throw cooldown beyond stash gate** — rapid-fire is allowed; the player who burst-throws empties their stash naturally.
   2. Compute direction: `direction = compute_throw_direction(stick, facing)` (Projectile Formula 1). Reads stick from CouchInput's last `move_input(slot)`, facing from Movement.
   3. Compute spawn: `spawn_pos = player_position + direction * THROW_SPAWN_OFFSET_PX`.
   4. Generate `projectile_id` (next monotonic).
   5. Instantiate: `Projectile.new(spawn_pos, direction, SHURIKEN_THROW_VELOCITY, projectile_id)`. Add to scene tree. *(constructor signature aligned 2026-05-17 with Projectile Rule 3 — 4 args: position, direction, throw_velocity, projectile_id)*
   6. Connect `projectile_hit_player` and `projectile_picked_up` signals.
   7. Record ownership: `thrower_by_projectile[projectile_id] = (slot, current_time)`.
   8. Decrement: `stash_by_slot[slot] -= 1`.
   9. Emit `stash_changed(slot, new_count, -1)`.

6. **Player collision handler** (`projectile_hit_player(projectile_id, player_body)`):
   1. Look up `victim_slot = player_body.slot`.
   2. **Self-hit immunity**: if `victim_slot == thrower_by_projectile[projectile_id].thrower_slot` AND `(current_time - throw_time) < SELF_HIT_IMMUNITY_S`: ignore signal.
   3. Look up `is_iframe = player_body.get_node("PlayerMovement").is_iframe_active()`.
   4. **Branch**:
      - `is_iframe == false` → **kill** (Rule 7).
      - `is_iframe == true` AND `stash[victim_slot] < STASH_MAX` → **catch** (Rule 8).
      - `is_iframe == true` AND `stash[victim_slot] == STASH_MAX` → **deflect** (Rule 9).

7. **Kill**:
   1. **Already-dead guard**: if `victim_movement.is_dead()` already true: skip emit + free (kill is a no-op for already-dead victim). Prevents duplicate `player_eliminated` events when multiple shurikens hit the same victim same tick. *(added 2026-05-17 during Combat GDD design review)*
   2. Call `victim_movement.set_dead()` (transitions Movement to Dead state per Movement Rule 13). Idempotent.
   3. Look up `killer_slot = thrower_by_projectile[projectile_id].thrower_slot` (or `victim_slot` if post-immunity self-hit).
   4. Emit `player_eliminated(victim_slot, killer_slot, projectile_id)` — Round Flow + HUD consume.
   5. Free the Projectile instance (`queue_free()`).
   6. Remove from `thrower_by_projectile`.

8. **Catch** (i-frame + stash has room):
   1. `stash_by_slot[victim_slot] += 1`.
   2. Emit `stash_changed(victim_slot, new_count, +1)`.
   3. Free Projectile.
   4. Remove from `thrower_by_projectile`.

9. **Deflect** (i-frame + stash full — Movement Edge Case row 8 contract):
   1. Read Projectile's current `velocity`.
   2. Set Projectile's velocity to `-velocity` (mirror, full magnitude).
   3. **Do NOT** transfer ownership — `thrower_by_projectile` entry stays. **Karma deflection**: original thrower's shuriken returns at them.
   4. **Do NOT** free the Projectile. It re-enters Flying with new velocity.
   5. Self-hit immunity typically already expired (deflection happens after some flight time), so the returning shuriken can legally kill the original thrower.

10. **Pickup handler** (`projectile_picked_up(projectile_id, picker_slot)`):
    1. If `stash_by_slot[picker_slot] < STASH_MAX`: increment stash; emit `stash_changed(picker_slot, new_count, +1)`. (Defensive: Projectile already filtered, but Combat double-checks.)
    2. Free Projectile.
    3. Remove from `thrower_by_projectile`.

11. **Round-start init** (on Round Flow's round-start signal):
    1. For each active slot (per `MatchContext` from GSM): `stash_by_slot[slot] = STASH_MAX`.
    2. Emit `stash_changed(slot, STASH_MAX, +STASH_MAX)` for each slot.
    3. Reset `next_projectile_id = 1`.
    4. Clear `thrower_by_projectile`.

12. **Round-end cleanup** (on Round Flow's round-end signal):
    1. Iterate all live Projectile instances in scene; `queue_free()` each.
    2. Clear `thrower_by_projectile`.
    3. Stash is NOT cleared at round-end — reset happens on next round-start (Rule 11). Allows HUD to display final stash during MatchEnd.

13. **Public API for HUD**:
    - `get_stash(slot: int) -> int` — query
    - `get_thrower(projectile_id: int) -> int` — query for kill-feed display
    - Signals: `stash_changed(slot, new_count, delta)`, `player_eliminated(victim_slot, killer_slot, projectile_id)`

14. **Identical across clans**: Combat applies the same stash size, throw mechanics, kill rules, deflection physics to every player slot. Per Pillar 2 (Fairness Is Sacred).

### States and Transitions

Combat carries no canonical state machine. It is a dispatch + dict layer
responding to signals from CouchInput (`throw_pressed`), Projectile (collision +
pickup), and Round Flow (round-start, round-end). Its observable "state" is
the per-slot stash counts and per-projectile ownership records.

**Internal fields:**

| Field | Type | Lifecycle | Used for |
|---|---|---|---|
| `stash_by_slot` | `dict[int, int]` (1..4 → 0..3) | Initialized on round-start (Rule 11); mutated on throw / catch / pickup; retained across round-end | Throw gate (Rule 5.1); catch/deflect branch (Rule 6.4); HUD display |
| `thrower_by_projectile` | `dict[int, OwnerRecord]` | Added on throw (Rule 5.7); removed on kill/catch/pickup; cleared on round-end | Self-hit immunity (Rule 6.2); killer attribution (Rule 7.2); HUD kill-feed (Rule 13) |
| `next_projectile_id` | int | Reset to 1 on round-start; incremented on each throw | Projectile constructor parameter; unique key for `thrower_by_projectile` |

**No `state` enum**. Combat's "phase" is implied by which Round Flow signals have fired most recently (round-start enables throws; round-end disables them via cleanup).

**Per-player alive/dead tracking**: Combat does **NOT** track per-slot alive/dead state. That's Round Flow's responsibility. When Combat needs to know if a player is alive (e.g., to gate throws per Rule 5.1), it polls `Movement.is_dead` on that player's Movement instance. **This avoids duplicating state across systems** — single source of truth.

**Public queries:**
- `get_stash(slot: int) -> int`
- `get_thrower(projectile_id: int) -> int` (returns 0 if not found; defensive)

**Signals emitted:**
- `stash_changed(slot: int, new_count: int, delta: int)` — on any stash mutation
- `player_eliminated(victim_slot: int, killer_slot: int, projectile_id: int)` — on kill

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **CouchInput** | Combat subscribes to `throw_pressed(slot)` (per CouchInput Core Rule 7). Reads `move_input(slot)` continuous query for throw direction stick value. | CouchInput → Combat |
| **Projectile** | Combat instantiates Projectile (`Projectile.new(spawn_pos, direction, projectile_id)`); connects `projectile_hit_player` and `projectile_picked_up` signals; reads/writes Projectile `velocity` for deflection (Rule 9); frees Projectile on kill/catch/pickup/round-end. | Combat ↔ Projectile |
| **Movement** | Combat polls `Movement.is_iframe_active()` on `projectile_hit_player` for catch/kill branch (Rule 6). Reads `Movement.is_dead` for throw gate (Rule 5.1) and `Movement.facing` for throw direction. Calls `Movement.set_dead()` to transition Movement to Dead state on kill (Rule 7.1). | Combat ↔ Movement |
| **Character Controller** | Combat reads `player_position` (from CC's inherited Node2D `position`) for throw spawn computation. Does **NOT** call CC's command API directly — all movement-related calls go through Movement. | CC → Combat |
| **Map** (indirect, via CC) | Combat reads no Map data directly. Map's screen-wrap and collision layers affect Combat indirectly through Projectile and CC. | indirect |
| **Round Flow** | Round Flow signals `round_started(MatchContext, round_index)` and `round_ended(winner_slot, round_index)` — Combat consumes per Rules 11, 12 (Combat ignores `round_index`/`winner_slot` payload — included in signatures for HUD consumption). Round Flow consumes `player_eliminated(victim_slot, killer_slot, projectile_id)` to update alive-player tracking and detect round-end (when only 1 alive remains). *(Updated 2026-05-18 during Round Flow GDD design — signal arity aligned + Round Flow no longer undesigned.)* | Round Flow ↔ Combat |
| **HUD** (forward contract — undesigned) | HUD subscribes to `stash_changed` for reactive per-player stash display and `player_eliminated` for kill feed. HUD calls `get_stash(slot)` for initial display and `get_thrower(projectile_id)` for kill-feed killer attribution. | Combat → HUD |
| **Game State Manager** (indirect, via Round Flow) | Combat is active only when GSM is in `InMatch`. Combat does not directly subscribe to GSM — it relies on Round Flow's round-start signal to gate activity. | indirect |

**Cross-system updates required** (caught during this section draft):
1. `design/gdd/character-controller.md` Interactions table row for Combat says "Combat calls a kill method on CC" — this is stale. The kill flow is now `Combat → Movement.set_dead()`; CC is freed later by Round Flow. **Recommend updating CC GDD's Combat row.**
2. `design/gdd/movement.md` Public Queries section lists only `is_dodging()`, `is_iframe_active()`, `is_dead()`, `facing` — does NOT list `set_dead()` as a public method, but Combat Rule 7.1 calls it. **Recommend adding `set_dead()` to Movement's public API documentation.**

Both updates will be applied in the post-design step.

## Formulas

Combat's math is dispatch + simple vector ops. 4 formulas total. All
defaults are starting offers for prototype iteration per Pillar 5.

### Formula 1: Throw direction (delegates to Projectile)

Combat reuses Projectile Formula 1 — same algorithm as Movement's dodge
direction (Movement Formula 2). Documented here as a reference for the
throw path:

```
function compute_throw_direction(stick: Vector2, facing: int) -> Vector2:
    if stick.length() >= STICK_AIM_THRESHOLD:
        return stick.normalized()
    else:
        return Vector2(facing, 0)
```

No new math; just a delegation. `STICK_AIM_THRESHOLD` is owned by
Projectile (default 0.25).

| Variable | Source | Description |
|---|---|---|
| `stick` | CouchInput's last `move_input(slot).vector` for the thrower's slot | Player movement stick at moment of throw |
| `facing` | Movement's `facing` field for the thrower's slot | Last non-zero horizontal direction |

Examples: see Projectile Formula 1 / Movement Formula 2.

### Formula 2: Throw spawn position

```
spawn_pos = player_position + direction * THROW_SPAWN_OFFSET_PX
```

| Variable | Type | Source | Description |
|---|---|---|---|
| `player_position` | Vector2 | CC's `position` for the thrower's slot | Player CC's current center position (Godot Y-down) |
| `direction` | Vector2 (unit) | Formula 1 | Throw direction |
| `THROW_SPAWN_OFFSET_PX` | float | tuning knob | Default **4 px**. Distance from player center to shuriken spawn point |

**Examples**:
- Player at `(200, 100)`, direction `(1, 0)` → spawn at `(204, 100)`.
- Player at `(200, 100)`, direction `(0.707, -0.707)` → spawn at `(202.83, 97.17)`.

### Formula 3: Self-hit immunity check

```
is_self_hit_blocked(projectile_id, victim_slot, t_now) :=
    thrower_by_projectile[projectile_id].thrower_slot == victim_slot
    AND (t_now - thrower_by_projectile[projectile_id].throw_time) < SELF_HIT_IMMUNITY_S
```

| Variable | Type | Source | Description |
|---|---|---|---|
| `projectile_id` | int | signal payload | Identifies the projectile |
| `victim_slot` | int | `player_body.slot` from signal | Player who got hit |
| `t_now` | float (s) | engine wall-clock | Current time |
| `throw_time` | float (s) | `thrower_by_projectile[projectile_id]` | Time the projectile was thrown |
| `SELF_HIT_IMMUNITY_S` | float (s) | tuning knob | Default **0.083 s** (~5 frames @ 60 Hz) |

**Examples**:
- Player 1 threw projectile 7 at `t = 10.000 s`. At `t = 10.040 s`, projectile overlaps player 1 (spawn-overlap from offset miss): **blocked** (40 ms < 83 ms).
- At `t = 10.500 s`, the (now deflected) projectile overlaps player 1: **NOT blocked** (500 ms > 83 ms) → kill. Karma deflection succeeds.

### Formula 4: Deflection velocity

```
deflected_velocity = -projectile.velocity
```

| Variable | Type | Source | Description |
|---|---|---|---|
| `projectile.velocity` | Vector2 | Projectile internal field | Incoming velocity at moment of catch |
| `deflected_velocity` | Vector2 | computed | New velocity assigned back to projectile |

**Example**: Incoming velocity `(150, -80)` (rightward-up) → deflected `(-150, 80)` (leftward-down). Same magnitude (170.3 px/s), exactly opposite direction. Projectile re-enters Flying with this velocity; gravity continues to act normally from there.

**No magnitude scaling, no angular noise** — strict mirror, full speed, per Round 3 decision. Deterministic per Pillar 2 (Fairness Is Sacred).

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Throw with empty stash | Rule 5.1 gates — signal ignored. No mutation. | Per stash invariant; no negative-stash possible |
| Throw while `Movement.is_dead` | Rule 5.1 gates — signal ignored. | Dead players can't throw; per Movement Rule 13 (Dead state suppresses all input) |
| Double-kill on same tick (two players killed by different projectiles same frame) | Combat processes each `projectile_hit_player` signal independently. Both kills resolved; both `player_eliminated` events emit. Round Flow sees 2 events, recomputes alive count → may trigger round-end if only 1 alive after both. | Per Godot signal processing semantics; deterministic per signal-emission order |
| **Stuck projectile + player walks over it** (cross-system issue) | Projectile should emit ONLY `projectile_picked_up`, NOT `projectile_hit_player`. **Projectile GDD currently has a gap**: Rule 7 emits `projectile_hit_player` on any Player overlap, including in Stuck state. **Fix**: Projectile Rule 7 must be gated by `state == Flying`. Recommend updating Projectile GDD. | Stuck = recoverable, not lethal. Without the fix, walking over a stuck shuriken would fire both signals (hit + pickup) and Combat would kill instead of pickup |
| Throw + round-end cleanup on same tick | Either order works. If round-end first: throw signal handler may see `next_projectile_id` reset (defensive); resulting projectile is freed by next tick's iteration. If throw first: projectile instantiated, immediately freed by cleanup. Acceptable. | No frame-perfect race condition that breaks the round |
| Stash overflow attempt (catch when stash == STASH_MAX) | Cannot occur via normal flow — Rule 6.4 routes catch (stash < MAX) vs deflect (stash == MAX) branches. Defensive guard in Rule 10.1 also clamps. | Stash invariant: `0 ≤ stash ≤ STASH_MAX` always |
| Stash underflow attempt (throw when stash == 0) | Cannot occur — Rule 5.1 gates. Defensive guard. | Same invariant |
| Deflection ping-pong (full-stash players bounce shuriken back and forth) | Each deflection preserves the original `thrower_by_projectile` record (Rule 9.3). Karma stays with whoever first threw. If both keep deflecting, the shuriken oscillates until one player drops i-frames or stash falls below MAX. Eventually someone kills (post-immunity) or it lands on a wall (Stuck). | Deterministic per ownership rule; no infinite loop because i-frames are short |
| Self-kill via deflection (post-immunity self-hit) | Per Rule 9.5: immunity typically expires before the deflected shuriken returns. If original thrower is NOT in i-frame + stash full at return: original thrower dies. `player_eliminated(thrower, thrower, projectile_id)` — self-attribution. | Reinforces "don't waste throws"; consistent with karma model |
| Player elimination triggers round-end while shurikens still in flight | Round Flow's round-end signal → Combat Rule 12 frees all in-flight projectiles. Late-arriving `projectile_hit_player` signals (if Godot has any queued) are dropped because the Projectile is queued for deletion. | Order doesn't matter; Godot's deletion is end-of-tick safe |
| 2-player match vs 4-player match | No special logic. `stash_by_slot` dict has 2 or 4 entries; throw / catch / kill / pickup branches are slot-agnostic. | Dict-based design scales 1–4 |
| Player walks into stuck shuriken with full stash | Per Projectile Rule 9: pickup is gated by `stash < STASH_MAX`. Player is NOT an eligible candidate. Stuck shuriken stays in place. | Stash cap respected; player must use one before retrieving more |
| Multiple shurikens hit same victim same tick (rapid-fire burst at close range) | First hit: kill path executes per Rule 7. Subsequent hits same tick: Rule 7.1 already-dead guard skips emit + free; no duplicate `player_eliminated` event. The Projectile from the second+ hit may stay live (Combat freed only the first one); next tick's overlap check would re-fire, hitting the same dead player → guard skips again. Projectile is freed via round-end cleanup (Rule 12) or via Combat's free in step 7.5 of the first hit's processing. **Implementation note**: in practice all second+ hits should also free their Projectile (extend Rule 7.1 guard to free + skip remove, not just skip emit). | Duplicate kills shouldn't fire; alive count must stay deterministic |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| **Projectile** | Combat depends on Projectile | Instantiates via `Projectile.new(spawn_pos, direction, projectile_id)`; connects `projectile_hit_player` + `projectile_picked_up` signals; reads `Projectile.position`, `Projectile.velocity`, `Projectile.state`; writes `Projectile.velocity` for deflection (Rule 9); frees instances on kill/catch/pickup/round-end |
| **Movement** | Combat depends on Movement | Polls `Movement.is_iframe_active()` for catch/kill branch (Rule 6); reads `Movement.is_dead` + `Movement.facing` for throw gate (Rule 5); calls `Movement.set_dead()` on kill (Rule 7.1) |
| **Couch Input** | Combat depends on CouchInput | Subscribes to `throw_pressed(slot)`; reads `move_input(slot)` continuous query for throw direction stick value |
| **Character Controller** | Combat depends on CC | Reads `player_position` (CC's inherited Node2D `position`) for throw spawn computation. Does NOT call CC's command API. |
| **Map** | **No direct dependency** | Combat does NOT read Map data directly. Map's screen-wrap and collision affect Combat indirectly through Projectile and CC. **This corrects systems-index.md and concept.md, which incorrectly list Map as a Combat dep — see cross-system updates below.** |
| **Game State Manager** (indirect, via Round Flow) | no direct dependency | Combat is active only when GSM is in `InMatch`. Combat does not directly subscribe to GSM — it relies on Round Flow's round-start signal. |
| **Round Flow** | Round Flow ↔ Combat | Round Flow signals `round_started(MatchContext, round_index)` + `round_ended(winner_slot, round_index)` — Combat consumes per Rules 11, 12 (Combat ignores `round_index` + `winner_slot` payload; included in signatures for HUD consumption). Round Flow consumes `player_eliminated(victim_slot, killer_slot, projectile_id)` for alive tracking + round-end detection. *(Updated 2026-05-18 during Round Flow GDD design — signal arity aligned to 2-arg form; Round Flow no longer "undesigned".)* |
| **HUD** (forward contract — undesigned) | HUD depends on Combat | Subscribes to `stash_changed` + `player_eliminated`; queries `get_stash(slot)` + `get_thrower(projectile_id)` |

**External dependencies:**
- Godot 4.6 autoload system (Combat registered as `Combat` autoload)
- Godot 4.6 signal system (subscribe + emit)
- Godot 4.6 `dict` (per-player + per-projectile tracking)

**Cross-system updates required** (caught during Sections C.3, E, F drafting — 5 total):

1. **`design/gdd/projectile.md` Rule 7** must be gated by `state == Flying` — currently emits `projectile_hit_player` on any Player overlap, including in Stuck (would cause walk-over-stuck-shuriken to fire both pickup AND hit signals).
2. **`design/gdd/character-controller.md` Interactions row for Combat** currently says "Combat calls a kill method on CC" — stale. Update to: "Combat calls `Movement.set_dead()`; CC is freed later by Round Flow."
3. **`design/gdd/movement.md` Public Queries** lists only the 4 read queries — should add `set_dead()` as a public method (called by Combat Rule 7.1).
4. **`design/gdd/map.md` Interactions row for Combat** says "Queries map for currently-recoverable shurikens" — stale; Combat tracks stash, Projectile tracks recoverable shurikens. Remove or rewrite.
5. **`design/gdd/systems-index.md` + `design/gdd/game-concept.md`**: remove Map from Combat's "depends on" list (and the corresponding Feature Layer entry in systems-index Dependency Map).

All 5 will be applied in the post-design step.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `STASH_MAX` | 3 | **Locked** (Pillar 4 *Every Shuriken Matters*) | (locked) | (locked) |
| `THROW_SPAWN_OFFSET_PX` | 4 px | 0 – 12 px | Shuriken spawns further from player; harder to self-hit at spawn | Spawn closer to body; self-hit immunity does more work |
| `SHURIKEN_THROW_VELOCITY` | 200 px/s | 100 – 350 px/s | Faster shurikens; tighter dodge reaction window; longer cross-map range | Slower shurikens; more readable; close-range only. **Pins Projectile's deferred knob.** |
| `SELF_HIT_IMMUNITY_S` | 0.083 s (~5 frames @ 60 Hz) | 0.05 – 0.20 s | More protection at spawn; deflected shurikens take longer to be lethal back at thrower | Less protection; karma deflection works faster; risk of spawn self-hits |

**Referenced from other systems (not owned here):**
- `STICK_AIM_THRESHOLD` (Projectile-owned, default 0.25) — Combat uses for throw direction computation (Formula 1).
- `DODGE_IFRAME_DURATION_S` (Movement-owned, default 0.20 s) — Combat respects via `is_iframe_active()` poll; not a direct knob here.
- `SHURIKEN_GRAVITY_PX_S2` (Projectile-owned, default 600) — combined with `SHURIKEN_THROW_VELOCITY` determines arc shape.

**Interactions to watch:**

- `THROW_SPAWN_OFFSET_PX` × `SELF_HIT_IMMUNITY_S`: if offset is large (8+ px), immunity is less critical because the shuriken spawns clear of the body. If offset is small (0-2), immunity is essential.
- `SHURIKEN_THROW_VELOCITY` × `SHURIKEN_GRAVITY` (Projectile): arc shape. Steeper gravity needs higher velocity to maintain horizontal range.
- `SELF_HIT_IMMUNITY_S` × deflection ping-pong: short immunity means deflected shurikens can re-kill quickly; long immunity gives the original thrower time to dodge.

**Not knobs**: throw cooldown (no cooldown — stash is the gate, per Round 1); deflection physics (mirror + full-speed locked per Round 3); catch mechanism (auto-on-i-frame locked per Movement Round 1); stash decrement (always 1 per throw); per-clan tuning (forbidden by Pillar 2).

**Concept doc update required**: `design/gdd/game-concept.md` Tuning Knobs row for `shuriken_throw_velocity` is stale (currently "TBD (prototype-driven)") — resolve to **200 px/s** *(pinned 2026-05-17 during Combat GDD design)*.

## Acceptance Criteria

### Throw flow

- [ ] `throw_pressed` with stash > 0 + alive: Projectile instantiated; stash decrements; `stash_changed` emitted
- [ ] `throw_pressed` with stash == 0: signal ignored; no Projectile spawned; no stash change
- [ ] `throw_pressed` while `Movement.is_dead`: signal ignored
- [ ] Rapid-fire 3 throws → 3 Projectiles in flight; stash goes 3→0 within 3 input frames
- [ ] Throw direction matches Projectile Formula 1 (stick aim with facing fallback)
- [ ] Throw spawn position = `player_position + direction * THROW_SPAWN_OFFSET_PX`

### Self-hit immunity

- [ ] Within `SELF_HIT_IMMUNITY_S` of throw: thrower's own `projectile_hit_player` signal is ignored
- [ ] After immunity expires: self-hit signal is processed (can kill thrower via deflection)
- [ ] Other players are NOT affected by thrower's immunity window (only the thrower-victim pair)

### Hit branch decisions

- [ ] `projectile_hit_player` + `is_iframe_active == false` + non-thrower-or-post-immunity → kill path (Rule 7)
- [ ] `projectile_hit_player` + `is_iframe_active == true` + `stash < STASH_MAX` → catch path (Rule 8)
- [ ] `projectile_hit_player` + `is_iframe_active == true` + `stash == STASH_MAX` → deflect path (Rule 9)

### Kill resolution

- [ ] `Movement.set_dead()` called on victim within same tick as hit
- [ ] `player_eliminated(victim, killer, projectile_id)` emitted exactly once per kill
- [ ] Projectile freed via `queue_free()` after kill
- [ ] `thrower_by_projectile` entry removed
- [ ] Self-hit kill (post-immunity): `killer_slot == victim_slot`

### Catch

- [ ] `stash_by_slot[victim]` increments by 1
- [ ] `stash_changed(victim, new_count, +1)` emitted
- [ ] Projectile freed
- [ ] Consecutive catches: stash goes 0→1→2→3, then deflect path on next i-frame hit

### Deflect

- [ ] `projectile.velocity` set to `-velocity` (mirror, full magnitude)
- [ ] `thrower_by_projectile` entry retained (ownership preserved)
- [ ] Projectile NOT freed (stays in scene, re-enters Flying behavior)

### Pickup handling

- [ ] `projectile_picked_up`: stash increments; `stash_changed` emitted
- [ ] Defensive guard: if stash already at max, no-op (shouldn't happen with proper Projectile filtering, but Combat defends)
- [ ] Projectile freed
- [ ] `thrower_by_projectile` entry removed

### Round-start init

- [ ] On `round_started(MatchContext)`: all active slots' stash set to `STASH_MAX`
- [ ] `stash_changed` fires for each active slot
- [ ] `next_projectile_id` resets to 1
- [ ] `thrower_by_projectile` cleared

### Round-end cleanup

- [ ] On `round_ended`: all live Projectile instances freed
- [ ] `thrower_by_projectile` cleared
- [ ] `stash_by_slot` NOT cleared (retained for HUD display during MatchEnd)

### Stash invariants

- [ ] `0 ≤ stash_by_slot[slot] ≤ STASH_MAX` at all times for every active slot
- [ ] No-duplication invariant: `sum(stash_by_slot) + count(live Projectiles)` ≤ `STASH_MAX × num_players` (shurikens never duplicated)

### Cross-system integration (verified at consumer side)

- [ ] `Movement.is_iframe_active()` correctly polled at hit time (Movement-side test)
- [ ] `Movement.set_dead()` correctly transitions Movement to Dead (Movement-side test)
- [ ] Projectile signals correctly received and resolved (Projectile-side test)
- [ ] Round Flow receives `player_eliminated` and updates alive count (Round Flow-side test)
- [ ] HUD reactively updates per `stash_changed` (HUD-side test)

### Performance

- [ ] Throw signal handler: ≤0.1 ms per throw
- [ ] Hit signal handler: ≤0.3 ms per hit (includes Movement query + branch decision)
- [ ] 4-player concurrent burst (up to 12 Projectiles in flight + matching dicts): Combat budget ≤ 1 ms/frame total

### Code hygiene

- [ ] Combat is autoload registered as `Combat`
- [ ] All tuning knobs (Section G) exposed via config Resource
- [ ] No direct `InputEvent` reads in Combat (input flows through CouchInput's typed signals)
- [ ] Signal payloads are typed (`signal stash_changed(slot: int, new_count: int, delta: int)`)
- [ ] All public queries (`get_stash`, `get_thrower`) documented with semantics

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| **Projectile GDD Rule 7** must be gated by `state == Flying`. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: Projectile Rule 7 updated with Flying-state gate |
| **CC GDD Interactions Combat row** stale. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: CC GDD updated to reflect Combat → Movement.set_dead flow |
| **Movement GDD Public Queries** should document `set_dead()`. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: Movement GDD updated with Public Mutators section documenting set_dead() |
| **Map GDD Interactions Combat row** stale. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: Map GDD updated; Combat row corrected (no direct dependency) |
| **systems-index + concept doc** list Map in Combat's deps. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: Map removed from Combat dep list in both systems-index and concept doc |
| **concept doc Tuning Knobs row** for `shuriken_throw_velocity` stale. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: concept doc updated; pinned at 200 px/s |
| **Projectile constructor signature alignment** (caught during /design-review): both GDDs misaligned on args. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: aligned to `(position, direction, throw_velocity, projectile_id)` — 4 args |
| **CC needs `slot` field** for Combat to identify victim from collision body (caught during /design-review). | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: CC GDD Rule 14 added documenting slot field |
| **Combat Rule 7 needs double-kill guard** to prevent duplicate `player_eliminated` (caught during /design-review). | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: Rule 7.1 added with already-dead guard; Edge Cases row 13 added |
| **Round Flow contracts**: must emit `round_started(MatchContext)` + `round_ended()`; consume `player_eliminated` for alive tracking + round-end detection. | Round Flow GDD author | Before Round Flow GDD approved | **Resolved 2026-05-18**: Round Flow GDD approved. Signal arities aligned to `round_started(MatchContext, round_index)` and `round_ended(winner_slot, round_index)` — see Combat Interactions + Dependencies tables. |
| **HUD contracts**: subscribe to `stash_changed` + `player_eliminated`; use `get_stash` + `get_thrower` queries; decide kill-feed display UX (duration, position, animation). | HUD GDD author | Before HUD GDD approved | Forward contract |
| **`MatchContext` schema** is under-specified in GSM GDD — what fields does Combat read from it at `round_started`? At minimum: active slot list. Verify during Round Flow design. | game-designer + Round Flow GDD author | Before Round Flow GDD approved | **Partially resolved 2026-05-18**: Round Flow GDD enumerates the MatchContext fields it reads/writes (`map_id`, `active_slots`, `match_target`, `final_scores`, `winner_slot`, `rounds_played`). Full schema formalization still pending — owner moved to GSM GDD. |
| **Stash event payload format**: currently `(slot, new_count, delta)`. Alternative: `(slot, old_count, new_count)`. Minor UX choice for HUD; either works. | HUD GDD author | Before HUD GDD approved | Defer to HUD |
| **Initial tuning values** are placeholders. MVP playtest priorities: `SHURIKEN_THROW_VELOCITY` (the named "reaction time required to dodge" lever from concept doc), `SELF_HIT_IMMUNITY_S`, deflection ping-pong tuning observation. | game-designer + Combat implementer | MVP playtest cycles | Defer to playtest |
