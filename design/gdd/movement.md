# Movement

> **Status**: Approved (reconciled with prototype validation 2026-06-02)
> **Author**: artursums + assistant
> **Last Updated**: 2026-06-02
> **Implements Pillar**: Primary — *Game-Feel First*; Secondary — *Fairness Is Sacred*

> ## Prototype Reconciliation (2026-06-02) — AUTHORITATIVE
> The `prototypes/movement-and-combat` playtest validated changes to this design. Where the
> body below disagrees, this block wins (production follows it):
>
> 1. **No air-jump / no double jump.** The air-jump was removed in the prototype and the
>    single-jump feel was judged cleaner. **Rules 4.6, 6b, 12, the `air_jump_available` flag,
>    and the `AIR_JUMP_STRENGTH` knob are CUT.** Vertical recovery comes from the single
>    ground-jump + **coyote time** (forgiveness) + wall-jump. Wall-jump still does not consume
>    a jump (there is no air-jump to consume).
> 2. **Dodge has no separate cooldown.** Re-dodge is gated only by `DODGE_TOTAL_DURATION_S`
>    (the lockout window), per Formula 1. The prototype's extra slide-cooldown + "instant
>    ground-reset" were artifacts of a different model and do not carry over.
> 3. **Pinned starting values** (from the validated prototype; CC values live in
>    `character_controller_config.tres`): `GRAVITY 1400`, `TERMINAL 320`, `MAX_HSPEED 158.4`,
>    `JUMP_STRENGTH 480`, `DODGE_DASH_SPEED 400`, `DODGE_IFRAME 0.20`, `DODGE_TOTAL 0.30`.
> 4. **Defense (L2 guard) is NOT in v1** (deferred; was never part of this GDD).

## Overview

Movement is the player-verb composition layer for Four Clans. It sits between
Couch Input (which delivers raw player intent — stick vectors, button presses)
and Character Controller (which executes physics primitives — set velocity,
apply impulse, query ground contact). Movement is where intent becomes
action: it reads the player's stick + button presses, reads the character's
current physics state, and decides which verb to express on this tick —
walk, jump, double-jump, dodge, wall-slide, wall-jump, or drop-through. It
owns the contextual A-button resolution (jump vs dodge based on character
state), the dodge i-frame window (the single most consequential balance
lever in the game per the concept doc), the wall-jump composition (CC has
no native wall-jump method), and the comfort layer (coyote time, jump
buffer) that makes the platforming feel forgiving.

The player never interacts with Movement directly — they press buttons,
they see their ninja jump or dodge. Movement is the translation. Remove it
and the player has primitives without verbs: the A button doesn't know
whether to call jump-impulse or dodge-impulse, the wall doesn't kick back,
the dodge has no i-frames. This is the system the entire *Game-Feel First*
pillar lives or dies on — every other system inherits its decisions.

## Player Fantasy

Movement should make the player feel like they're inside the ninja's
muscles. Every jump lands where they aimed. Every dodge feels like a
deliberate commitment — a moment of risk traded for a moment of
invincibility. Every wall touch becomes a fresh decision: slide, jump off,
or drop. The verbs should be few, but each one should feel deep enough
that mastery is the whole game.

The dodge is the system's signature verb. The same A-button that jumps
when you're moving becomes a dodge when you're still — and to be still is
to be exposed. That contextual overlap is not a UI shortcut; it's a
tactical commitment. The dodge i-frame window rewards the player for
*reading the throw*, not for spamming the button. When a dodge succeeds
against an incoming shuriken, the player should feel like they out-read
the thrower, not like they got lucky. TowerFall is the explicit
reference: the dodge isn't an evasion, it's a parry. Per the concept doc,
"players treat the dodge button as an active catch / parry, not just an
evasion."

Movement is *Game-Feel First* made concrete: per the pillar, *"tuning the
dodge frame count, the throw arc, the wall-slide friction matters more
than content."* And per *Fairness Is Sacred*, every player gets the exact
same Movement system — no clan-modifier, no per-character tuning. The bet
is that one deeply-tuned vocabulary has more skill ceiling than four
shallow ones.

## Detailed Design

### Core Rules

1. Movement is a Godot Node (`PlayerMovement`) attached as a **child** of `PlayerCharacterBody`. One instance per active player slot, instantiated by Round Flow at round start, freed by Round Flow at round end (or on death after a brief delay for kill-cam).

2. Movement subscribes to CouchInput's `move_input(slot, vector)` and `primary_action_pressed(slot)`, filtered to its owner's slot. It calls CC's command API (`set_horizontal_intent`, `apply_jump_impulse`, `cancel_jump`, `apply_dodge_impulse`, `set_vertical_velocity`, `drop_through_request`) and reads CC's state queries (`is_on_floor`, `is_on_wall`, `wall_normal`, `velocity`, `is_stationary`).

3. **Walk** (every `_physics_process` tick, while alive):
   - Read latest `move_input(slot).vector` (deadzone-cleaned by CouchInput).
   - Call `CC.set_horizontal_intent(stick.x * MAX_HSPEED)`.
   - Update `facing` to `sign(stick.x)` when `stick.x != 0`; persists when stick neutral. Default `+1` on instantiation.

