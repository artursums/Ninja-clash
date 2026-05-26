# ADR-0001: Input / State Separation

## Status

Accepted (2026-05-26)

## Date

2026-05-26

## Decision Makers

`technical-director`, project owner. Informed by the Couch Input GDD
(`design/gdd/couch-input.md`) and game-concept risk *"Online-deferral
architectural debt"* (`design/gdd/game-concept.md`).

## Context

### Problem Statement

Four Clans is local-couch-only in v1, but the concept doc explicitly wants online
multiplayer kept viable for v2+ *without* implementing it now: *"Architecture should
not preclude future P2P or client-server but should not implement it either. Single
ADR will cover input/state separation."* The corresponding technical risk: *"today's
input/state code shouldn't bake in local-only assumptions."*

This decision must be made **before** the first gameplay systems (Game State Manager,
Couch Input, Movement, Combat) are implemented in `src/`, because retrofitting an
input boundary after Movement and Combat read devices directly is a costly rewrite —
exactly the trap the throwaway prototype fell into (see Current State).

### Current State

The throwaway prototype (`prototypes/movement-and-combat/player.gd`) reads the device
directly inside the physics step, e.g. `Input.is_action_pressed(input_left)` and
`Input.is_action_just_pressed(input_katana)` scattered through `_physics_process`.
This is fine for a feel prototype but is **disqualifying for production**:

- It couples every gameplay system to the local `Input` singleton and to physical devices.
- It cannot be driven from a network source (precludes online).
- It cannot be unit-tested without a live device or faking the global `Input` state.

Production must not carry this pattern over.

### Constraints

- **Engine**: Godot 4.6, GDScript. Simulation runs in `_physics_process` (fixed tick).
- **Timeline**: v1 is local-only; netcode is explicitly *out of scope* — this ADR adds
  a boundary, not a network layer.
- **Resource**: solo developer; the boundary must be cheap to maintain, not a framework.
- **Compatibility**: must match the already-approved Couch Input GDD (CouchInput autoload
  is the sole `InputEvent` owner; emits typed per-slot intent signals; Movement resolves
  the contextual jump-vs-dodge semantic).

### Requirements

- Gameplay systems mutate simulation state **only** from player *intent*, never from
  direct device reads.
- Intent is addressed by **player slot** (`1..4`), not by device id.
- A frame of intent is representable as **plain, serializable data** so a future network
  layer can substitute as an intent source with zero changes to gameplay systems.
- Input is **testable** without a live device (inject intent directly).
- No measurable runtime cost versus direct reads (this is a couch game on a 16.6 ms budget).

## Decision

**All gameplay state mutation is driven by per-slot player intent. `CouchInput` is the
sole producer of intent (from local devices in v1). Intent is keyed by slot and is plain
serializable data, so a future `NetworkInput` source can be substituted without changing
any gameplay system. No gameplay/Movement/Combat code reads Godot `Input` / `InputEvent`
directly.**

This is a *boundary*, not netcode. v1 implements only the local producer.

### Architecture

```
   [ Local devices ]                         [ (v2+) Network packets ]
      InputEvent stream                             intent bytes
            │                                             │
            ▼                                             ▼
   ┌────────────────────┐                       ┌─────────────────────┐
   │  CouchInput (v1)    │  ← only source in v1  │  NetworkInput (v2+) │
   │  raw → PlayerIntent │                       │  bytes → PlayerIntent│
   └─────────┬──────────┘                       └──────────┬──────────┘
             │        PlayerIntent  (per slot, per tick — plain data)
             ▼
   ┌──────────────────────────────────────────────────────────┐
   │  Gameplay systems  (Movement, Combat, Round Flow, …)       │
   │  • read intent BY SLOT (polled snapshot + typed signals)   │
   │  • mutate simulation state                                 │
   │  • NEVER call Input.* / InputEvent directly                │
   └──────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# Per-slot, per-tick player intent — plain value data, no device references.
# v1: produced from local devices by CouchInput. v2+: a NetworkInput layer can
# produce the identical struct from remote packets without touching gameplay.
class_name PlayerIntent
extends RefCounted

var move: Vector2          # movement axis, deadzoned, components in [-1, 1]
var aim: Vector2           # throw-aim octant intent
var primary_pressed: bool  # A (bottom face) — Movement resolves jump-vs-dodge
var primary_held: bool
var throw_pressed: bool
var throw_held: bool
var katana_pressed: bool
# ...all fields are value types → trivially serializable for v2+ networking.

# CouchInput autoload — the ONLY system that touches Godot Input / InputEvent.
# Exposes BOTH (per the Couch Input GDD + this ADR):
#   1. typed signals for discrete/responsive verbs:  throw_pressed(slot), etc.
#   2. a per-slot polled snapshot for per-tick simulation reads:
func get_intent(slot: int) -> PlayerIntent     # current tick's intent for a slot
```

