# ADR-0002: Adopt the Prototype as the Production Base

## Status

Accepted (2026-05-26)

## Date

2026-05-26

## Decision Makers

Project owner + assistant. Supersedes the from-scratch-rewrite strategy implied by
Milestone 01 and Sprints 1–2.

## Context

### Problem Statement

The `prototypes/movement-and-combat` prototype was built to validate one question — "is the
throw–dodge–retrieve loop fun?" — but it grew far past that into a **nearly-complete, playable
game** (~3,900 lines, 16 scripts): title, mode/clan/map select, 2–4 players, bots, combat,
shuriken, katana, HUD, FX, generated pixel-art, and a synthesized-audio system. The owner has
played whole matches from it.

The project's original plan (`.claude/rules/prototype-code.md` + Milestone 01) treated the
prototype as **throwaway** and mandated a clean **from-scratch rewrite in `src/`**. We executed
two sprints of that rewrite (Game State Manager, Couch Input, Map, Character Controller,
Movement — 81 GUT tests). It became clear we were **re-implementing working, validated prototype
functionality**, at significant cost, while a fun playable game sat unused.

### Constraints

- Solo developer; time is the scarcest resource.
- The prototype is prototype-grade in places (hardcoded tuning, no tests, input read directly in
  `player.gd`) — but it is reasonably typed and organised, not a disaster.
- Online multiplayer is a **v2 goal** (per game-concept) — the architecture must not preclude it.

## Decision

**Adopt the prototype as the production base (renamed `ninja_clash`), and harden it incrementally
to production quality — rather than rewrite from scratch.** Keep the validated feel and all working
features; invest effort in the gaps (tests, data-driven config, online-viable input, content,
store-readiness) instead of re-building what already works.

Online (v2) remains a goal, so the **input/state-separation pattern from ADR-0001 is brought into
`ninja_clash`** as the first hardening step (done: `PlayerInput` router + `PlayerIntent`).

### What changes

- The from-scratch `src/` rewrite (GSM, Couch Input, Map, Character Controller, Movement + tests)
  is **archived to `archive/src-rewrite/`** as reference. We do **not** run a parallel rewrite.
- The **GDDs (`design/gdd/`), ADR-0001, and the clean patterns** from the rewrite remain the
  **guide** for hardening — we know what "right" looks like; we apply it to the prototype.
- `ninja_clash` is the single Godot project; GUT is installed there for hardening tests.

## Alternatives Considered

### Alternative 1: Continue the from-scratch rewrite in `src/`

- **Pros**: cleanest possible codebase; textbook discipline.
- **Cons**: re-implements a working, validated game; slowest path to shipping; the prototype's
  playable completeness is wasted.
- **Rejection reason**: poor ROI for a solo dev who already has a fun, playable game.

### Alternative 2: Ship the prototype as-is (no hardening)

- **Pros**: fastest to a build.
- **Cons**: prototype-grade code (no tests, hardcoded tuning, device-coupled input) is risky to
  maintain/expand and blocks online; placeholder audio + no store-readiness.
- **Rejection reason**: owner chose "build properly, long-term" — quality + online matter.

## Consequences

### Positive

- Keeps the validated feel and all working features; fastest *quality* path to shippable.
- Effort goes to real gaps (tests, config, online input, content, store) not re-building.

### Negative

- We accept prototype-grade code as the starting point and must harden it deliberately
  (otherwise tech debt compounds). The rewrite's two sprints are partly sunk cost (mitigated:
  they produced the ADR-0001 pattern + tested reference we now reuse).

### Neutral

- `src/` rewrite lives in `archive/` as reference; the repo root no longer has a stray project.

## Validation Criteria

- [ ] `ninja_clash` is the sole Godot project and boots/plays unchanged after each hardening step.
- [ ] Hardening reaches: data-driven tuning, GUT tests on core feel/combat math, online-viable
      input (✅ done), store-readiness — without regressing the playable game.
- [x] Input/state separation in `ninja_clash` (sim reads `PlayerInput` intent, not the device).

## Related

- `docs/architecture/ADR-0001-input-state-separation.md` — the pattern now applied to `ninja_clash`
- `archive/src-rewrite/` — the archived from-scratch rewrite (reference)
- `production/milestones/milestone-01-production-mvp.md` — re-scoped per this ADR
- `production/sprints/sprint-01.md`, `sprint-02.md` — the rewrite sprints (now superseded/historical)
- `design/gdd/` — GDDs remain the design spec + hardening guide
