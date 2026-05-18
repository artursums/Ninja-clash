# Prototype Report: Movement and Combat

> **Status**: PRE-PLAYTEST — Hypothesis + Approach filled in; Result + Metrics + Recommendation **left blank for the playtest session**.
>
> See [README.md](README.md) for playtest instructions. Fill the remaining sections after a real playtest.

---

## Hypothesis

**The throw-dodge-retrieve loop with one-hit-kill rules is intrinsically fun in a 2-player local context for sessions of 15+ minutes** (verbatim from `design/gdd/game-concept.md` MVP Definition).

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

> **TO FILL IN AFTER PLAYTEST**
>
> Capture **specific observations**, not opinions. For example:
>
> - "At `dodge_iframe = 0.20`, P2 successfully dodged 7 of 12 incoming throws over a 5-round match."
> - "Throw velocity 200 felt readable; at 350 the dodge became unreliable for both players (~2/10 success)."
> - "Pickup radius 12 felt cramped — players sometimes ran past stuck shurikens; 18 felt comfortable."
> - "Self-hit immunity at 0 caused 3 accidental spawn-suicides in the first 2 minutes; at 0.083 zero accidents over 10 rounds."

**[Fill in here.]**

---

## Metrics

> **TO FILL IN AFTER PLAYTEST.** Even rough numbers are valuable — "we played for 15 minutes, here's what we noticed" beats "felt good."

- **Playtester count**: N people (target: 2+ humans — solo testing both halves of the keyboard is OK for the first pass but the social feel can't be tested solo)
- **Total playtest duration**: X minutes
- **Rounds completed**: N rounds across M matches
- **Sub-minute round rate**: X / N rounds ended in <60 s? (concept target: 30–60 s)
- **Frame time** (if observed in `top` / Godot's monitor): peak ms per frame during 2P chaos
- **Tuning values that felt right** (final slider positions after iteration):
  - `dodge_iframe_duration_s`: ____ (default 0.20)
  - `shuriken_throw_velocity`: ____ (default 200)
  - `pickup_radius_px`: ____ (default 12)
  - `self_hit_immunity_s`: ____ (default 0.083)
- **Subjective feel notes** (specific, not "good/bad"):
  - Dodge feel: ____
  - Throw arc feel: ____
  - Retrieval feel: ____
  - Kill clarity (do you know why you died?): ____
- **Concept-doc MVP acceptance check**:
  - At least 3 of 5 playtesters describe dodge timing as "satisfying" or "fair"? ____
  - At least 3 of 5 voluntarily request another match after their first? ____

---

## Recommendation: **[PROCEED / PIVOT / KILL]**

> **TO FILL IN AFTER PLAYTEST.** One paragraph with evidence.

**[Fill in here.]**

---

## If Proceeding

> If the prototype validates the loop, the production MVP must be written from scratch (this prototype code is throwaway). The following must change from the prototype:

- **Architecture**: implement the full 8 MVP GDDs (CouchInput slot/clan assignment, Movement with all 7 verbs including wall-jump + drop-through + comfort features, Combat as dict-based autoload per its GDD, Projectile with both states gated cleanly, CC with `slot` field + 32-bit collision layers, Map with `MapResource` + recoverability validator, GSM with full state machine, Round Flow with cyclic spawn rotation + kill-cam + full match flow)
- **Performance targets**: 60 fps locked on Steam Deck; verify per the budgets in each GDD's Performance section
- **Scope adjustments**: pin tuning values from the playtest (especially the 4 live-tunable levers); document any GDD revisions discovered during playtest
- **Estimated production effort**: ~3 months to v1 per concept doc; first sprint = ~2-3 weeks for full MVP per Scope Tiers table

---

## If Pivoting

> If the loop is *workable but needs change*, document:

- Which sub-hypothesis failed (dodge feel / throw velocity / retrieval)
- What alternative the playtest suggests (e.g., "catch needs a separate input button, not dodge auto-catch" — would invalidate the resolved `catch_input_mode` decision)
- Whether the GDDs need revision before MVP commit

---

## If Killing

> If the loop is fundamentally not fun even with extreme tuning, document:

- Which playtest finding was decisive
- What the failure suggests about the game concept (e.g., "1-hit-kill is too punishing at 2P — players never feel safe enough to throw")
- Whether the project should pivot (alternative mechanic / 2-hit-kill / shield variant) or stop

Per concept doc: *"If this hypothesis fails in MVP testing, the project pivots or stops."*

---

## Lessons Learned

> **TO FILL IN AFTER PLAYTEST** — even short notes are valuable for the production MVP design.

Examples of lesson categories worth capturing:

- **GDD revisions** the playtest suggested (e.g., "Movement Rule 4.4 needs a smaller stationary threshold than 5 px/s — dodge triggered too rarely")
- **Cross-system surprises** (e.g., "self-hit immunity at 83ms is too short when throwing straight down — shuriken returns from a wall bounce within the window")
- **Tuning interactions** (e.g., "high throw velocity + small pickup radius = stuck shurikens become uncatchable")
- **Player behaviors** that confirm or contradict the concept's predicted dynamics (e.g., did players "count opponents' shurikens"? Did they develop "preferred retrieval routes"?)

---

*Generated as a scaffold by `/prototype movement-and-combat` on 2026-05-18. Playtest required to complete.*
