# Sprint 1 — 2026-05-26 to 2026-05-30

> ⚠️ **SUPERSEDED (2026-05-26) — historical record.** This sprint built the from-scratch `src/`
> rewrite (Game State Manager, Couch Input). Per [ADR-0002](../../docs/architecture/ADR-0002-prototype-as-production-base.md)
> we adopted the prototype (`ninja_clash`) as the production base instead; this rewrite is archived
> in `archive/src-rewrite/`. Its value lives on as the ADR-0001 pattern + tested reference now
> reused for hardening. Kept here for history; not the active plan.

> **Milestone**: [Milestone 01 — Production MVP](../milestones/milestone-01-production-mvp.md)
> **Capacity**: 1 week, full-time (~5 days) · solo
> **Status**: Planned

## Sprint Goal
Transition from prototype to production: stand up the `src/` project with a test
harness, lock the input/state architecture, and build the dependency-free
**Foundation** systems (Game State Manager, Couch Input) to approved-GDD spec with
passing tests — the base every other system plugs into.

## Capacity
- Total days: 5 (full-time)
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T1 | ✅ **DONE** — Record playtest result in prototype `REPORT.md`; confirm **PROCEED** | You | 0.25 | — | ✅ REPORT.md filled; decision = **PROCEED** (developer-confidence, 2026-05-26) |
| T2 | ✅ **DONE** — Production scaffold: `src/` layout, GUT addon + green smoke test, root `project.godot`, prototype shielded via `.gdignore` | You + `godot-specialist` | 0.75 | T1 | ✅ `src/` has core/gameplay/ai/networking/ui/tools; GUT 9.6.0 runs **2/2 passing** headless on Godot 4.6.2; prototype untouched. *(Autoload stubs deferred to T4 where the real GSM lands.)* |
| T3 | ✅ **DONE** — **ADR-0001**: input/state separation (keeps online v2 viable; enables testable input) | You + `technical-director` | 0.5 | — | ✅ `docs/architecture/ADR-0001-input-state-separation.md` (Accepted 2026-05-26); intent-as-data boundary + grep guard |
| T4 | ✅ **DONE** — **Game State Manager** to GDD (7 states, full transition table) + GUT tests | You + `godot-gdscript-specialist` | 1.0 | T2, T3 | ✅ `src/core/game_state_manager.gd` (+ `match_context.gd`, `game_state_config.gd/.tres`); **19 GUT tests green** covering all transitions, signal order, pause+debounce, auto-pause, Settings return, MatchContext lifecycle; `GameState` autoload registered; ADR-0001 guard clean |
| T5 | ✅ **DONE** — **Couch Input** core: sole Input owner, slot assignment + hot-plug, layer switching, per-slot intent + signals | You + `godot-specialist` | 1.5 | T2, T3, T4 | ✅ `src/core/couch_input.gd` (+ `player_intent.gd`, `couch_input_config.gd/.tres`); **21 GUT tests green** (join/4-cap, disconnect→reserve→reclaim, layer gating, throw/primary/pause signals, deadzone+clamp, move intent, menu-nav debounce); `CouchInput` autoload; ADR-0001 guard: CouchInput is the only Input owner. **Deferred** (clan/UI-coupled, VS tier): MatchSetup clan Browsing/Locked/Ready + forced uniqueness + menu hold-to-repeat. |

### Should Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T6 | **Map**: `MapResource` + one flat production test map + recoverability validator | You + `level-designer` | 1.0 | T2 | Map loads from resource; validator proves no shuriken can become unrecoverable (automated test) |
| T7 | **Character Controller** framework: gravity/collision/ground-wall detection, `slot` field, 32-bit collision layers | You + `gameplay-programmer` | 1.0 | T2, T6 | CC spawns on map, detects floor/wall; generic (Movement plugs in later); tests for ground/wall detection |

### Nice to Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T8 | Begin **Movement** port: walk + single-jump on CC (no dodge/wall yet) | You + `gameplay-programmer` | stretch | T7 | A character walks + jumps in `src/` driven by Couch Input |

## Carryover from Previous Sprint
None — this is Sprint 1.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Production-quality rewrite (typed/DI/tested) is slower than prototype hacking | High | Medium | Foundation-only scope; Map/CC are Should-Have, not Must; lean on prototype as reference |
| Couch Input controller hot-plug is non-trivial in Godot 4.6 (flagged technical risk) | Medium | Medium | 1.5d budget; reference `docs/engine-reference/godot/`; validate 2-controller before 4 |
| Playtest gate not formally closed → may be PIVOT not PROCEED | Medium | High | T1 first; if PIVOT, stop and re-plan before building |
| GUT addon incompatible with Godot 4.6 | Low | Medium | Verify in T2 smoke test before anything depends on it |

## Dependencies on External Factors
- GUT (Godot Unit Test) addon compatible with Godot 4.6
- A 2nd human + controller for the real (social) playtest behind T1

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations discovered during implementation
- [ ] Code reviewed and merged; GUT tests green in headless

## Notes
- **T1 gates the rest.** The playtest PROCEED/PIVOT/KILL decision was not recorded
  before this plan; if it turns out PIVOT, stop and re-plan rather than building on an
  unvalidated loop.
- **Movement & Combat are deliberately not in this sprint.** They are the L-effort,
  feel-critical "hot zone" systems and each deserves a focused sprint, with the
  prototype's tuned values pinned as the starting point.
- The prototype (`prototypes/movement-and-combat/`) stays **frozen as reference**.
  Production is a rewrite to standards, not a copy (see `.claude/rules/prototype-code.md`).
- **Deferred:** the L2/J defense mechanic prototyped this cycle is held out of v1 until
  validated (off-GDD; pushes on the purist anti-pillars).
