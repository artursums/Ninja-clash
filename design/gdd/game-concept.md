# Game Concept: Four Clans

*Created: 2026-05-17*
*Status: Draft*

---

## Elevator Pitch

> A 2D single-screen arena PvP where 2–4 ninjas hunt each other across
> stacked platforms using a limited stash of standard shurikens — projectiles
> that can be retrieved from walls and floors mid-fight to keep the pressure on.
> Built for the couch: four controllers, one screen, one clean kill at a time.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D arena PvP / single-screen platform fighter |
| **Platform** | PC (Steam + Itch.io) |
| **Target Audience** | Mid-core to hardcore players who own controllers and have local friends; the TowerFall / Duck Game / Smash couch-night audience |
| **Player Count** | 2–4 players, local couch only (online deferred to v2+) |
| **Session Length** | ~30–60 second round; ~15–45 minute first-to-N match (launch default: N=10) |
| **Monetization** | Premium (one-time purchase). No microtransactions, no battle pass. |
| **Estimated Scope** | Small (~3 months to v1 launch) |
| **Comparable Titles** | TowerFall Ascension (2013), Duck Game (2014), Lethal League / Blaze (2014/2018), Stick Fight: The Game (2017) |

---

## Core Fantasy

You are a silent rooftop shinobi. You don't shout, you don't grandstand, you
don't carry exotic weapons. You carry three plain shurikens, you read the
room, and you turn every dodge, ricochet, and recovered throw into a clean
kill.

The fantasy is **restraint as power**. In a genre that usually escalates —
bigger weapons, more abilities, louder VFX — Four Clans deliberately strips
back. The promise is that mastery of a tight, fair set of verbs feels better
than mashing through a buffet of options. When you outplay another human
with the same tools they have, the kill belongs to you and you alone.

---

## Unique Hook

It's like TowerFall, **and also** every player has mechanically identical
loadouts — the four clans (Shadow, Storm, Frost, Fire) differ only in
costume color and emblem. There are no weapon variants, no power-ups, no
character abilities to memorize. The game is settled entirely by skill at
the same shared verb set.

This positions Four Clans against the genre default. TowerFall, Duck Game,
and Stick Fight all build replayability through weapon variety. Four Clans
bets the entire product on the opposite thesis: that a single, deeply-tuned
shuriken loop has more long-term skill ceiling than a buffet of pickups, and
that fairness creates cleaner head-to-head moments than asymmetry ever does.

This is a gameplay decision, not a cosmetic one. Mechanical identity = clean
attribution of every win and loss to player skill.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 2 | Punchy shuriken throws, satisfying wall-thunks, dodge i-frame chime, snappy hit-stop on kills, pixel-art clarity |
| **Fantasy** (make-believe, role-playing) | 4 | Silent-shinobi tone via restraint: no voice-lines, no UI clutter, minimal HUD, deliberate animation |
| **Narrative** (drama, story arc) | N/A | No narrative |
| **Challenge** (obstacle course, mastery) | 1 | High skill ceiling on dodge timing, throw arc prediction, projectile catching, wall-jump positioning, retrieval routing |
| **Fellowship** (social connection) | 3 | Couch co-location is half the product — the shared room, the trash-talk, the spectate-after-death wait |
| **Discovery** (exploration, secrets) | N/A | No hidden content, no world to explore |
| **Expression** (self-expression, creativity) | N/A | Only cosmetic clan choice — minimal expression surface, by design |
| **Submission** (relaxation, comfort zone) | N/A | The game is the opposite — high-tension, sub-minute round resolution |

**Primary: Challenge (1) and Sensation (2).** Fellowship (3) is a context the
game depends on but does not itself produce — the players bring it.

### Key Dynamics (Emergent player behaviors)

- Players learn to **read opponents' throw arcs** and pre-emptively dodge or wall-slide
- Players treat the **dodge button as an active catch / parry**, not just an evasion
- Players develop **preferred retrieval routes** per map — which walls are safe, which floors are exposed
- Players **count opponents' shurikens** and exploit empty-handed enemies aggressively
- Players who die mid-round trash-talk during the spectate wait — the dead-time becomes social currency
- Skill cliques form within friend groups; a "house champion" emerges and gets dethroned

