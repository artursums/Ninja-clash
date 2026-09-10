# Systems Index: Four Clans

> **Status**: Draft
> **Created**: 2026-05-17
> **Last Updated**: 2026-05-18 (post-Round Flow design — **8/13 systems Approved; MVP design path COMPLETE (8/8)**)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Four Clans is a small-scope 2D arena PvP (~3 months to v1) where the entire
product rests on the moment-to-moment feel of throw, dodge, retrieve, and kill.
The mechanical surface area is deliberately tight — 13 v1 systems total, with
no progression, no character abilities, no power-ups, and no online networking.

Two systems carry disproportionate weight: **Movement** (which owns the dodge
i-frame timing — the single most consequential balance lever per the concept
doc) and **Combat** (which owns the throw/hit/kill rules + retrieval economy).
These two systems are the game-feel make-or-break and warrant L-effort design
treatment.

The dependency graph is clean — Foundation → Core → Feature → Presentation/Meta
with no circular dependencies. The bottleneck systems (Map, Movement, Combat)
are correctly placed in the MVP tier and at the front of the design queue.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Game State Manager *(inferred)* | Foundation | MVP | Approved | [game-state-manager.md](game-state-manager.md) | — |
| 2 | Couch Input | Foundation | MVP | Approved | [couch-input.md](couch-input.md) | Game State Manager |
| 3 | Map | Foundation | MVP | Approved | [map.md](map.md) | — |
| 4 | Character Controller *(inferred)* | Foundation | MVP | Approved | [character-controller.md](character-controller.md) | Map |
| 5 | Movement | Core | MVP | Approved | [movement.md](movement.md) | Character Controller, Couch Input |
| 6 | Projectile *(inferred)* | Core | MVP | Approved | [projectile.md](projectile.md) | Map |
| 7 | Combat | Feature | MVP | Approved | [combat.md](combat.md) | Projectile, Movement, Couch Input, Character Controller |
| 8 | Round Flow | Feature | MVP | Approved | [round-flow.md](round-flow.md) | Game State Manager, Combat, Movement, Map, Couch Input, Character Controller |
| 9 | Clan Cosmetics *(inferred)* | Feature | Vertical Slice | Not Started | — | Character Controller |
| 10 | HUD *(inferred)* | Presentation | Vertical Slice | Not Started | — | Round Flow, Combat |
| 11 | Visual FX *(inferred)* | Presentation | Alpha | Not Started | — | Movement, Combat, Round Flow, Character Controller |
| 12 | Audio *(inferred)* | Presentation | Alpha | Not Started | — | Combat, Movement, Round Flow, Game State Manager |
| 13 | UI Flow *(inferred)* | Meta | Alpha | Not Started | — | Game State Manager, Couch Input, Map, Clan Cosmetics |

### Deferred (post-v1)

| System | Tier | Notes |
|---|---|---|
| Accessibility (deepening) | v1.x | v1 includes basics (colorblind-safe clan palettes, key remap, audio-cue redundancy). Full pass with accessibility-specialist deferred to v1.x. |
| Bot AI | v1.x | Per concept doc anti-pillar — not in v1. Needs at least a sketch before v1 architecture is locked to avoid coupling that excludes bots later. |
| Online Networking | v2+ | Per concept doc anti-pillar — not in v1. Address with one ADR on input/state separation to keep door open. |

---

## Categories

This game uses 5 categories. The template's Progression / Economy / Persistence /
Narrative categories are intentionally omitted — Four Clans has no progression,
no economy, no save-game data beyond settings, and no narrative.

| Category | Description | Systems |
|---|---|---|
| **Foundation** | Independent systems with no internal deps. Build first. | Game State Manager, Couch Input, Map, Character Controller |
| **Core** | Player-facing systems that plug into Foundation. | Movement, Projectile |
| **Feature** | Game-defining systems built on Core. | Combat, Round Flow, Clan Cosmetics |
| **Presentation** | UI, VFX, audio that wrap gameplay. | HUD, Visual FX, Audio |
| **Meta** | Cross-cutting orchestration. | UI Flow |

