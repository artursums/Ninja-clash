# Prototype Report: Movement and Combat

> **Historical record.** This is the prototype decision report as it stood on **2026-05-26**,
> kept because it documents *why* the project continued and which tuning values were carried
> forward. It describes the prototype, not the shipped game — see [`README.md`](README.md) for
> what Ninja Clash is today, and *What happened next* at the bottom for the gap between them.
>
> **Verdict**: CONCLUDED — **PROCEED** (developer-confidence). A formal 2+ human social
> playtest was recommended but never separately run; that is stated plainly below.

---

## Hypothesis

**The throw-dodge-retrieve loop with one-hit-kill rules is intrinsically fun in a 2-player local context for sessions of 15+ minutes** (verbatim from `docs/gdd/game-concept.md` MVP Definition).

More specifically, this prototype tests three sub-hypotheses:

1. **Dodge feels like a parry, not luck.** The named "single most consequential balance lever" (`dodge_iframe_duration_s`) has a sweet spot in the 0.15–0.30 s range where reading the throw is *possible* but requires skill.
2. **Throw velocity creates real reaction-time pressure.** The named "reaction time required to dodge" lever (`shuriken_throw_velocity`) at ~200 px/s produces a dodge window that rewards reading over reflex.
3. **Retrieval is the recovery beat.** Picking up shurikens from walls/floors gives the player something purposeful to do *between* throws, sustaining engagement when out of stash.

If even one of these sub-hypotheses fails decisively, the whole loop is in question.

---

## Approach

**What was built** (10 files, ~1 day equivalent of effort):

- Godot 4.6 project with autoload `Combat` singleton holding 4 live-tunable parameters
- Single flat-platform map (480×270 internal, 800×450 window, walled on 4 sides)
- 2 player `CharacterBody2D` instances spawned at opposite corners
- Player mechanics: walk, jump (contextual A-button), dodge (with `is_iframe` window driven by `dodge_iframe_duration_s`), throw, catch (auto-on-i-frame), deflect (when stash full), die, respawn
- Shuriken `Area2D` projectile with manual gravity integration, wall-stick on `StaticBody2D` overlap, pickup detection (distance-based) per tick when stuck
- Live tuning UI with 4 HSliders (i-frame duration, throw velocity, pickup radius, self-hit immunity)
- Match progression: first-to-5 wins, both players respawn 2 s after any kill
- Keyboard input only (2P): WASD-S + Arrows-Down

**Shortcuts taken** (intentional — prototype scope):