### Core Mechanics (Systems we build)

1. **One-hit-kill shuriken combat** with retrievable projectiles (from walls and floors)
2. **Movement vocabulary**: jump, double-jump, dodge (i-frames + catch-on-dodge), wall-slide, wall-jump
3. **Round flow**: spawn with 3 shurikens → fight → death waits out round → first-to-N rounds wins the match
4. **Map system**: 4–6 hand-built single-screen platform layouts with deliberate retrieval geography
5. **Couch input layer**: 4 simultaneous controllers, hot-plug, clan-select via face-button mapping

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Tactical: target selection, throw timing, dodge timing, retrieval routing, when to commit a shuriken vs hold. No strategic-layer choice (no builds, no loadout). | Supporting |
| **Competence** (mastery, skill growth) | The entire long-tail. Every verb has a real skill ceiling. The fairness pillar means every win is unambiguously attributable to skill. | **Core** |
| **Relatedness** (connection, belonging) | Couch co-location is the product. Shared screen, shared room, shared laughter. The dead player still watching is social. | **Core** |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Killers/Competitors** (~60% of appeal) — Head-to-head skill expression. The read-counter-read cycle is the whole product.
- [x] **Achievers** (~25%) — Players who chase mastery for its own sake: perfecting dodge timing, learning map retrieval routes, climbing a personal skill curve.
- [x] **Socializers** (~15%) — Couch context attracts players who want shared-room play more than they want to win.
- [ ] **Explorers** — Explicitly not served. No world to discover, no systems to unravel, no hidden content.

### Flow State Design

- **Onboarding curve**: First 2 minutes — throw, dodge, jump, wall-jump. The verb set is small enough that play-by-doing is enough; no tutorial gating. A short optional control-card screen is acceptable.
- **Difficulty scaling**: Opponent-driven. Human opponents auto-scale to the room's skill. (Bot mode in v1.x will need explicit difficulty.)
- **Feedback clarity**: Always-visible per-player shuriken counter; brief "X eliminated Y" feed after each kill; scoreboard tick on round end; obvious dodge-i-frame visual.
- **Recovery from failure**: ~3–5s between rounds, instant respawn next round. No punishment beyond the round loss.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Stalk → spot → throw → dodge incoming → retrieve from wall/floor → reposition.
Every shuriken thrown is a small commitment — you've spent a resource and
exposed your position. Retrieval is the recovery beat that resets tension.

### Short-Term (5-15 minutes)

A single round resolves in ~30–60 seconds. One-hit-kill + 3-shuriken stash +
wait-out-the-round respawn means rounds end fast and decisively. The "one
more round" hook is built into the loop itself: the round ends, the scoreboard
ticks up, the next round spawns immediately.

### Session-Level (30-120 minutes)

A first-to-10 match takes 15–45 minutes. Couch sessions naturally stack matches
as laughter and trash-talk escalate. Match end is the natural stopping point.
Real-world sessions tend to end when someone has to leave, not when the game
runs out of content.

### Long-Term Progression

**None mechanically.** All progression is skill-internal to the player — better
dodge timing, sharper throw prediction, smarter wall-jump routing, cleaner
retrieval routes. No XP, no unlocks, no meta-progression, no battle pass.

This is a session game, not a service game. The friend group is the
progression system.

### Retention Hooks

- **Curiosity**: Minimal — no unlocks, no hidden content
- **Investment**: Zero — no progression to lose, no characters to grow attached to
- **Social**: **High** — the friend group brings each other back. Couch night becomes "we're doing Four Clans tonight."
- **Mastery**: **High** — the skill ceiling is the long tail. You always want to be the house champion.

---

## Game Pillars

### Pillar 1: Restraint over Spectacle

Every action is small. Every kill is clean. We choose silence over flash,
precision over chaos.

*Design test*: When evaluating any feature, ask "does this whisper or scream?"
Pick the whisper. A subtle dodge-frame chime beats a screen-flash.

### Pillar 2: Fairness Is Sacred

All players have mechanically identical tools. Differentiation is cosmetic
only. The match is settled by skill, not selection.

*Design test*: Reject any mechanical asymmetry between players. If clan
Shadow's shuriken behaves even slightly differently from clan Fire's, the
feature is wrong.