4. **A-button decision tree** (on `primary_action_pressed`, evaluated in priority order; first match wins):
   1. **Drop-through**: if `stick.y > DROP_THROUGH_THRESHOLD` AND on a one-way platform → call `CC.drop_through_request()`. **Return**.
   2. **Locked in dodge**: if `is_dodging` → ignore press. **Return**.
   3. **Wall-jump**: if `CC.is_on_wall()` AND NOT `CC.is_on_floor()` AND `wall_jump_cooldown_remaining == 0` → wall-jump (Rule 7). **Return**.
   4. **Dodge**: if `CC.is_stationary()` → dodge (Rule 5). **Return**.
   5. **Ground-jump**: if `CC.is_on_floor()` OR `coyote_remaining > 0` → ground-jump (Rule 6a). **Return**.
   6. **Air-jump**: if `air_jump_available` → air-jump (Rule 6b). **Return**.
   7. **Buffer**: airborne with no available jump → set `jump_buffer_remaining = JUMP_BUFFER_FRAMES`. **Return**.

5. **Dodge**:
   - Compute `dodge_direction`:
     - If `stick.length() >= STICK_NEUTRAL_THRESHOLD`: `stick.normalized()`.
     - Else: `Vector2(facing, 0)` (horizontal dash in facing direction).
   - Call `CC.apply_dodge_impulse(dodge_direction, DODGE_DASH_SPEED)`.
   - Set `is_dodging = true` for `DODGE_TOTAL_DURATION_MS`.
   - Set `is_iframe_active = true` for `DODGE_IFRAME_DURATION_MS` (must be `≤ DODGE_TOTAL_DURATION_MS`).
   - **Catch behavior**: while `is_iframe_active`, any shuriken colliding with the CC body is *caught* — added to the player's stash (cap at 3) instead of killing. Combat polls `is_iframe_active()` from Movement at hit time.
   - At `DODGE_TOTAL_DURATION_MS` elapse: clear `is_dodging`, clear `is_iframe_active`. No recovery state in v1.

6. **Jump** (two variants):
   - **6a. Ground-jump**: Call `CC.apply_jump_impulse(JUMP_STRENGTH)`. Clear `coyote_remaining`. Set `air_jump_available = true`.
   - **6b. Air-jump**: Call `CC.apply_jump_impulse(AIR_JUMP_STRENGTH)`. Set `air_jump_available = false`.

7. **Wall-jump**:
   - Read `n = CC.wall_normal()` (`(-1, 0)` for left wall, `(+1, 0)` for right wall).
   - Call `CC.apply_jump_impulse(WALL_JUMP_VERTICAL_STRENGTH)`.
   - Call `CC.set_horizontal_intent(n.x * WALL_JUMP_HORIZONTAL_KICK)` (kick away from wall).
   - Set `wall_jump_cooldown_remaining = WALL_JUMP_COOLDOWN_MS`.
   - **Does NOT consume** `air_jump_available`.

8. **Wall-slide** (every tick, while alive, while `!is_on_floor AND is_on_wall AND CC.velocity.y > 0`):
   - If `CC.velocity.y > WALL_SLIDE_MAX_FALL_SPEED`: call `CC.set_vertical_velocity(WALL_SLIDE_MAX_FALL_SPEED)`.
   - No discrete state — the velocity cap IS the wall-slide.

9. **Jump-cut** (every tick, while alive):
   - If `CC.velocity.y < 0` (moving upward post-jump) AND A-button currently NOT held → call `CC.cancel_jump()`.

10. **Coyote-time lifecycle**:
    - On `CC.is_on_floor()` transition `true → false` AND the transition was NOT caused by a jump executed this tick → set `coyote_remaining = COYOTE_TIME_FRAMES`.
    - Decrement each tick toward 0.
    - Clear on: landing, executing any jump, or expiry.

11. **Jump-buffer lifecycle**:
    - Set per Rule 4.7.
    - Decrement each tick toward 0.
    - On `CC.is_on_floor()` transition `false → true` while `jump_buffer_remaining > 0`: execute ground-jump (Rule 6a). Clear buffer.
    - Clear on: expiry, or buffer-jump fired.

12. **Air-jump availability**:
    - Set `air_jump_available = true` on `is_on_floor` transition `false → true` (landing).
    - Set `false` when consumed by air-jump (Rule 6b).
    - Wall-touch does NOT refresh.

13. **Death**:
    - On Combat's kill signal: set `is_dead = true`. Suppress all input handling and all velocity intents (subsequent ticks: no `set_horizontal_intent`, no jump/dodge logic).
    - Movement instance remains briefly under Round Flow's control for kill-cam / death FX, then freed.
    - Fresh Movement re-instantiates on next round via Round Flow.

14. **Identical across clans**: All Movement parameters are global, not per-clan. Per Pillar 2 (Fairness Is Sacred), no per-clan tuning overrides.

### States and Transitions

Movement carries no canonical state machine — it is a policy + flags layer.
The "states" of a player from a fantasy / animation perspective (idle,
walking, falling, wall-sliding, dodging, dead) are *implicit*: each is
derived from the combination of Movement's transient flags + CC's state
queries. Visual FX uses the derivations of `velocity` + `is_on_floor` +
`is_on_wall` + `is_dodging` + `is_dead` to drive its animation state
machine.

Movement owns the following internal flags and counters:

| Field | Type | Set by | Cleared by | Used for |
|---|---|---|---|---|
| `is_dodging` | bool | Dodge action (Rule 5) | `DODGE_TOTAL_DURATION_MS` elapses | A-button re-evaluation suppressed (Rule 4.2) |
| `is_iframe_active` | bool | Dodge action (Rule 5) | `DODGE_IFRAME_DURATION_MS` elapses (subset window of `is_dodging`) | Combat polls to enable catch-instead-of-kill behavior |
| `air_jump_available` | bool | Landing (`CC.is_on_floor` false→true transition) | Air-jump executed (Rule 6b) | Gates Rule 4.6 |
| `coyote_remaining` | float (s) | Walked off ledge (Rule 10) | Landing; any jump executed; expiry | Allows ground-jump even when `!is_on_floor` (Rule 4.5) |
| `jump_buffer_remaining` | float | Airborne A-press with no available jump (Rule 4.7) | Expiry; or buffer-jump fired on landing (Rule 11) | Next landing triggers ground-jump |
| `wall_jump_cooldown_remaining` | float | Wall-jump executed (Rule 7) | Expiry | Suppresses Rule 4.3 |
| `is_dead` | bool | Combat kill signal (Rule 13) | Instance freed; next round's instance is fresh | Suppresses all input + intent processing |
| `facing` | int (`-1` or `+1`) | Stick `x != 0` (Rule 3) | Persists when stick neutral; reset to `+1` on instantiation | Dodge direction default (Rule 5); Visual FX sprite flip |

**Movement does NOT expose a canonical `current_state` enum.** Downstream
consumers query the individual flags + CC state. This avoids drift between
Movement's "state name" and its actual behavior, and keeps Visual FX as the
single owner of animation-state-machine semantics.

**Public queries Movement exposes:**

- `is_dodging() -> bool`
- `is_iframe_active() -> bool`
- `is_dead() -> bool`
- `facing -> int` (read-only property)

**Public mutators Movement exposes:**

