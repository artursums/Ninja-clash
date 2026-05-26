# Sprint 1 Retrospective — 2026-05-26

> Sprint: [Sprint 1](sprint-01.md) · Milestone: [Production MVP](../milestones/milestone-01-production-mvp.md)
> Closed at the Must-Have boundary (deliberate — clean checkpoint over momentum).

## Outcome

| Tier | Planned | Delivered |
|------|---------|-----------|
| Must-Have | 5 (T1–T5) | **5 / 5 ✅** |
| Should-Have | 2 (T6 Map, T7 Character Controller) | 0 (not attempted — sprint closed at the Must-Have boundary) |
| Stretch | 1 (T8 Movement port) | 0 |

**Delivered:** PROCEED recorded · production project + GUT harness · ADR-0001 (input/state separation) ·
Game State Manager · Couch Input core. **Test suite: 42 green** (19 GSM + 21 Couch Input + 2 smoke).

## Velocity

All 5 Must-Have tasks (budgeted ~4 days) were cleared well inside the 5-day window, with full test
coverage and zero rework. Signal: **Sprint 2 can be sized up** — but Movement is L-effort and
feel-critical, so keep the 20% buffer rather than packing it.

## What went well

- **ADR-0001 paid for itself immediately.** Building every system DI-first (inject `config`,
  `time_source`, `pause_sink`) meant 40 system tests run with no live device and never touch a real
  SceneTree. The "input → intent → state" boundary is enforced by a one-line grep guard.
- **GUT harness was frictionless** once installed — headless, fast (<0.5 s), reliable.
- **Clean separation held** — GSM and Couch Input have zero knowledge of each other's internals;
  Couch Input depends on GSM only through the `state_changed` signal.

## What to watch / improve

- **Social playtest still outstanding.** The PROCEED was developer-confidence. Foundation systems
  aren't loop-specific so this was safe — but it must happen before Movement's feel is pinned.
- **Deferred work is tracked, not lost:** Couch Input clan-select state machine (Browsing/Locked/
  Ready + forced uniqueness) + menu hold-to-repeat → build with MatchSetup / Clan Cosmetics (VS tier).
- **`active.md` is wiped between turns** (gitignored + a clean hook). Treat the sprint docs as the
  source of truth; `active.md` is a convenience only.
- **Autoload naming convention established:** the singleton name differs from the class name
  (`GameState`/`GameStateManager`, `CouchInput`/`CouchInputSystem`) to avoid Godot clashes — apply
  to all future autoloads.

## Actions for Sprint 2

1. **Re-sequence around the dependency chain that matters:** Map → Character Controller → **Movement**.
   End the sprint with *a character that moves in `src/` and feels right*.
2. **Run the 2-human social playtest at sprint start** — before pinning Movement's tuned values into
   production config.
3. **Pin the prototype's tuned values** (dodge i-frames, throw velocity, jump/dash, etc.) into
   data-driven config as the production starting point (see prototype REPORT.md Metrics).
4. Carry the 20% buffer; Movement is the L-effort hot-zone.