### Pillar 3: The Couch Is the Game

This is designed for co-located play. The shared screen, the shared room, the
shared rivalry is the point.

*Design test*: If a feature only makes sense online, defer it. If a feature
breaks couch readability (e.g., split-screen at 4-player), reject it.

### Pillar 4: Every Shuriken Matters

Scarcity drives choice; retrieval rewards positioning. The resource economy
is the soul of the game.

*Design test*: Reject changes that reduce scarcity (bigger stash, regenerating
ammo) or weaken retrieval (auto-pickup, magnetic returns). The 3-shuriken
stash is non-negotiable in v1.

### Pillar 5: Game-Feel First

Tuning the dodge frame count, the throw arc, the wall-slide friction matters
more than content. Polish the verbs before adding nouns.

*Design test*: Prefer 100 hours iterating on existing verbs over adding a new
one. If a feature debate is "add map vs polish dodge," polish wins.

### Anti-Pillars (What This Game Is NOT)

- **NOT character abilities or asymmetric mechanics** — violates *Fairness Is Sacred*; dilutes the "clans are cosmetic" identity.
- **NOT online multiplayer in v1** — violates *The Couch Is the Game* in priority terms and would consume the entire v1 budget.
- **NOT meta-progression, XP, or unlocks** — violates *Restraint over Spectacle*. This is a session game, not a service game.
- **NOT weapon variants, bombs, or power-up pickups in v1** — violates *Every Shuriken Matters* and *Restraint over Spectacle*.
- **NOT a single-player campaign or story mode** — out of scope, dilutes focus. (Bot/practice mode is a separate, scoped v1.x feature.)

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **TowerFall Ascension** | Retrievable-projectile combat, one-hit-kill, couch focus, dodge-as-catch | Ninja/shuriken framing instead of archery; deliberately purist with no weapon variants | Validates the entire business model — small couch-PvP arena can sustain a small studio |
| **Duck Game** | 4-player couch chaos, sub-minute round pacing | No weapon variety; no ragdoll humor; more focused/serious tone | Proves a decade of sustained sales is achievable in this niche |
| **Lethal League / Blaze** | Tight reactive arena, no meta-progression, "mastery is the product" | Projectile-throw economy instead of ball-physics rally | Validates the no-meta ethos commercially |
| **Stick Fight: The Game** | Small content, strong viral mainstream success | Skill-driven instead of physics-comedy driven | Proves a tight, content-light scope can break out |

**Non-game inspirations**: Classic shinobi cinema (e.g., *Shinobi no Mono*,
*Shogun Assassin*) for the silent-deliberate-lethal tone. Ukiyo-e woodblock
aesthetic as an art-direction touchstone — bold silhouettes, restrained
palettes, deliberate negative space.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16–40 |
| **Gaming experience** | Mid-core to hardcore — action games, fighting games, the TowerFall audience |
| **Time availability** | 30–60 minute couch sessions with friends, often as part of a games-night rotation |
| **Platform preference** | PC (Steam) for couch-with-controllers; Steam Deck for portable couch |
| **Current games they play** | TowerFall, Duck Game, Super Smash Bros., Lethal League, Nidhogg, Gang Beasts |
| **What they're looking for** | A tight, fast couch-PvP game that respects their time and rewards skill |
| **What would turn them away** | Bloated unlocks, asymmetric balance, weak game-feel, online-only, microtransactions, story padding |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — excellent 2D pipeline, strong joypad input (4 controllers + hot-plug), GDScript productivity for a small team, free + no royalties, Jolt physics by default in 4.6, smooth Steam/Itch deployment |
| **Key Technical Challenges** | (1) Game-feel iteration loop — needs fast tuning cycle. (2) 4-controller couch input + hot-plug + clan-select UX. (3) Projectile/dodge collision determinism (matters less for local, matters more if online is added later). |
| **Art Style** | Pixel art |
| **Art Pipeline Complexity** | Low–Medium — sprite-based 2D, per-clan recolor via palette swap (single base sprite serves all four clans). |
| **Audio Needs** | Moderate — punchy SFX (shuriken whiff, hit, dodge chime, wall-thunk), ~3–5 music tracks. Future audio direction needed. |
| **Networking** | None in v1. Architecture should not preclude future P2P or client-server but should not implement it either. Single ADR will cover input/state separation. |
| **Content Volume** | 4–6 maps · 4 cosmetic clan recolors (1 base sprite + palette swaps) · ~10–15 SFX · ~3–5 music tracks · 1 menu flow |
| **Procedural Systems** | None planned. All maps hand-built. |

