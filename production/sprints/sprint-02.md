# Sprint 2 — 2026-06-02 to 2026-06-06

> **Milestone**: [Milestone 01 — Production MVP](../milestones/milestone-01-production-mvp.md)
> **Capacity**: 1 week, full-time (~5 days) · solo
> **Status**: Planned
> **Follows**: [Sprint 1](sprint-01.md) (Foundation spine: GSM + Couch Input, 42 tests green)

## Sprint Goal
Finish the Foundation layer (Map, Character Controller) and land **core Movement** on top of it,
so a character **moves, jumps, and dodges in `src/`** — driven by Couch Input intent, using the
prototype's validated feel values. End the sprint with movement you can *feel*.

## Capacity
- Total days: 5 (full-time)
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T1 | **Social playtest** (2 humans) of the prototype; confirm the solo PROCEED and **pin tuned values** into a data-driven config | You | 0.5 | — (external: 2nd human + controller) | REPORT.md updated with multi-tester notes; final feel values recorded; if a value shifts, the production config uses the new one. Can run in parallel with T2/T3. |
| T2 | ✅ **DONE** — **Map** system: `MapResource`, screen-wrap math, registry + loader, validator, flat arena | You + `level-designer` | 1.0 | — | ✅ `src/core/map/*` (resource, screen_wrap, validator, registry, loader) + `src/gameplay/maps/flat_arena.tscn/.tres`; **12 GUT tests green**; 480×270 display set. **Deferred to Sprint 3** (needs Projectile physics): the trajectory-sweep recoverability sim — static checks (spawn count, metadata, designer assertion) ship now. |
| T3 | ✅ **DONE** — **Character Controller** framework: gravity, collision, ground/wall detection, `slot`, 32-bit layers, screen-wrap hook | You + `gameplay-programmer` | 1.25 | T2 | ✅ `src/core/player_character_body.gd` (CharacterBody2D subclass) + `character_controller_config.gd/.tres`; command API (intent/jump/cut/dodge/drop-through) + state queries; collision layers per GDD (Player/Wall/OneWay/Projectile); **14 GUT tests green** incl. an integration test landing a body on the flat arena. ADR-0001 guard clean. |
| T4 | ✅ **DONE** — **Movement core**: reconciled `movement.md` (air-jump CUT), then walk + single jump + jump-cut + dodge (i-frames) + coyote + jump-buffer on CC via intent; pinned prototype values | You + `gameplay-programmer` + `game-designer` | 1.5 | T3 | ✅ `src/gameplay/player_movement.gd` + `movement_config.gd/.tres`; CC config `.tres` pinned to prototype values (gravity 1400, hspeed 158.4, jump 480, dash 400). **13 GUT tests green** incl. i-frame window + no-double-jump + coyote + buffer. movement.md status → Approved w/ reconciliation block. ADR-0001 clean. *(Built without the T1 playtest, which is parked — prototype values used as the validated starting point.)* |

### Should Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T5 | **Movement — wall verbs**: wall-grab + wall-jump on CC | You + `gameplay-programmer` | 1.0 | T4 | Wall-grab slows the slide; wall-jump kicks off per GDD + prototype feel; covered by a movement test. |

### Nice to Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| T6 | **Movement — drop-through platforms + screen-wrap** polish | You + `gameplay-programmer` | stretch | T5 | Drop-through one-way platforms; screen-wrap matches the Map's wrap rules. |

## Carryover from Previous Sprint
None — Sprint 1 closed clean at its Must-Have boundary. (The deferred Couch Input clan-select state
machine is VS-tier and belongs to the future MatchSetup / Clan Cosmetics work, not a Sprint 1 carryover.)

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Movement feel doesn't survive the production rewrite (the core project risk) | Medium | High | Pin the prototype's exact values; the playtest (T1) gives the comparison baseline; dodge i-frame duration is *the* lever — unit-test it. |
| `movement.md` GDD diverges from prototype-validated changes (double-jump, dash cap, ground-reset) | High | Medium | T4 reconciles the GDD *before* implementing; single source of truth restored. |
| Map + CC + Movement is a lot for one week | Medium | Medium | Core verbs only are Must-Have; wall-jump (T5) is Should, drop-through (T6) is Nice. Prototype reference accelerates implementation. |
| Social playtest blocked (no 2nd human available) | Medium | Low | Proceed on the recorded solo PROCEED; flag the playtest as still-owed; it does not block CC/Map coding. |

## Dependencies on External Factors
- A 2nd human + controller for the T1 social playtest.
- Prototype `Combat`/`player.gd` values as the source for pinned production config.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] No S1 or S2 bugs in delivered features
- [ ] `movement.md` updated for the prototype-validated feel decisions
- [ ] ADR-0001 guard clean (`Input.*` only in `couch_input.gd`); GUT suite green
- [ ] Code reviewed and merged