---

## Priority Tiers

Distribution: **8 MVP · 2 Vertical Slice · 3 Alpha · 3 deferred**

| Tier | Definition | Target Milestone | Systems |
|---|---|---|---|
| **MVP** | Required for the core loop to function — without these, you can't test "is this fun?" | First playable prototype (~2-3 weeks) | Game State Manager, Couch Input, Map, Character Controller, Movement, Projectile, Combat, Round Flow |
| **Vertical Slice** | Required for one complete, polished experience. | Vertical slice (~3-4 weeks cumulative) | Clan Cosmetics, HUD |
| **Alpha** | Complete mechanical scope; placeholder content OK. | Alpha milestone (~4-6 weeks cumulative) | Visual FX, Audio, UI Flow |
| **v1 Launch** | Polish, content-complete. | v1 release (~10-14 weeks cumulative) | — (all systems exist by Alpha; v1 Launch is polish, not new systems) |

---

## Dependency Map

Systems sorted by dependency layer. Design and build top-to-bottom. Systems
within the same layer can be designed in parallel.

### Foundation Layer (no dependencies)

1. **Game State Manager** — top-level state machine (Boot → MainMenu → MatchSetup → InMatch → MatchEnd); everything plugs into a state
2. **Couch Input** — raw input source; depends on Game State Manager (subscribes to `state_changed` to switch input layer; emits `pause_requested` GSM consumes). Within-layer dep — design GSM first.
3. **Map** — geometry/data; defines the world all gameplay sits in
4. **Character Controller** — physics framework (gravity, collision, ground/wall detection); generic — Movement plugs in. Depends on Map (queries collision geometry, screen-wrap rules). Within-layer dep — design Map first.

### Core Layer (depends on Foundation)

5. **Movement** — depends on: Character Controller, Couch Input
6. **Projectile** — depends on: Map (collision geometry for stick/recover)

### Feature Layer (depends on Core)

7. **Combat** — depends on: Projectile (hit detection + instantiation), Movement (i-frame interaction + set_dead), Couch Input (`throw_pressed` signal), Character Controller (reads `position` + `slot`). *(updated 2026-05-17 during Combat GDD design — Map removed; Combat reads no Map data directly, only indirect via Projectile + CC)*
8. **Round Flow** — depends on: Game State Manager, Combat (kill events), Movement (death trigger), Map (spawn points), Couch Input (`controller_disconnected` for mid-round elimination), Character Controller (instantiates `PlayerCharacterBody` at round start)
9. **Clan Cosmetics** — depends on: Character Controller (visual layer)

### Presentation Layer (depends on Feature)

10. **HUD** — depends on: Round Flow (scoreboard), Combat (kill feed, shuriken count)
11. **Visual FX** — depends on: Movement (animation states), Combat (hit-stop trigger), Round Flow (death anim), Character Controller (reads `velocity` + `is_on_floor` for animation state inputs)
12. **Audio** — depends on: Combat (events), Movement (events), Round Flow (events), Game State Manager (subscribes to `state_changed` for music swaps)

### Meta Layer (cross-cutting orchestration)

13. **UI Flow** — depends on: Game State Manager, Couch Input (navigation), Map (selection), Clan Cosmetics (selection preview)

---

## Recommended Design Order

Combining dependency layer + priority tier. Systems within the same row-group
can be designed in parallel; the suggested sequence below is the order
recommended for solo work, because each design informs the next.