---

## Risks and Open Questions

### Design Risks

- **Game-feel is the entire product.** If dodge / throw / wall-jump / retrieval don't feel sublime, no amount of content or polish saves the game. (HIGH severity)
- **Content thinness** — with no progression and pure PvP, replayability rests on game-feel + map variety. 4 maps may feel thin; aim for 6. (MEDIUM)
- **Solo discoverability** — a buyer without local friends gets nothing in v1. Could hurt reviews and word-of-mouth. (MEDIUM)
- **Cosmetic-only clans may underperform commercially** vs the genre default of character variety. Counter-positioning is a real bet. (LOW-MEDIUM)

### Technical Risks

- **4-controller input + hot-plug + join-mid-match** in Godot 4.6 — mature but couch-UX is non-trivial. (MEDIUM)
- **Online-deferral architectural debt** — today's input/state code shouldn't bake in local-only assumptions. (LOW, mitigated by an early ADR)

### Market Risks

- **Genre is small but loyal** — TowerFall, Duck Game, and Stick Fight all proved the niche, but a polished entry realistically earns 10k–100k sales over time. Plan for the niche; treat breakout as upside. (Inherent to scope, not a fixable risk)
- **Couch PvP audience is shrinking long-term** as more games go online-first. Niche may keep narrowing. (LOW-MEDIUM, partially addressed by future online stretch goal)

### Scope Risks

- **Game-feel iteration is open-ended** — the prototype phase could consume more time than budgeted. (MEDIUM, mitigated by hard time-boxing prototype phases)
- **Adding bot mode prematurely** would blow v1 scope. Deferring it to v1.x is the discipline call. (Already mitigated by anti-pillar)

### Open Questions

- **Dodge i-frame duration** — what frame count gives the right risk/reward? TowerFall is ~16 frames at 60fps; needs prototype validation in our context.
- **Catch mechanic** — does dodge auto-catch incoming shurikens, or does catching require a separate input? Prototype both.
- **Round time cap** — when no one dies for 60–90s, do we trigger sudden-death (e.g., shrinking arena, hunter buff)? Needs design.
- **Map size and player density** — 4 players on a small map vs roomy map = completely different feel. Needs prototype-driven calibration.
- **Bot AI architecture (v1.x)** — what behavior layer? Needs at least a sketch before v1 architecture decisions are locked, to avoid coupling that excludes bots later.
- **Accessibility baseline** — colorblind-safe clan palettes, key-rebinding, audio-cue redundancy. Owner: accessibility-specialist (later).

---

## Detailed Rules

Concept-level rules locked at this layer. Implementation-level specifics —
shuriken physics curves, dodge i-frame counts, retrieval radius, wall-stick
behavior, controller hot-plug handling — are intentionally deferred to
per-system GDDs created via `/design-system`. The **Dependencies** section
below shows which system GDD owns each detail.

- **Lethality**: a single shuriken hit to any body part kills instantly.
- **Stash**: each player spawns with exactly 3 shurikens. Maximum carry is 3.
- **Movement verbs**: walk, jump, double-jump, dodge (with i-frames), wall-slide, wall-jump. No other movement abilities in v1.
- **Round flow**: spawn → fight → death is permanent for the round → round ends when one player remains → first-to-10 round wins is the match (N=10 is the launch default; tunable — see Tuning Knobs).
- **Differentiation**: all four clans are mechanically identical. The only differences are costume color and clan emblem.
- **Power-ups / variants**: none in v1. The shuriken is the only weapon.
- **Online**: none in v1.

Anything not in this list is open to per-system-GDD specification.

---

## Formulas

No game-concept-level formulas. All numeric tuning — dodge i-frame counts,
throw velocity, gravity, wall-slide friction, retrieval pickup radius,
respawn delay — is specified in per-system GDDs. The **Tuning Knobs**
section below enumerates which formulas/values will exist and where.