- `set_dead()` — transitions Movement to Dead state (per Rule 13). Idempotent: calling on already-dead Movement is a no-op. Called by Combat on kill (Combat Rule 7.1). *(added 2026-05-17 during Combat GDD design — was implied by Rule 13 but not documented as public API)*

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **Couch Input** | Movement subscribes to `move_input(slot, vector)` (continuous per-tick polling) and `primary_action_pressed(slot)` (discrete signal). Filters to its owner's slot. Owns A-button semantic resolution (jump vs dodge vs wall-jump vs drop-through per Rule 4). | CouchInput → Movement |
| **Character Controller** | Movement calls `set_horizontal_intent(v)`, `apply_jump_impulse(strength)`, `cancel_jump()`, `apply_dodge_impulse(direction, strength)`, `set_vertical_velocity(v)` (for wall-slide cap — see Dependencies + Open Questions: CC GDD Rule 6 mentions this method but Rule 10's command list omits it), `drop_through_request()`. Reads `is_on_floor`, `is_on_wall`, `wall_normal`, `velocity`, `is_stationary`. | Movement ↔ CC |
| **Combat** | Combat polls `Movement.is_iframe_active()` at shuriken-vs-player collision time. If true: catch (add to stash, do not kill). If false: kill (Combat signals death back to Movement, which transitions to Rule 13 Dead state). | Movement ↔ Combat |
| **Round Flow** | Round Flow instantiates `PlayerCharacterBody` + child `PlayerMovement` at round start at assigned spawn points (per Map GDD). On death (Combat → Movement → Dead state), Round Flow controls free timing for kill-cam / death FX. On round end, Round Flow frees all surviving CC+Movement instances. | Round Flow → Movement |
| **Visual FX** | Visual FX reads `Movement.is_dodging()`, `is_iframe_active()`, `is_dead()`, `facing` + CC's `velocity`, `is_on_floor`, `is_on_wall` to derive animation state machine inputs (idle/walk/jump/fall/wall-slide/dodge/dead). Movement does NOT push animation state — Visual FX pulls and derives. | Movement → Visual FX |

**Forward contracts**: Combat, Round Flow, and Visual FX GDDs do not yet
exist. The interfaces above are this GDD's expectations of them; those
GDDs will need to either honor these contracts or escalate a change back
to this Movement GDD.

## Formulas

Movement's math is mostly predicates and assignments — the load-bearing
formulas are the dodge timing windows (the concept's "single most
consequential balance lever") and the wall-jump impulse decomposition. All
default values are starting offers for prototype iteration per Pillar 5.

### Formula 1: Dodge timing windows

```
t_now           := engine wall-clock time, seconds
t_dodge_start   := time of last dodge action (or -inf if never dodged)

is_iframe_active(t_now) := (t_now - t_dodge_start) < DODGE_IFRAME_DURATION_S
is_dodging(t_now)       := (t_now - t_dodge_start) < DODGE_TOTAL_DURATION_S
```

Constraint: `DODGE_IFRAME_DURATION_S ≤ DODGE_TOTAL_DURATION_S` (i-frames are a subset of the dodge state).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `t_now` | float (s) | (0, ∞) | engine | Wall-clock seconds since boot |
| `t_dodge_start` | float (s) | (0, ∞) or `-inf` | Movement internal | Time of most recent dodge action |
| `DODGE_IFRAME_DURATION_S` | float (s) | 0.10 – 0.30 | tuning knob | Default **0.20 s** (~12 frames @ 60 Hz). The "single most consequential balance lever" per the concept doc |
| `DODGE_TOTAL_DURATION_S` | float (s) | 0.20 – 0.50 | tuning knob | Default **0.30 s** (~18 frames). Locks A-button re-evaluation for this window |

**Example**: With defaults (0.20 i-frame, 0.30 total): a dodge at `t = 10.000 s` makes `is_iframe_active` true for `t ∈ [10.000, 10.200)` and `is_dodging` true for `t ∈ [10.000, 10.300)`. Combat sees catch behavior in the first 200 ms; the next 100 ms are dodge "recovery" (still locked from re-dodging but i-frames have ended — exposed window).

### Formula 2: Dodge direction resolution

```
function compute_dodge_direction(stick: Vector2, facing: int) -> Vector2:
    if stick.length() >= STICK_NEUTRAL_THRESHOLD:
        return stick.normalized()
    else:
        return Vector2(facing, 0)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `stick` | Vector2 | length 0 – 1 | CouchInput deadzone output | Player movement intent |
| `STICK_NEUTRAL_THRESHOLD` | float | 0.15 – 0.40 | tuning knob | Default **0.25**. Stick below this magnitude is treated as neutral |
| `facing` | int | -1, +1 | Movement internal | Last non-zero horizontal direction |

**Examples**:
- `stick = (0.0, -0.9)` → returns `(0.0, -1.0)` (pure upward dodge — air dodge straight up).
- `stick = (0.7, 0.7)` → returns `(0.707, 0.707)` (diagonal dodge up-right).
- `stick = (0.05, 0.0)`, `facing = +1` → returns `(+1, 0)` (neutral stick falls back to facing right).

### Formula 3: Wall-jump impulse decomposition

Composed from two CC calls executed in the same tick:

```
n := CC.wall_normal()                          # (-1, 0) for left wall, (+1, 0) for right wall

CC.apply_jump_impulse(WALL_JUMP_VERTICAL_STRENGTH)
   # effect: CC.vertical_velocity := -WALL_JUMP_VERTICAL_STRENGTH

CC.set_horizontal_intent(n.x * WALL_JUMP_HORIZONTAL_KICK)
   # effect: target horizontal velocity := n.x * WALL_JUMP_HORIZONTAL_KICK
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `n` (wall normal) | Vector2 | `(-1, 0)` or `(+1, 0)` | CC.wall_normal() | Direction OUT of the wall (perpendicular to the wall, away from it) |
| `WALL_JUMP_VERTICAL_STRENGTH` | float (px/s) | 200 – 500 | tuning knob | Default **350** (slightly less than ground `JUMP_STRENGTH` to nudge players to favor regular jumps when grounded) |
| `WALL_JUMP_HORIZONTAL_KICK` | float (px/s) | 100 – 250 | tuning knob | Default **180** (1.5× CC's default `MAX_HSPEED` of 120 — a deliberate "kick" past normal walk speed) |

**Example**: Player against right wall (`wall_normal = (-1, 0)`) presses A → vertical velocity becomes `-350` (upward in Godot Y-down); `horizontal_intent` becomes `-1 × 180 = -180` (leftward, away from wall). CC's horizontal acceleration (3000 px/s²) reaches that intent within ~2 frames, then natural physics + gravity take over.

### Formula 4: Coyote-time eligibility

```
coyote_active(t_now) := coyote_remaining > 0

# Lifecycle:
on ledge-walk-off (is_on_floor transition true→false, NOT via jump):
    coyote_remaining := COYOTE_TIME_S
on each tick: coyote_remaining := max(0, coyote_remaining - delta_t)
on landing OR any jump executed: coyote_remaining := 0
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `coyote_remaining` | float (s) | [0, COYOTE_TIME_S] | Movement internal | Time remaining in coyote window |
| `COYOTE_TIME_S` | float (s) | 0.05 – 0.15 | tuning knob | Default **0.083 s** (~5 frames @ 60 Hz) |
| `delta_t` | float (s) | ~0.0167 | physics tick | Per-tick advance |

**Example**: Player walks off ledge at `t = 5.000 s` → `coyote_remaining = 0.083`. At `t = 5.040 s` (40 ms later) player presses A → `coyote_remaining ≈ 0.043` (> 0) → ground-jump executes (Rule 4.5).

### Formula 5: Jump-buffer eligibility

```
buffer_fires_this_tick := jump_buffer_remaining > 0 AND just_landed_this_tick

# Lifecycle:
on airborne A-press with no available jump (Rule 4.7):
    jump_buffer_remaining := JUMP_BUFFER_S
on each tick: jump_buffer_remaining := max(0, jump_buffer_remaining - delta_t)
on buffer-jump fired: jump_buffer_remaining := 0
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `jump_buffer_remaining` | float (s) | [0, JUMP_BUFFER_S] | Movement internal | Time remaining in buffer window |
| `JUMP_BUFFER_S` | float (s) | 0.05 – 0.15 | tuning knob | Default **0.083 s** (~5 frames @ 60 Hz) |
| `just_landed_this_tick` | bool | true/false | derived from `CC.is_on_floor` rising edge | Edge detector |

**Example**: Player presses A in air at `t = 10.000 s` with no jump available (no air-jump, no wall) → buffer set to `0.083 s`. Lands at `t = 10.040 s` (`just_landed_this_tick = true`) → `buffer_fires_this_tick = true` → ground-jump fires immediately on the landing tick.

### Formula 6: Wall-slide velocity cap

```
on each physics tick (while alive, while !is_on_floor AND is_on_wall AND velocity.y > 0):
    if CC.velocity.y > WALL_SLIDE_MAX_FALL_SPEED:
        CC.set_vertical_velocity(WALL_SLIDE_MAX_FALL_SPEED)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `CC.velocity.y` | float (px/s) | (-∞, `TERMINAL_VELOCITY`) | CC | Current vertical velocity (positive = down per Godot Y-down) |
| `WALL_SLIDE_MAX_FALL_SPEED` | float (px/s) | 60 – 200 | tuning knob | Default **100 px/s** (~ 1/6 of `TERMINAL_VELOCITY = 600`) |

**Example**: Player falls at 400 px/s, then grabs a wall (`is_on_wall` becomes true on next tick). On that tick, `velocity.y = 400 > 100` → `CC.set_vertical_velocity(100)`. Subsequent ticks: gravity adds back during CC's physics, cap re-engages next tick. Net steady-state vertical velocity: ~`100 px/s + gravity_per_tick / 2`.

### Formula 7: Jump-cut trigger

Movement decides *when* to trigger jump-cut; CC owns the actual velocity clamp (per CC Formula §"Jump-cut").

```
on each physics tick (while alive):
    if CC.velocity.y < 0 AND NOT a_button_held:
        CC.cancel_jump()
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `CC.velocity.y` | float (px/s) | (-∞, ∞) | CC | Negative = upward (Godot Y-down) |
| `a_button_held` | bool | true/false | CouchInput continuous query | True while A is held |

**Example**: Player ground-jumps at `t = 10.000 s` (`velocity.y = -400`, using a placeholder `JUMP_STRENGTH`). Releases A at `t = 10.060 s`. `velocity.y` at that tick ≈ `-330` (gravity reduced it). NOT held + upward → `CC.cancel_jump()` clamps to `-JUMP_CUT_VELOCITY = -200` (per CC's `JUMP_CUT_VELOCITY_PX_S` default).

Result: short tap → short jump arc; held tap → full jump arc. Standard TowerFall / Mario behavior.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| A-press during `is_dodging` | Ignored (per Rule 4.2). Player is locked until `DODGE_TOTAL_DURATION_S` elapses. | Prevents stutter-dodge exploits; preserves dodge as a real commitment |
| Dodge during wall-slide | Not possible. Player is not stationary (airborne + falling). A-press → wall-jump (Rule 4.3) or air-jump fallback. | Wall-slide is a vulnerable state by design |
| Jump-buffer + coyote-time overlap (A pre-pressed, then walks off ledge) | Buffer counts down independently; if player re-presses A within coyote, Rule 4.5 fires immediately and buffer is cleared. If buffer expires first, coyote may still fire on next A-press. No conflict between mechanisms. | Each timer is independent; precedence is per-press |
| Dodge dash into wall corner mid-flight | CC handles collision; dash velocity stops at wall. `is_dodging` continues for full duration; i-frames remain active. Player can wall-jump out when dodge ends. | CC's collision is correct; Movement doesn't need to abort the dodge |
| Wall-jump on screen-wrap edge | Map's wrap preserves velocity. Wall-jump arc completes normally on the other side. | Wrap is positional only; Movement needs no special case |
| Wall-jump cooldown across screen-wrap | Cooldown is a per-Movement-instance timer; survives wrap. Player wrapping onto another wall during cooldown: A-press falls through to air-jump (Rule 4.6) or no-op. | Cooldown is the canonical wall-spam prevention |
| Wall-jump in corner (player touches two walls simultaneously) | `CC.wall_normal()` returns one normal (CC implementation chooses; deterministic per Godot's physics). Wall-jump uses that normal. | Corner cases rare in well-designed maps; acceptable in v1 |
| Catch during stash-full (player at 3 shurikens dodges into incoming shuriken) | I-frames prevent death; shuriken is **deflected** (bounces off the ninja, stays in play with reflected velocity). Stash stays at 3. | **Forward contract for Combat GDD**: implement deflection physics when `Movement.is_iframe_active() && stash_count == STASH_MAX` |
| Player dies mid-dodge | Combat signals death → Movement enters Dead state → `is_dodging`, `is_iframe_active`, all flags cleared by Dead-state suppression. | Death is highest-priority transition; clean state reset |
| Drop-through on one-way platform directly above a solid floor | Per CC Rule 12: down+A → `drop_through_request` → one-way disabled for 1 tick → player falls → lands on solid floor next tick. | CC's existing physics handles this correctly |
| Air-jump exploit attempt — wall-touch does NOT refresh air-jump | Per Rule 12: wall-touch does NOT refresh. Player who used their air-jump must touch ground to refresh. Wall-jump is the alternative aerial vertical tool. | Reaffirms Round 2 decision: wall and air-jump are separate resources |
| Stick magnitude exactly equal to `STICK_NEUTRAL_THRESHOLD` | Rule 5 uses `>=`. Equality is treated as "stick has direction" → dodge dashes in stick direction. | Defensive: CouchInput's deadzone already returns clean values; no NaN paths |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| **Character Controller** | Movement depends on CC | Calls CC's command API (`set_horizontal_intent`, `apply_jump_impulse`, `cancel_jump`, `apply_dodge_impulse`, `set_vertical_velocity`, `drop_through_request`); reads CC's state queries (`is_on_floor`, `is_on_wall`, `wall_normal`, `velocity`, `is_stationary`) |
| **Couch Input** | Movement depends on CouchInput | Subscribes to `move_input(slot, vector)` (continuous) and `primary_action_pressed(slot)` (discrete), filtered to its owner's slot; reads continuous A-button-held state for jump-cut |
| **Combat** | Combat depends on Movement | Polls `Movement.is_iframe_active()` at shuriken-vs-player collision to gate catch-vs-kill; signals death back to Movement (transitions Movement to Dead state); inherits forward contracts (stash-full deflection from Edge Case row 8) |
| **Round Flow** | Round Flow depends on Movement | Instantiates `PlayerCharacterBody` + child `PlayerMovement` at round start at Map spawn points; controls free timing for kill-cam / death FX; frees all surviving instances at round end |
| **Visual FX** | Visual FX depends on Movement | Reads `is_dodging()`, `is_iframe_active()`, `is_dead()`, `facing` + CC's `velocity`, `is_on_floor`, `is_on_wall` to derive animation state machine inputs (idle/walk/jump/fall/wall-slide/dodge/dead) |

**External dependencies:**
- Godot 4.6 signal system (signal subscription from CouchInput; signal handler for Combat's kill ack)
- Godot 4.6 `Node` (Movement is a Node child of `PlayerCharacterBody`)
- Godot 4.6 `_physics_process(delta)` (60 Hz fixed tick for all per-tick logic)

**Bidirectional consistency notes:**

- `design/gdd/systems-index.md` already lists Movement correctly: depends on Character Controller + Couch Input (Core Layer row 5); depended on by Combat, Round Flow, Visual FX (their respective rows). No index updates needed for dependency direction.
- **`design/gdd/game-concept.md` Dependencies table is stale on Movement**: currently says "Movement depends on: Couch Input", missing Character Controller. Recommend updating to "Movement depends on: Character Controller, Couch Input" during the post-design index-update step (similar updates were made for Round Flow during prior GDD passes).
- **CC GDD internal API inconsistency**: `design/gdd/character-controller.md` Rule 6 mentions `set_vertical_velocity(v)` as a Movement-callable method, but Rule 10's command list omits it. Movement Rule 8 (wall-slide) and Rule 2 (API list) both call it. Recommend updating CC GDD Rule 10 to include this method for consistency. Carried to Open Questions for the implementation step.
- Combat, Round Flow, and Visual FX GDDs are **not yet designed**. The contracts above are forward expectations those GDDs must honor when authored.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `DODGE_IFRAME_DURATION_S` | 0.20 s (~12 frames) | 0.10 – 0.30 s | More forgiving dodge; easier catches; potential stalemates if too long | More skill-based dodge; tighter window; risk of "unfair" hits |
| `DODGE_TOTAL_DURATION_S` | 0.30 s (~18 frames) | 0.20 – 0.50 s | Longer commitment per dodge (slower recovery); fewer dodges per fight | Faster dodge recovery; more dodge-spammy gameplay |
| `DODGE_DASH_SPEED` | 300 px/s | 200 – 500 px/s | Bigger dodge distance; harder for thrower to track | Smaller dodge distance; more positional commitment |
| `STICK_NEUTRAL_THRESHOLD` | 0.25 | 0.15 – 0.40 | Stick must be more deliberately released for default-facing dodge | More sensitive — slight stick wiggle counts as directional |
| `DROP_THROUGH_THRESHOLD` | 0.5 | 0.35 – 0.65 | Player must firmly hold down to drop through (deliberate) | Easier accidental drop-through; lighter stick triggers it |
| `JUMP_STRENGTH` | 400 px/s | 300 – 500 px/s | Higher jumps; longer airtime; more aerial control | Lower jumps; tighter platforming |
| `AIR_JUMP_STRENGTH` | 350 px/s | 250 – 450 px/s | More vertical recovery from air-jump | Less generous air-jump; harder vertical recovery |
| `WALL_JUMP_VERTICAL_STRENGTH` | 350 px/s | 200 – 500 px/s | Wall-jumps gain more height | Wall-jumps barely lift; need many to climb |
| `WALL_JUMP_HORIZONTAL_KICK` | 180 px/s | 100 – 250 px/s | Bigger push away from wall (harder to wall-spam) | Less push; easier to bounce back onto same wall |
| `WALL_JUMP_COOLDOWN_MS` | 300 ms | 150 – 500 ms | Slower re-trigger on same wall; cleaner wall-jump pacing | Faster re-trigger; risk of single-wall vertical climb |
| `WALL_SLIDE_MAX_FALL_SPEED` | 100 px/s | 60 – 200 px/s | Faster wall-slides; less wall-as-cover viability | Stickier wall-slides; better positioning, more stalls |
| `COYOTE_TIME_S` | 0.083 s (5 frames) | 0.05 – 0.15 s | More forgiving ledge-walk jumps; risk of "phantom jumps" | Tighter input; ledge-walk-off deaths more common |
| `JUMP_BUFFER_S` | 0.083 s (5 frames) | 0.05 – 0.15 s | Bouncier feel; "why did I jump?" if buffer is too long | Frame-perfect-or-nothing landings; harder bounce combos |

**Referenced from Character Controller (not owned here):**
- `MAX_HSPEED` (CC default 120 px/s) — Movement passes `stick.x * MAX_HSPEED` as horizontal intent.
- `STATIONARY_THRESHOLD` (CC default 5 px/s) — read via `is_stationary()` for A-button gate.
- `JUMP_CUT_VELOCITY_PX_S` (CC default 200 px/s) — CC's clamp on the upward velocity post-`cancel_jump()`.
- `GRAVITY_PX_S2`, `TERMINAL_VELOCITY_PX_S` — CC-owned; influence Movement's perception of vertical dynamics.

**Interactions to watch:**

- `DODGE_IFRAME_DURATION_S` × `DODGE_TOTAL_DURATION_S`: i-frames must be ≤ total. If equal, there's no "recovery exposed window" — the dodge is fully safe end-to-end. If i-frames are much smaller than total, the player commits to a long lockout for a short defensive window — high risk/high read.
- `WALL_JUMP_COOLDOWN_MS` × `WALL_JUMP_HORIZONTAL_KICK`: if kick is large enough that the player can't re-touch the same wall before cooldown ends, cooldown is moot. Tune together.
- `COYOTE_TIME_S` × `JUMP_BUFFER_S`: typically set equal (symmetric pre/post tolerance). Asymmetric tuning is unusual — flag if requested.
- `DODGE_DASH_SPEED` × `DODGE_TOTAL_DURATION_S`: dash distance ≈ speed × i-frame portion of duration (walls intervene). Players perceive total dodge "range" as that product.
- `JUMP_STRENGTH` × `AIR_JUMP_STRENGTH`: rule of thumb — `AIR_JUMP_STRENGTH ≤ JUMP_STRENGTH`. Otherwise air-jump dominates ground-jump and players never jump from the ground.

**Not knobs**: physics tick rate (60 Hz fixed); collision layer indices (architectural); button mapping (locked to TowerFall parity per CouchInput); per-clan tuning overrides (forbidden by Pillar 2 *Fairness Is Sacred*).

**Concept doc update required**: `design/gdd/game-concept.md` Tuning Knobs row for `catch_input_mode` is now stale (currently "TBD, MVP blocker"). Resolved as: locked to **dodge-button auto-catch during i-frames**. Will be applied during the post-design step.

## Acceptance Criteria

### Functional — basic verbs

- [ ] Walk: `stick.x = ±1` results in CC's horizontal velocity ramping to `±MAX_HSPEED` within 2–3 frames
- [ ] Ground-jump: A-press while `is_on_floor` → `CC.apply_jump_impulse(JUMP_STRENGTH)`; peak upward velocity reached on the same tick
- [ ] Air-jump: A-press while airborne (after using initial jump) → second impulse; `air_jump_available` becomes `false`
- [ ] Air-jump does NOT trigger a second time without landing
- [ ] Wall-touch does NOT refresh `air_jump_available`
- [ ] Wall-slide engages automatically when `!is_on_floor && is_on_wall && velocity.y > 0`; caps vertical velocity at `WALL_SLIDE_MAX_FALL_SPEED`
- [ ] Wall-jump: `apply_jump_impulse(WALL_JUMP_VERTICAL_STRENGTH)` + `set_horizontal_intent(wall_normal.x * WALL_JUMP_HORIZONTAL_KICK)` (kick AWAY from wall)
- [ ] Wall-jump sets `wall_jump_cooldown_remaining`; second wall-jump blocked until cooldown expires
- [ ] Wall-jump does NOT consume `air_jump_available`
- [ ] Drop-through: down+A on a one-way platform → `CC.drop_through_request()`; player falls through within 1 tick

### A-button decision tree (Rule 4 priority verification)

- [ ] On a one-way platform, down+A → drop_through fires (precedes all other branches)
- [ ] During `is_dodging`, A-press is a no-op
- [ ] On wall + airborne + cooldown=0 + A → wall-jump (precedes dodge check)
- [ ] On floor + stationary + A → dodge (not jump)
- [ ] On floor + moving + A → ground-jump (not dodge)
- [ ] Within coyote window (just walked off ledge) + A → ground-jump
- [ ] In air with `air_jump_available` + A → air-jump
- [ ] In air with no jumps available + A → `jump_buffer_remaining` set; next landing fires ground-jump

### Dodge + catch

- [ ] Dodge with `stick.length() >= STICK_NEUTRAL_THRESHOLD` → dash in `stick.normalized()` direction at `DODGE_DASH_SPEED`
- [ ] Dodge with stick below threshold → dash in `Vector2(facing, 0)` at `DODGE_DASH_SPEED`
- [ ] `is_iframe_active` is true for `DODGE_IFRAME_DURATION_S` then false
- [ ] `is_dodging` is true for `DODGE_TOTAL_DURATION_S` then false; `DODGE_IFRAME_DURATION_S ≤ DODGE_TOTAL_DURATION_S` invariant holds
- [ ] Cannot re-trigger dodge during `is_dodging` (A-press ignored per Rule 4.2)

### Comfort features

- [ ] Coyote: A-press within `COYOTE_TIME_S` of ledge-walk-off triggers ground-jump
- [ ] Coyote does NOT trigger when `is_on_floor` transition was caused by a jump (intentional take-off, not a fall)
- [ ] Jump buffer: A-press ≤ `JUMP_BUFFER_S` before landing triggers ground-jump on the landing tick
- [ ] Jump-cut: A released while `velocity.y < 0` → `CC.cancel_jump()` called; CC's clamp applies (verified via CC's jump-cut test)

### Death + lifecycle

- [ ] On Combat kill signal: `is_dead = true`; all input handling and velocity intents suppressed on subsequent ticks
- [ ] Round Flow can safely free Movement+CC instances after kill-cam delay
- [ ] New round: fresh Movement instance starts with `is_dodging=false`, `is_iframe_active=false`, `is_dead=false`, `air_jump_available=true`, `coyote_remaining=0`, `jump_buffer_remaining=0`, `wall_jump_cooldown_remaining=0`, `facing=+1`

### Cross-system integration (verified at consumer side)

- [ ] Combat polls `Movement.is_iframe_active()` at shuriken-vs-player collision and correctly catches instead of kills (Combat-side integration test)
- [ ] Combat correctly deflects shuriken when `is_iframe_active() && stash_count == STASH_MAX` (Combat-side test for stash-full edge case)
- [ ] Visual FX correctly derives animation state from `Movement.is_dodging() + is_iframe_active() + is_dead() + facing + CC.velocity + CC.is_on_floor + CC.is_on_wall` (Visual FX-side test)
- [ ] Round Flow successfully instantiates Movement (as child of CC) at each Map spawn point (Round Flow-side test)

### Performance

- [ ] Movement per-tick logic completes within ≤0.3 ms per Movement instance
- [ ] 4 simultaneous Movement instances: ≤1.2 ms total Movement budget per frame
- [ ] No heap allocations per tick (input polling reuses `Vector2`; flags are primitives)

### Code hygiene

- [ ] All tuning knobs (Section G) exposed via a config Resource, not hardcoded
- [ ] No magic numbers for impulse strengths or timing windows
- [ ] No direct `InputEvent` reads in Movement (all input flows through CouchInput)
- [ ] All public queries (`is_dodging`, `is_iframe_active`, `is_dead`, `facing`) documented with their return-value contracts
- [ ] State-flag clear-on-respawn verified by unit test (no leakage across rounds)

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| CC GDD Rule 10 must add `set_vertical_velocity(v: float)` to the Movement command list (currently mentioned in Rule 6 but missing from Rule 10's API list). | CC GDD author / gameplay-programmer | Before Movement implementation begins | **Resolved 2026-05-17**: added to CC GDD Rule 10 during post-Movement-design step |
| `design/gdd/game-concept.md` Dependencies table row for Movement is stale — should include Character Controller (currently only lists Couch Input). | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: concept doc updated to include Character Controller (+ Visual FX as downstream) |
| `design/gdd/game-concept.md` Tuning Knobs row for `catch_input_mode` is stale — should reflect "dodge-button auto-catch during i-frames" resolution. | post-design step | This GDD's Phase 5c | **Resolved 2026-05-17**: concept doc updated to reflect dodge-button auto-catch resolution |
| CouchInput "A-button currently held" semantics: jump-cut (Rule 9) requires reading whether A is *currently held* (continuous query), but CouchInput's spec emits `primary_action_pressed` (discrete edge only). Verify CouchInput exposes a polling query like `is_primary_action_held(slot) -> bool` or document a Godot `Input.is_action_pressed(...)` equivalent. | gameplay-programmer | Before Movement implementation begins | Verify/add to CouchInput; document in CouchInput GDD |
| Wall-jump in corner (player touches two walls simultaneously): which `wall_normal` does CC return? CC GDD says "deterministic per Godot's physics" but doesn't specify the resolution rule. | technical investigation during implementation | Movement implementation | TBD — likely Godot returns the most recently-contacted normal or the one with the larger collision penetration |
| Combat-side contracts inherited from this GDD: (a) catch-and-add-to-stash when `Movement.is_iframe_active() && shuriken_hits_player`, capped at `STASH_MAX = 3`; (b) **deflection** physics when stash is full at catch time (Edge Case row 8). | Combat GDD author | Before Combat GDD approved | Forward contract — Combat GDD must honor |
| Death animation / kill-cam timing: how long does Movement+CC persist after Combat's kill signal before Round Flow frees them? | Round Flow GDD author + Visual FX GDD author | Before Round Flow + Visual FX GDDs approved | TBD |
| Initial tuning values (Section G) are placeholders informed by TowerFall heuristics. Real values require playtest iteration per Pillar 5 (*Game-Feel First*). The 5 highest-impact values to validate first: `DODGE_IFRAME_DURATION_S`, `DODGE_TOTAL_DURATION_S`, `DODGE_DASH_SPEED`, `WALL_JUMP_HORIZONTAL_KICK`, `WALL_SLIDE_MAX_FALL_SPEED`. | game-designer + Movement implementer | MVP playtest cycles | Defer to playtest |
| Drop-through alternative input (currently requires down-stick + A-press): some platformers allow down-stick-hold-only drop-through. Pros: less input. Cons: harder to disambiguate from "I want to crouch" intent (no crouch in v1). | game-designer | Post-MVP playtest if confusion observed | Defer; current design requires down+A |
