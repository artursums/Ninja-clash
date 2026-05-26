# Milestone 01 — Production MVP

> **Status**: In Progress (Sprint 1 active)
> **Created**: 2026-05-26
> **Source**: design/gdd/systems-index.md (MVP tier — 8 systems)

## Goal
Re-implement the 8 approved MVP systems to production standards in `src/` and
integrate them into a complete, playable first-to-N couch match — the production
equivalent of what the throwaway prototype validated. This is the point at which
"the game exists in `src/`," not just in a prototype.

## Scope — the 8 MVP systems
Build order follows the dependency graph in `systems-index.md`:

| Layer | Systems | GDD |
|-------|---------|-----|
| Foundation | Game State Manager, Couch Input, Map, Character Controller | approved |
| Core | Movement, Projectile | approved |
| Feature | Combat, Round Flow | approved |

Vertical-Slice/Alpha systems (Clan Cosmetics, HUD, VFX, Audio, UI Flow) are **out
of scope** for this milestone — they belong to later milestones.

## Out of Scope (anti-pillars / deferred)
- Bot AI (v1.x — concept anti-pillar; the prototype's bot does **not** carry over)
- Online networking (v2+ — addressed only by the input/state-separation ADR)
- L2/J defense mechanic (deferred until validated; off-GDD)
- Any progression, abilities, power-ups, or meta systems

## Exit Criteria
- [ ] All 8 MVP systems implemented in `src/` and pass their GDD acceptance criteria
- [ ] A full 2-player match is playable end-to-end **from `src/`** (not the prototype):
      menu → match setup → rounds → match end
- [ ] GUT test suites green in headless for every system (balance formulas, slot logic,
      projectile recoverability, round flow)
- [ ] 60 fps locked during 2-player play; < 1 GB RAM (per technical-preferences.md budgets)
- [ ] Projectile recoverability validator passes (no shuriken can become unrecoverable)
- [ ] Prototype tuning values (dodge i-frames, throw velocity, pickup radius, etc.)
      pinned into data-driven config, sourced from the playtest

## Sprints laddering up to this milestone
| Sprint | Focus | Systems |
|--------|-------|---------|
| [Sprint 1](../sprints/sprint-01.md) | Scaffold + architecture + Foundation base | Project setup, ADR-0001, Game State Manager, Couch Input (+ Map, Character Controller as Should-Have) |
| Sprint 2 (planned) | Core feel — the hot zone | Character Controller (finish), Movement, Projectile |
| Sprint 3 (planned) | The game | Combat, Round Flow → first full `src/` match |

Rough estimate: ~3–4 one-week full-time sprints to a complete Production MVP,
assuming PROCEED from the playtest gate.

## Risks
- The two feel-critical systems (Movement, Combat) carry the most design risk; the
  prototype de-risked them, so production must **pin the prototype's tuned values**
  rather than re-discovering them.
- Solo production-quality velocity is unproven — Sprint 1 establishes the real
  build pace; re-estimate Sprints 2–3 after it closes.
