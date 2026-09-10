# Sprint 3 — Ninja Clash Hardening

> **Milestone**: [Milestone 01 — Ninja Clash v1](milestone-01-production-mvp.md)
> **Strategy**: [ADR-0002](../../docs/architecture/ADR-0002-prototype-as-production-base.md) — prototype is the production base
> **Capacity**: 1 week, full-time (~5 days) · solo · **Status**: Active
> **Project**: `ninja_clash/`

## Sprint Goal
Harden the validated `ninja_clash` base into maintainable, online-viable production code — finish
the quality foundation (online-safe input ✅, data-driven tuning, tests on the core math) **without
regressing the playable game**. This is Work Stream 1 (Hardening) of the milestone.

## Capacity
- Total days: 5 (full-time) · Buffer (20%): 1 day · Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T1 | ✅ **DONE** — **Input/state separation**: `PlayerInput` router as sole sim Input reader; per-tick `PlayerIntent`; `player.gd` reads the snapshot (ADR-0001 pattern, online-viable) | You | 1.0 | — | ✅ `player_input_router.gd` + `player_intent.gd`; `player.gd` `_held`/`_pressed` route through `PlayerInput`; 5 GUT tests; game plays unchanged (commit 57e8551) |
| T2 | ✅ **DONE** — **Data-driven tuning**: player.gd tuning consts → `PlayerTuning` resource (`player_tuning.gd/.tres`), applied in `_ready` | You + `game-designer` | 1.5 | — | ✅ No balance values hardcoded in logic; editable in `player_tuning.tres`, injectable in tests; parse/boot clean; behaviour unchanged (defaults == validated values). Commit 364d4cf |
| T3 | ✅ **DONE (scoped)** — **GUT tests on testable core**: combat scoring + tuning-value integrity + katana-window invariant | You + `qa-tester` | 1.5 | T2 | ✅ 14 GUT tests green in `ninja_clash` (combat 5 + player_input 5 + tuning 4). **Note:** deeper physics/feel tests (shuriken trajectory, in-context dodge i-frames) need the real-scene+autoloads integration approach — the prototype's node-coupled classes block pure unit tests; tracked as a follow-up. |

### Should Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T4 | Route **menu input** (clan/map/mode/match-end select) through `PlayerInput` too — finish the single-Input-owner picture | You | 1.0 | T1 | No menu script reads `Input.*` directly; menus behave unchanged |

### Nice to Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T5 | Shuriken **recoverability validator** test (the trajectory-sweep deferred from the rewrite's Map work) against the prototype's maps | You | stretch | T3 | Automated test proves no shuriken can become unrecoverable on shipped maps |

## Carryover
None as tasks — but note T1 (input/state separation) was completed ahead of this plan during the
pivot; it is recorded here as the sprint's first Must-Have.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Hardening regresses the playable game | Medium | High | Change in small steps; boot + GUT after each; launch to confirm feel; the game is the source of truth |
| Config extraction changes feel (value drift) | Medium | Medium | Pin the exact current prototype numbers; a feel diff = a bug, not a tuning choice |
| Prototype's core math is entangled (hard to unit-test) | Medium | Medium | Test via the same DI/stub approach used in the rewrite; refactor seams only where needed |

## Dependencies on External Factors
- None (hardening is all code/tests). Audio/art/store assets are later streams (owner-sourced).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed; game plays unchanged (verified by launch)
- [ ] No balance values hardcoded in gameplay logic
- [ ] Core feel/combat math covered by green GUT tests
- [ ] No S1/S2 bugs introduced