- No wall-jump (the GDD specifies it; this prototype tests only the throw/dodge loop)
- No one-way platforms, no screen-wrap, no double-jump
- No real Round Flow — simplified to "any kill → score + respawn both" (the full Round Flow GDD's alive-count tracking + match-end + kill-cam is overkill for the feel question)
- No 4-player, no controllers, no clans, no audio, no real art (colored rectangles)
- No CouchInput-style slot/clan assignment — slots hardcoded 1 + 2 by key bindings
- Production-quality state machines, dependency injection, typed signals — all skipped

**What was NOT shortcut** (load-bearing for the feel question):
- Self-hit immunity is implemented (so spawn-throws don't accidentally suicide the thrower — would skew "is throw worth it?" judgment)
- Catch is implemented (catching shurikens during i-frames IS the point of dodge per concept doc)
- Deflect when stash full is implemented (otherwise full-stash players can't defend)
- Pickup eligibility gated by `stash < 3` (otherwise stash invariant breaks)

---

## Result

**PROCEED.** (Recorded 2026-05-26.) The throw–dodge–retrieve loop was validated through
extensive hands-on iteration across multiple sessions (solo and keyboard-vs-bot). The
developer's judgment is that the core loop is fun, has the "one more match" pull, and that
the mechanics read clearly. This cycle also explored several feel changes beyond the original
three sub-hypotheses:

- **Double jump removed** — vertical movement now relies on the single jump + wall-jumps +
  head-stomps; reads as cleaner, not worse.
- **Dash/dodge** — straight-up dash height capped to match the diagonal; the cooldown now
  resets instantly on landing (the old air-dash penalty felt too long).
- **Katana** — added a real post-swing recovery cooldown (the previous one was dead code).
- **L2/J defense (guard)** — prototyped, then **held out of v1** pending validation (off-GDD;
  pushes on the purist anti-pillars).

> **Caveat — honesty note:** a formal multi-tester (2+ human) social playtest with recorded
> metrics was **not** separately captured. This is a *developer-confidence* PROCEED based on
> heavy iterative testing. A social playtest is still recommended early in production as cheap
> insurance, but it is not blocking the decision to build.

---

## Metrics

> Formal structured metrics were not separately captured this cycle (single-developer
> iterative testing). Recorded below: what is known, and the tuning values carried forward.

- **Playtester count**: 1 (developer), solo + vs bot — formal multi-tester session not yet run
- **Total playtest duration**: multiple iterative sessions (not separately timed)
- **Rounds completed**: not formally counted
- **Sub-minute round rate**: not measured (concept target: 30–60 s)
- **Frame time**: no errors and no perceived hitching in headless + windowed runs (Apple M3)
- **Tuning values carried forward** (prototype `Combat` autoload defaults — to be pinned in production config):
  - `dodge_iframe_duration_s`: 0.20 (default kept)
  - `shuriken_throw_velocity`: 200 (default kept)
  - `pickup_radius_px`: 12 (default kept)
  - `self_hit_immunity_s`: 0.083 (default kept)
  - Movement: `MAX_HSPEED` 158.4 · `JUMP_STRENGTH` 480 · single jump (no double jump) ·
    `SLIDE_SPEED` 400 with up-dash capped to `SLIDE_SPEED·sin45°` · dash recharges on floor touch
  - Katana: swing 0.32 s + 0.20 s recovery cooldown
- **Subjective feel notes**: developer-confident the loop is fun; per-tester notes pending a social playtest
- **Concept-doc MVP acceptance check**: not formally measured (single-developer decision)

---

## Recommendation: **PROCEED**

Developer-confidence PROCEED. After extensive hands-on iteration, the core throw–dodge–retrieve
loop is judged fun and buildable, and the prototype has fully de-risked the make-or-break
Movement and Combat systems. Production begins with the Foundation layer per
`docs/production/sprint-01.md`. Two caveats carried into production: (1) run a 2+ human
social playtest early to confirm the solo judgment; (2) the L2/J defense mechanic is deferred
until validated. The prototype tuning values above are pinned as the production starting point.

---

## What happened next

The PROCEED decision held, but two things in the plan above did **not** survive contact
with reality — recorded here rather than quietly edited out:

- **"This prototype code is throwaway; rewrite from scratch."** That plan was executed for
  two sprints and then abandoned. The prototype had grown into a nearly-complete, playable
  game, and the rewrite was re-implementing validated behaviour at real cost. The prototype
  was promoted to the production base instead — see
  [`docs/architecture/ADR-0002-prototype-as-production-base.md`](docs/architecture/ADR-0002-prototype-as-production-base.md).
  This report's *If Proceeding* plan is therefore superseded; it has been removed rather
  than left standing as a false statement of intent.
- **The one-hit-kill hypothesis was not what shipped.** The game runs on **5 HP** with a
  katana and a guard. The hypothesis this report validated — the throw–dodge–retrieve
  *loop* — held; the lethality rule around it did not, and the divergence was a deliberate
  feel decision made during iteration, not an oversight.

The tuning values pinned above are the 2026-05-26 snapshot and have since moved on
(`shuriken_throw_velocity`, for instance, is now 648). Current values live in
`player_tuning.tres`, `bot_tuning.tres` and the `Combat` autoload.

The unfilled *If Pivoting*, *If Killing* and *Lessons Learned* template sections were
removed: the first two describe branches that were not taken, and the third was never
filled in. An empty template section documents nothing.

---

*Prototype decision report, concluded 2026-05-26. Superseded for production planning by
ADR-0002; retained as the record of why the project continued.*