| Order | System | Priority | Layer | Suggested Discipline(s) | Est. Effort |
|---|---|---|---|---|---|
| 1 | Game State Manager | MVP | Foundation | game-designer + technical-director | M |
| 2 | Couch Input | MVP | Foundation | systems-designer + godot-specialist | M |
| 3 | Map | MVP | Foundation | level-designer + game-designer | M |
| 4 | Character Controller | MVP | Foundation | gameplay-programmer + game-designer | M |
| 5 | **Movement** ← hot-zone | MVP | Core | game-designer + systems-designer + gameplay-programmer | **L** |
| 6 | Projectile | MVP | Core | systems-designer + gameplay-programmer | M |
| 7 | **Combat** ← hot-zone | MVP | Feature | game-designer + systems-designer | **L** |
| 8 | Round Flow | MVP | Feature | systems-designer + game-designer | M |
| 9 | Clan Cosmetics | VS | Feature | art-director + game-designer | S |
| 10 | HUD | VS | Presentation | ux-designer + ui-programmer | M |
| 11 | Visual FX | Alpha | Presentation | technical-artist + sound-designer | M |
| 12 | Audio | Alpha | Presentation | audio-director + sound-designer | M |
| 13 | UI Flow | Alpha | Meta | ux-designer + ui-programmer | L |

**Effort estimates:** S = 1 session · M = 2-3 sessions · L = 4+ sessions. A session is one focused design conversation producing a complete GDD.

**Total**: ~30-35 design sessions. MVP-only: ~17-20 sessions.

---

## Circular Dependencies

**None found.** The graph is strictly Foundation → Core → Feature → Presentation/Meta with no back-edges. The Meta-tier UI Flow depends on Feature-tier Clan Cosmetics (preview during clan-select), which is allowed because Meta is permitted to depend across layers.

---

## High-Risk Systems

These warrant prototype-driven validation early, regardless of priority tier.
Movement and Combat are flagged in the concept doc as the make-or-break for
the entire product; Couch Input and Projectile carry technical risk specific
to Godot 4.6 + the retrievable-projectile mechanic.

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| **Movement** | Design | Dodge i-frame timing is the single most consequential balance lever per the concept doc. Too generous = stalemates; too tight = lucky kills feel unearned. | Prototype-first; test multiple i-frame durations (100/200/300 ms) with playtesters in MVP. |
| **Combat** | Design + Balance | 4-player + 3-shuriken stash chaos: opening 5 seconds could become a retrieval scramble. | Prototype 4-player playtests early in Vertical Slice; tune `pickup_radius_px`, `shuriken_wall_stick_duration_s`. |
| **Couch Input** | Technical | 4-controller hot-plug + clan-select UX is non-trivial in Godot 4.6. | Validate in MVP with 2-controller; expand to 4 in Vertical Slice. Reference the official Godot 4.6 `Input` documentation. |
| **Projectile** | Technical | Wall-stick + 100%-recoverability requirement (per concept Edge Cases) is novel to the team. | Prototype shuriken physics in MVP alongside placeholder map; validate "no shuriken can become unrecoverable" via automated test. |

---

## Progress Tracker

| Metric | Count |
|---|---|
| Total v1 systems identified | 13 |
| Deferred systems (post-v1) | 3 |
| Design docs started | 8 |
| Design docs reviewed | 8 |
| Design docs approved | 8 |
| MVP systems designed | **8 / 8 — COMPLETE** |
| Foundation tier | **4 / 4 — COMPLETE** |
| Core tier | **2 / 2 — COMPLETE** |
| Feature tier | **2 / 3 — Combat + Round Flow done; Clan Cosmetics (VS-tier) remains** |
| Vertical Slice systems designed | 0 / 2 |
| Alpha systems designed | 0 / 3 |

---

## Next Steps

- [ ] Approve this systems index
- [ ] Write the MVP system GDDs in the order above, starting with Game State Manager
- [ ] Review each system GDD against the design-doc standards before marking it approved
- [ ] Update this index's Status column as each system progresses (Not Started → In Design → In Review → Approved)
- [ ] Re-check pre-production readiness once all MVP systems are designed
- [ ] Prototype the highest-risk systems early — movement and combat, once those two GDDs are drafted
- [ ] Write a single ADR on input/state separation to keep online (v2+) viable