The single mathematical statement at this layer:

```
match_won(player) := round_wins(player) >= N    where N = 10 (launch default, tunable)
```

---

## Edge Cases

Concept-level edge-case behaviors. Detailed implementation behavior is
deferred to the listed per-system GDD.

| Edge case | Concept-level behavior | Detailed in (future GDD) |
|---|---|---|
| Round ends with no kills (stalemate) | Sudden-death mechanic to be designed (shrinking arena / hunter buff / time-limit-kills-all). Without resolution, round ends with no winner. | Round Flow |
| Two players die in the same frame | Both deaths register; round may end in tie. No tie-break in v1 (no one banks the round win). | Round Flow |
| Controller plugs in mid-round | New player cannot join the current round. Joins as eligible for next round. | Couch Input |
| Controller unplugs mid-round | Player is eliminated immediately; round continues. Reconnect re-joins at next round. | Couch Input |
| All shurikens off-screen / unrecoverable | Cannot happen by map design — every map MUST guarantee 100% projectile recoverability via the wall/floor system. | Map Design |
| Player throws final shuriken and dies before retrieval | Standard behavior. No special handling. | Combat |
| Shuriken hits two players simultaneously | Both die. | Combat |
| Catch-on-dodge interaction | **TBD: either dodge auto-catches incoming shurikens, OR catching requires a distinct input. Must be resolved before MVP can ship** (see MVP). | Movement (early-priority) |

---

## Dependencies

The five systems identified in **Core Mechanics** (MDA section) have the
following dependency relationships. Per-system GDDs MUST update the
corresponding entry here when they specify additional dependencies.
`/map-systems` will produce the canonical `design/gdd/systems-index.md`
from this list.

| System | Depends on | Depended on by |
|---|---|---|
| **Combat** (shuriken throw, hit, kill, retrieval) | Movement (dodge i-frame interaction), Map (wall geometry for stick & retrieval) | Round Flow |
| **Movement** (walk, jump, dodge, wall-slide, wall-jump) | Couch Input, Character Controller *(updated 2026-05-17 during Movement GDD design)* | Combat, Round Flow, Visual FX |
| **Round Flow** (spawn, death, round-end, match-end) | Combat, Movement, Map, Game State Manager, Couch Input *(updated 2026-05-17 during GSM + Couch Input GDD design)* | — |
| **Map** (single-screen platform layouts) | — | Combat (geometry), Round Flow (spawns), Movement (collision) |
| **Couch Input** (4 controllers, hot-plug, clan-select) | — | Movement (player intent), Round Flow (join/leave) |

**External dependencies**: Godot 4.6 `InputEventJoypad*` system, GodotPhysics2D collision system.

---

## Tuning Knobs

Enumerated knobs that require explicit values in per-system GDDs. Each knob
lists a safe initial range (TowerFall-informed best guess) and the gameplay
aspect it controls. Per-system GDDs MUST link back here and pin a final
value.

| Knob | Safe range (initial) | Affects | Owner GDD |
|---|---|---|---|
| `shuriken_stash_size` | 3 (locked by Pillar 4) | Resource scarcity, round pacing | Combat |
| `dodge_iframes_duration_ms` | 100–300 ms (TowerFall ~16f @60fps ≈ 260 ms) | **Single most consequential balance lever** — too long = stalemates; too short = lucky kills feel unearned | Movement |
| `shuriken_throw_velocity` | TBD (prototype-driven) | Reaction time required to dodge | Combat |
| `shuriken_wall_stick_duration_s` | TBD (or permanent until retrieved) | Retrieval pressure, map clutter | Combat |
| `wall_slide_friction` | TBD | Vertical mobility, wall-as-cover viability | Movement |
| `wall_jump_cooldown_ms` | TBD | Wall-jump abuse prevention | Movement |
| `gravity` | Standard 2D platformer range | Jump arc, fall time | Movement |
| `round_time_cap_s` | 60–90 s (or none) | Stalemate frequency, session pacing | Round Flow |
| `first_to_n_match_target` | N = 10 (TowerFall default) | Match length | Round Flow |
| `respawn_delay_s` | 3–5 s between rounds | Round-to-round rhythm | Round Flow |
| `pickup_radius_px` | TBD | Retrieval feel, contested-pickup tension | Combat |
| `catch_input_mode` | dodge-button auto-catch during i-frames *(resolved 2026-05-17 during Movement GDD — TowerFall parity)* | Defensive depth, control complexity | Movement |