**Binding rule for all gameplay code:** read `CouchInput.get_intent(slot)` (and/or
connect to CouchInput's typed signals) inside `_physics_process`; resolve any contextual
semantics (e.g. jump-vs-dodge) in the *consuming* system (Movement), per the Couch Input
GDD. A call to `Input.*` or a handled `InputEvent` anywhere outside `CouchInput` (and UI
focus navigation) is an architecture violation.

### Implementation Guidelines

- Sample intent once per physics tick; gameplay reads the snapshot so the simulation
  step has a single, consistent input frame (deterministic-friendly, and the natural unit
  a future netcode layer would replicate).
- Signals remain for responsive UI / discrete edges; the **simulation** reads the snapshot.
- Keep `PlayerIntent` free of engine-event types and device ids — value types only.
- Tests inject a `PlayerIntent` (or a stub `CouchInput`) directly — no device needed.
- A simple CI/grep guard: `grep -rn "Input\.\|InputEvent" src/` should match only
  `src/.../couch_input*` (and UI navigation), enforced at code review.

## Alternatives Considered

### Alternative 1: Direct device reads in each system (the prototype approach)

- **Description**: Each system calls `Input.is_action_pressed(...)` itself.
- **Pros**: Fastest to write; zero indirection; fine for a throwaway prototype.
- **Cons**: Couples gameplay to local devices; precludes online; not unit-testable.
- **Estimated Effort**: Lowest now, highest later (full rewrite to add online/tests).
- **Rejection Reason**: Directly violates the concept's online-viability requirement and
  the project's "DI over singletons / unit-testable" coding standard.

### Alternative 2: Typed signals only (no polled snapshot)

- **Description**: CouchInput emits signals; systems react to them; no per-tick snapshot.
- **Pros**: Event-driven, responsive, already half-specified in the Couch Input GDD.
- **Cons**: Signals fire at arbitrary times, not as a single per-tick input frame — awkward
  for a future lockstep/rollback netcode and for deterministic replay/tests. Continuous
  state (movement held) still needs polling anyway.
- **Estimated Effort**: Similar to chosen.
- **Rejection Reason**: Partial — keeps signals (good for UI/discrete) but adds the polled
  snapshot the simulation reads, which the chosen approach does.

### Alternative 3: Full netcode abstraction now (command queue + rollback)

- **Description**: Build the input-as-command, replication, and rollback layer up front.
- **Pros**: Online would "just work" later.
- **Cons**: Massive over-engineering for a local-only v1; burns the budget the concept
  says to protect.
- **Rejection Reason**: Concept explicitly says *do not implement* networking in v1.

## Consequences

### Positive

- Online (v2+) stays viable: swap/add an intent producer, gameplay untouched.
- Gameplay systems become unit-testable by injecting `PlayerIntent` — satisfies the
  "all public methods unit-testable / DI over singletons" coding standard.
- Single, consistent per-tick input frame → deterministic-friendly simulation and replay.
- Clean separation matches the already-approved Couch Input GDD.

### Negative

- One layer of indirection between device and gameplay (negligible cost, slight ceremony).
- Discipline required: a tempting `Input.is_action_pressed` in a gameplay script must be
  caught in review (mitigated by the grep guard).

### Neutral

- CouchInput exposes both signals and a polled snapshot — slightly larger surface, but each
  serves a clear consumer (UI/discrete vs simulation).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Devs reintroduce direct `Input.*` reads in gameplay | Medium | Medium | Grep guard in CI + code-review gate; this ADR linked from Movement/Combat tasks |
| Per-tick snapshot adds input latency vs immediate reads | Low | Low | Sample at the start of the physics tick; same frame the sim already runs on |
| Over-abstraction creep toward premature netcode | Low | Medium | ADR scope is the boundary only; netcode explicitly deferred to a future ADR |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | direct reads | +~negligible (a few field copies / slot / tick) | 16.6 ms total |
| Memory | — | ~1 small `PlayerIntent` per active slot (≤4) | < 1 GB |
| Network (v1) | n/a | n/a (no netcode in v1) | n/a |

## Migration Plan

This is greenfield for `src/` — there is nothing to migrate (the prototype is frozen and
not carried over). The plan is forward-looking:

1. **T5 (Couch Input)**: implement `CouchInput` autoload as the sole `Input`/`InputEvent`
   owner; expose typed signals (per GDD) + `get_intent(slot) -> PlayerIntent`.
2. **T7/Movement**: Character Controller + Movement read intent only; no `Input.*`.
3. **Combat / Round Flow**: same — intent only.
4. Add the `grep` guard to the test/CI step so a violation fails fast.

**Rollback plan**: If the snapshot proves awkward, fall back to signals-only (Alternative 2)
for v1 — gameplay still never reads devices directly, so online viability is preserved either
way. The binding "no direct `Input.*` in gameplay" rule is the part that must not be rolled back.

## Validation Criteria

- [ ] `grep -rn "Input\.\|InputEvent" src/` matches only the CouchInput module (+ UI nav)
- [ ] A Movement unit test drives a character by injecting `PlayerIntent`, with no live device
- [ ] `CouchInput.get_intent(slot)` returns a plain, serializable value (no engine-event refs)
- [ ] Removing all local devices and feeding synthetic intent still steps the simulation
      identically (proves the producer is swappable) — a v2 readiness check, runnable in v1 via a test stub

## Related

- `design/gdd/couch-input.md` — CouchInput interface, signals, slot model (this ADR makes its
  separation principle binding architecture-wide)
- `design/gdd/movement.md` — consumes intent; owns jump-vs-dodge resolution
- `design/gdd/game-concept.md` — risk "Online-deferral architectural debt"; networking deferral
- `production/sprints/sprint-01.md` — T3 (this ADR), T5 (Couch Input), T7 (Character Controller)
- `prototypes/movement-and-combat/player.gd` — the anti-pattern this ADR forbids in production