---

## Acceptance Criteria

Concept-level acceptance criteria the project must satisfy to advance past
each scope tier. QA verifies pass/fail.

### MVP acceptance criteria

The MVP **passes** if all of the following are demonstrably true in 2-player
local-couch playtesting:

1. Two players can complete consecutive matches without crashes, with both controllers responding throughout.
2. The throw → dodge → retrieve loop executes end-to-end: a shuriken thrown, dodged (with i-frames preventing the hit), and either retrieved from a wall or picked up from the floor.
3. A clean one-hit kill resets the round within 5 seconds.
4. At least 3 of 5 first-time playtesters describe the dodge timing as "satisfying" or "fair" in open-ended feedback.
5. At least 3 of 5 first-time playtesters voluntarily request to play another match after their first.

If any criterion fails, the MVP is iterated (not the doc) until it passes — or the project pivots/stops.

### Vertical Slice acceptance criteria

All MVP criteria, plus:

- 4-player local matches play without input contention or crashes.
- Clan-select flow works for 4 controllers (face-button mapping).
- Scoring tracks correctly across rounds; match-end is detected and presented.

### v1 Launch acceptance criteria

All Vertical Slice criteria, plus:

- 4–6 maps shipped, each playtested for retrieval-route balance.
- Full audio pass (SFX + music).
- No P1 bugs in 8 consecutive hours of playtesting.
- 60 fps locked on minimum target hardware (Steam Deck).

---

## MVP Definition

**Core hypothesis**: "The throw-dodge-retrieve loop with one-hit-kill rules
is intrinsically fun in a 2-player local context for sessions of 15+ minutes."

If this hypothesis fails in MVP testing, the project pivots or stops. No
content production happens until this is validated.

**Required for MVP**:

1. One playable map (placeholder geometry, real platform layout)
2. Two-player local controller input
3. Throw, dodge (with i-frames), jump, double-jump, wall-slide, wall-jump
4. Three-shuriken stash per spawn, with floor and wall retrieval
5. One-hit-kill collision and round reset

**Explicitly NOT in MVP**:

- Clans / cosmetic differentiation
- Score, scoreboard, menus, clan-select, map-select
- Third and fourth player slots
- Audio polish (placeholder SFX only)
- Multiple maps
- Bot mode
- Art beyond programmer-art placeholders

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 map, placeholder art | Core loop only, 2 players | ~2–3 weeks (cumulative) |
| **Vertical Slice** | 1 polished map | Core loop + 4 players + scoring + clans | ~3–4 weeks (cumulative) |
| **Alpha** | 4 maps, placeholder art for some | All systems + menus + first audio pass | ~4–6 weeks (cumulative) |
| **v1 Launch** | 4–6 maps, full art + audio | All systems, polished menus, PC (Steam + Itch) | ~10–14 weeks (cumulative; ~3 mo total) |
| **v1.x (post-launch)** | + bot/practice mode, possibly more maps | Same systems + bot AI + accessibility deepening | TBD |
| **v2+ (stretch)** | + online multiplayer, possibly consoles | Networking, certification, cross-platform | TBD |

---

## Next Steps

- [ ] Validate this concept doc: `/design-review design/gdd/game-concept.md`
- [ ] Configure engine: `/setup-engine godot 4.6` (version already pinned)
- [ ] Optional pillar refinement conversation with `creative-director` agent
- [ ] Decompose into systems: `/map-systems` (creates the systems index and dependency map)
- [ ] Author per-system GDDs: `/design-system` (guided section-by-section writing)
- [ ] First architecture decision record: `/architecture-decision` (likely subject: input/state separation to permit future online)
- [ ] Prototype the MVP: `/prototype throw-dodge-retrieve` (validate core hypothesis)
- [ ] Run playtest after MVP: `/playtest-report`
- [ ] If validated, plan the first sprint: `/sprint-plan new`
