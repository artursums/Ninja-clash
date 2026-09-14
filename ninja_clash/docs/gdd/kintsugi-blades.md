# Kintsugi Blades & the Round Clock

> **Status**: In Design — not implemented
> **Author**: artursums + assistant
> **Last Updated**: 2026-09-14
> **Implements Pillar**: Primary — *Every Shuriken Matters*; Secondary — *Restraint over Spectacle*, *Fairness Is Sacred*
> **Supersedes**: `round-flow.md` Rule 148 (*"No round-time-cap in MVP"*) and its open
> `STALEMATE_BEHAVIOR` knob (`round-flow.md:384`). Those entries must be updated when this ships.

## Overview

This document specifies two systems that together answer one problem: **a Ninja Clash round
has no escalation.** A ten-second round and a ninety-second round play identically, the arena
accumulates loose ammunition the longer a round runs (working against *Every Shuriken Matters*),
and the game's most dramatic event — two blades meeting in mid-air — currently *destroys* both
blades rather than meaning anything.

**System A — Blade Temper (Kintsugi).** A shuriken is no longer spent by a clash. It is
**tempered** by it. Every blade carries a temper level 0–3; clashes and katana deflects raise it,
time in the arena lowers it. A tempered blade is faster, pierces a guard, and — at full
temper — refuses to stick when it misses, ricocheting through the arena as a hazard to everyone
before it cools. Temper transfers with possession: catching a hot blade takes it from your
opponent.

**System B — The Round Clock.** A round runs for a fixed time. If fighters are still standing
when it expires, the round goes to the most hearts remaining. The final seconds heat the arena.

The two systems are specified together because the clock's endgame and tiebreak are defined in
terms of temper, but **each ships independently behind its own `MatchConfig` toggle**. Either can
be enabled alone.

This document does not own projectile physics (`projectile.md`), the kill economy
(`combat.md`), or player verbs (`movement.md`). It owns blade *value* and round *pressure*.

---

## Player Fantasy

> *The blade that has been fought over is worth more than the blade that has not.*

Kintsugi is the Japanese craft of repairing broken pottery with gold, so that the break becomes
the most beautiful part of the object. That is the feeling: a shuriken that has been struck,
deflected, stolen and thrown back is not damaged goods — it is **the prize**, and everyone in the
room can see it glowing.

The intended emotional arc of a round:

1. **Opening** — three plain blades each, clean and quiet. Feeling out.
2. **First clash** — lightning, hitstop, and now two blades in the air with gold in their cracks.
   Both players' eyes snap to them. *Something on this screen is now worth having.*
3. **Contest** — the hot blade is caught, deflected, stolen back. Each exchange makes it more
   valuable and more dangerous to hold.
4. **The gamble** — someone throws the gold blade. If it lands, it is unblockable. If it misses,
   it does not stick: it screams around the arena, through the screen wrap, hunting *both* of you.
5. **The clock** — the last fifteen seconds, every blade on the floor flares gold at once and the
   room stops being safe.

The fantasy is **restraint under pressure**, not power fantasy. A tempered blade never hits
harder. It only becomes harder to survive and harder to hold onto. You do not get stronger; the
situation gets sharper. That distinction is what keeps this inside Pillar 1.

The couch-facing fantasy: **there is one shining thing on the screen and you are both trying to
own it.** A spectator who has never played can follow the whole round by watching the gold.

---

## Detailed Design

### System A — Core Rules: Blade Temper

1. **Temper level.** Every shuriken carries `temper: int`, range `0..TEMPER_MAX` (default 3).
   A freshly thrown blade from a stash slot carries whatever temper that stash slot held
   (see Rule 6). Round-start stash blades are temper 0.

2. **Clash tempers both blades.** When two *live* blades meet (`shuriken.gd::_do_shuriken_clash`),
   both gain `+1` temper, clamped to `TEMPER_MAX`. They ricochet apart exactly as today.
   **This replaces the current `ricocheted = true` "spent blade" behaviour entirely** — a clashed
   blade remains lethal.
   - Only blades with `temper` below `TEMPER_MAX` gain from a clash; a clash between two T3
     blades still ricochets and sparks, but grants nothing.
   - The existing `_clash_cooldown_until` gap (0.25 s) is retained unchanged and is what prevents
     a single pair of blades from farming temper in one contact.

3. **Katana deflect tempers and steals.** `shuriken.gd::deflect(by_slot, by_facing)` grants
   `+1` temper **and reassigns `thrower_slot` to `by_slot`.** A deflected blade becomes the
   deflector's property for kill-credit and for Rule 6. Deflecting is therefore the cheapest way
   to take a hot blade off an opponent — it costs no katana charge (deflect is already free) but
   requires standing in the blade's path.

4. **Temper effects.** Temper never changes damage. A blade deals one heart at every level.
   It changes only flight, defensibility, and the cost of missing:

   | Temper | Visual | Speed | Guard | On miss |
   |---|---|---|---|---|
   | **0** | plain steel | ×1.00 | blocked by guard | sticks, retrievable |
   | **1** | gold seams in the cracks | ×1.12 | blocked by guard | sticks, retrievable |
   | **2** | glowing seams, brighter trail | ×1.25 | **pierces guard** | sticks, retrievable |
   | **3** | fully gold, heat shimmer, hum | ×1.40 | **pierces guard** | **does not stick — goes hot** (Rule 5) |

   *Design decision — temper does not increase damage.* A gold blade that one-shots would make
   rounds swing on who happened to catch it, which violates *Fairness Is Sacred* ("every win
   unambiguously attributable to skill"). Instead the reward is **unblockability**, which is
   answerable by skill: the dodge still beats it. The dodge-catch is deliberately left as the
   universal answer to every temper level.

5. **The hot phase (T3 miss).** A temper-3 blade that strikes terrain does **not** stick. It
   reflects off the surface, retains its speed, and remains lethal to **every** fighter including
   its thrower, for `HOT_DURATION_S` (default 3.0 s). During the hot phase:
   - It reflects off walls and platforms rather than sticking, and wraps at the arena seam like
     any other body (`arena_rules.gd::wrap_position`).
   - Its own thrower is immune for `HOT_SELF_IMMUNITY_S` (default 0.5 s) from the moment it goes
     hot, then becomes a valid target like anyone else.
   - It **cannot be picked up** off the ground (it is not stuck) but it **can** be dodge-caught
     (Rule 6) or katana-deflected (Rule 3) — those are the ways to end the hazard early.
   - When `HOT_DURATION_S` expires it drops to temper 0, sticks where it next touches terrain,
     and becomes ordinary retrievable ammunition.

6. **Possession carries temper.** A dodge-catch (the existing i-frame catch) places the blade in
   the catcher's stash **retaining its temper**. The next throw from that stash slot fires a
   blade of that temper. Stash slots are not interchangeable for this purpose: a stash is an
   ordered list of temper values, and a throw consumes the **hottest** blade held.

   *Rationale:* throwing the hottest first makes the decision legible — "do I spend the gold one
   now?" — rather than requiring slot management on a gamepad.

7. **Cooling.** A blade that is **stuck in the arena** loses `1` temper every `COOL_INTERVAL_S`
   (default 6.0 s), down to 0. A blade **held in a stash does not cool.**

   *Rationale:* this is the stalemate pressure. Gold exists only where there is conflict —
   two players who refuse to engage watch the arena's value drain away, while the blade you
   fought for and caught stays yours. It punishes camping without a clock, diegetically.

8. **Round reset.** On round start every fighter's stash is refilled to `MatchConfig.start_shurikens`
   at temper 0, and every blade left in the arena is freed as today. No temper persists across
   rounds.

9. **Toggle.** The whole system is gated by `MatchConfig.kintsugi_enabled`. When false,
   `_do_shuriken_clash` keeps its current spent-ricochet behaviour and no temper is tracked.

### System B — Core Rules: The Round Clock

10. **The clock.** A round runs for `ROUND_TIME_S` (default 60.0 s), counted in scaled game time
    and started the instant the 3-2-1-FIGHT countdown completes (`main.gd::_start_countdown` →
    `State.ROUND`), not at `MATCH_INTRO`. It is displayed centred at the top of the screen as
    whole seconds.

11. **Display.** Plain type above 15 s. At `KILN_TIME_S` (default 15.0 s) remaining the readout
    turns gold and a low drone enters the mix. Below 5 s it pulses once per second.

12. **The Kiln.** At exactly `KILN_TIME_S` remaining, **every blade currently stuck in the arena
    gains `+1` temper simultaneously**, and cooling (Rule 7) stops for the remainder of the round.

    *Rationale:* this is the direct answer to the ammunition-abundance drift. The loose blades
    littering the arena late in a round are exactly what makes the endgame slack; the Kiln turns
    that litter into the most contested objects on screen at the moment the round needs urgency.
    It is one readable beat — the whole arena flares gold at once — not a new rule to learn.
    Requires System A; with Kintsugi disabled the Kiln is skipped and only the visual/audio
    escalation plays.

13. **Expiry with fighters standing.** When the clock reaches zero and two or more fighters are
    alive, the round ends immediately and is awarded to the fighter with the **most hearts
    remaining** (`player.gd::hp`). No kill is credited; the round score increments exactly as
    `Combat.award_survivor(slot)` does today.

14. **Tie on hearts — Sudden Death.** If two or more surviving fighters are tied on the highest
    heart count, the round does **not** end. It enters Sudden Death:
    - Every tied fighter is set to `1` heart. Fighters not tied for the lead are eliminated
      immediately (no kill credit).
    - Every blade stuck in the arena is set to `TEMPER_MAX`. The kiln opens.
    - The clock is set to `SUDDEN_DEATH_TIME_S` (default 20.0 s).
    - The round then resolves normally by elimination. If Sudden Death itself expires with more
      than one fighter alive, the round is a **draw**: no score is awarded to anyone, and the
      next round begins.

    *This rule is a design decision, not a user requirement.* The brief specified "most hearts
    wins" but not the equal-hearts case. A silent draw was rejected as anticlimactic for a couch
    game; Sudden Death is definitive, thematically consistent (the arena at maximum temper), and
    bounded. The quieter alternative — breaking the tie on total temper held — is recorded in
    Open Questions.

15. **Four-player FFA.** Rules 13–14 apply unchanged: most hearts among the living takes the
    round; all fighters tied for the lead enter Sudden Death together and the rest are eliminated.

16. **Toggle.** Gated by `MatchConfig.round_time_s`, where `0` disables the clock entirely and
    restores today's indefinite round. Sudden Death is separately gated by
    `MatchConfig.sudden_death_enabled`; with it off, a heart tie at expiry is a draw round.

### States and Transitions

**Blade temper state** (per shuriken, orthogonal to the existing `stuck` / `consumed` flags):

| State | Entered when | Exits to |
|---|---|---|
| `COLD` (temper 0) | thrown from a temper-0 slot; hot phase expires; cooled down | `TEMPERED` on clash/deflect |
| `TEMPERED` (1–2) | clash or deflect raises temper | `TEMPERED±1`, `COLD` by cooling, `HOT` by reaching 3 |
| `HOT_READY` (temper 3, in flight or stash) | temper reaches 3 | `HOT_LOOSE` on terrain contact; `COLD` if cooled while stuck |
| `HOT_LOOSE` | a temper-3 blade in flight strikes terrain (Rule 5) | `COLD` + stuck after `HOT_DURATION_S`; consumed if caught or deflected |

**Round clock state** (single, owned by `main.gd`):

| State | Entered when | Exits to |
|---|---|---|
| `IDLE` | any state that is not `ROUND` | `RUNNING` on countdown completion |
| `RUNNING` | 3-2-1-FIGHT completes | `KILN` at `KILN_TIME_S`; `IDLE` on elimination round-end |
| `KILN` | `KILN_TIME_S` remaining | `EXPIRED` at 0; `IDLE` on elimination round-end |
| `EXPIRED` | clock hits 0 with ≥2 alive | `IDLE` (round awarded) or `SUDDEN_DEATH` (heart tie) |
| `SUDDEN_DEATH` | Rule 14 | `IDLE` on elimination or draw |

### Interactions with Other Systems

| System | Interaction |
|---|---|
| **Combat** (`combat.gd`) | Clock expiry awards a round via the existing `award_survivor(slot)` path; no new scoring API. `clash_occurred` is unaffected — temper is granted inside `shuriken.gd`, not by the Combat autoload. |
| **Projectile** (`shuriken.gd`) | Owns `temper`, the clash grant, the cooling timer, the hot phase, and the speed multiplier. The hot phase is the only new physics behaviour: reflect instead of stick. |
| **Movement / guard** (`player.gd`) | `_blocks_incoming` must return false for `temper >= GUARD_PIERCE_TEMPER`. The guard meter (`GUARD_MAX_S` 4.0 / `GUARD_COOLDOWN_S` 5.0) is untouched — guard-piercing is a property of the blade, not a change to the guard economy. The dodge-catch is untouched and remains the universal answer. |
| **Round Flow** (`main.gd`) | Owns the clock, the Kiln trigger, expiry resolution and Sudden Death. Hooks into the existing `_start_countdown` → `State.ROUND` transition and the existing `_enter_round_end` path (`_round_end_until = now + 1.6`). |
| **HUD** (`hud.gd`) | Adds the countdown readout. The HUD is currently only a map banner (y=235) and a score bar, so there is ample room at top-centre. The blades themselves are the temper UI — no meter is added. |
| **Net** (`net.gd`, `net_codec.gd`) | `enum S` gains `TEMPER` and `HOT` fields; `encode_shuriken` / decode extend accordingly (+2 bytes per blade per snapshot at 30 Hz). The clock is host-authoritative and rides the reliable state-change channel once per second rather than in every snapshot. Sudden Death entry is a reliable event. |
| **MatchConfig** | Three new variants (Rule 9, Rule 16). Follows exactly the `blade_wave_enabled` precedent from DEV-005: default off, persisted to `user://match_config.cfg`, surfaced on the Fight Setup screen. |
| **Audio** (`audio.gd`) | New SFX keys: `temper_up`, `blade_hot`, `kiln`, `clock_tick`, `sudden_death`. All fall back to procedural beeps until real audio is dropped into `audio/sfx/`, per the existing drop-in override. |
| **Bot** (`bot_logic.gd`) | Must value a tempered blade above a cold one when choosing a retrieval target, must not attempt to guard a piercing blade, and must treat a `HOT_LOOSE` blade as a moving hazard to avoid. Untuned bots will read as noticeably weaker once this ships. |
| **Maps** (`maps.gd`) | No change. `crumble_platforms` and the hot phase interact naturally: a hot blade can ricochet off a platform that then crumbles beneath a fighter. No special-casing. |

---

## Formulas

### Formula 1: Temper gain on clash

```
on clash(a, b):
    if not MatchConfig.kintsugi_enabled: return legacy_ricochet(a, b)
    a.temper = min(a.temper + 1, TEMPER_MAX)
    b.temper = min(b.temper + 1, TEMPER_MAX)
    # ricochet vectors unchanged from today
    a._clash_cooldown_until = t + CLASH_COOLDOWN_S   # 0.25, unchanged
    b._clash_cooldown_until = t + CLASH_COOLDOWN_S
```

**Note:** `ricocheted` is no longer set. The flag is retained in the codebase only for the
`kintsugi_enabled == false` path.

### Formula 2: Flight speed by temper

```
speed_multiplier(temper) = 1.0 + TEMPER_SPEED_STEP * temper
```

With `TEMPER_SPEED_STEP = 0.133`: T0 ×1.00, T1 ×1.13, T2 ×1.27, T3 ×1.40. Applied to the blade's
speed at the moment temper changes, preserving direction. Base `shuriken_throw_velocity` (648)
and `FLIGHT_TIME_SCALE` (0.4725) are unchanged — a T3 blade is 40 % faster than today's blade,
not 40 % faster than some new baseline.

### Formula 3: Cooling

```
every physics tick, for each shuriken s:
    if s.stuck and s.temper > 0 and not kiln_active:
        s.cool_accum += delta
        if s.cool_accum >= COOL_INTERVAL_S:
            s.temper -= 1
            s.cool_accum = 0
    else if not s.stuck:
        s.cool_accum = 0        # airborne and stashed blades do not cool
```

### Formula 4: Hot phase

```
on terrain_contact(s):
    if s.temper < TEMPER_MAX or not MatchConfig.kintsugi_enabled:
        stick(s)                                    # today's behaviour
    else if s.hot_until == 0:                       # first contact — go hot
        s.hot_until = t + HOT_DURATION_S
        s.hot_self_immune_until = t + HOT_SELF_IMMUNITY_S
        reflect(s, surface_normal)                  # keep speed
    else if t < s.hot_until:
        reflect(s, surface_normal)
    else:
        s.temper = 0; s.hot_until = 0; stick(s)
```

### Formula 5: Round winner at clock expiry

```
on clock_expired():
    living = [p for p in players if p.alive]
    if living.size() <= 1: return            # normal elimination path already handled it
    best = max(p.hp for p in living)
    leaders = [p for p in living if p.hp == best]
    if leaders.size() == 1:
        Combat.award_survivor(leaders[0].slot)
        → State.ROUND_END
    else if MatchConfig.sudden_death_enabled:
        → enter_sudden_death(leaders)
    else:
        → State.ROUND_END with no score (draw)
```

### Formula 6: Sudden Death entry

```
enter_sudden_death(leaders):
    for p in players:
        if p in leaders: p.hp = 1
        else if p.alive: eliminate(p, killer_slot = 0)   # no kill credit
    for s in stuck_shurikens: s.temper = TEMPER_MAX
    clock = SUDDEN_DEATH_TIME_S
    kiln_active = true
```

---

## Edge Cases

| Case | Resolution | Rationale |
|---|---|---|
| Clash between two T3 blades | Ricochet and spark as normal; no temper granted (already capped) | Cap must not be silently exceeded |
| Blade deflected by katana while already T3 | Temper stays 3; ownership still transfers to the deflector | Ownership transfer is the point of the interaction |
| T3 blade caught mid-air by a dodge | Enters the catcher's stash at temper 3; the hot phase never begins | Catching is the skilled answer and should be rewarded fully |
| Hot blade strikes its own thrower inside `HOT_SELF_IMMUNITY_S` | No damage; blade continues | Prevents an instant self-kill on a point-blank miss |
| Hot blade strikes its own thrower after that window | Full damage, kill credited to `slot 0` (no killer) | The gamble in Rule 5 is the entire point; crediting the victim their own kill would inflate the score |
| Hot blade still loose when the round ends | Freed with all other projectiles by the existing round-end cleanup | No new lifecycle |
| Hot blade loose when Sudden Death begins | Retains its remaining hot timer; not reset | Continuity — the arena does not pause mid-hazard |
| Stash is full (5) and a blade is caught | Existing deflect-instead-of-catch behaviour applies unchanged; the deflected blade gains temper per Rule 3 | Consistent with Rule 3 |
| `MatchConfig.max_hp == 1` | Every survivor tie at expiry is a 1-heart tie → Sudden Death fires immediately with hp already 1 | Degenerate but well-defined; Sudden Death still resolves by elimination |
| `MatchConfig.shurikens_enabled == false` | No blades exist; temper and the Kiln are inert; the clock still runs and resolves on hearts | Katana-only variant must remain playable |
| `MatchConfig.infinite_shurikens == true` | Thrown blades still carry temper, but the stash never depletes, so hoarding a hot blade costs nothing | Flagged in Open Questions as a balance interaction to playtest |
| Clock expiry on the same tick as a lethal hit | The elimination path wins: `_on_kill_logged` already transitions to `ROUND_END`, and the clock checks `current_state == State.ROUND` before firing | Preserves today's signal-order determinism |
| Pause during a round, offline | `get_tree().paused` freezes the clock with everything else | Existing pause semantics |
| Pause during a round, online | The tree is **not** paused online (`pause_menu` mutes local input via `PlayerInput.suppress_local`), so the clock keeps running | Documented deliberately — pausing the clock would let one player stall an online match |
| Client/host clock disagreement | Client renders the host's last received value; the host alone decides expiry | Host authority per ADR-0003 |
| Draw round (Sudden Death expiry) | No score change; `_round_winner_slot = 0`; the existing double-KO display path is reused | Double-KO already produces a winner-less round end |

---

## Dependencies

| System | Relationship |
|---|---|
| `projectile.md` / `shuriken.gd` | **Owns temper.** This document extends the Projectile system; conflicts resolve in favour of Projectile for physics, this doc for value. |
| `combat.md` / `combat.gd` | Consumes `award_survivor`. Combat Rule 11/12 (stash refill, projectile cleanup) must additionally reset temper — see Rule 8. |
| `movement.md` / `player.gd` | Guard-piercing changes `_blocks_incoming`. Dodge-catch unchanged. |
| `round-flow.md` | **Superseded in part.** Rule 148 ("no round-time cap") and the `STALEMATE_BEHAVIOR` knob are resolved by System B. Note that `round-flow.md` describes a `RoundFlow` autoload that does not exist in the shipped build — round flow lives in `main.gd`. That discrepancy predates this document and should be reconciled separately. |
| `ADR-0001` (input/state separation) | No impact. Temper is simulation state, not input. |
| `ADR-0003` (online multiplayer) | Direct impact — new replicated fields and a host-authoritative clock. |
| `game-concept.md` Pillar 2 / anti-pillars | **Compatible.** All fighters have mechanically identical tools; temper is a property of world state earned in play, never of a clan or a menu selection. This is explicitly *not* an asymmetric ability. |

---

## Tuning Knobs

| Knob | Default | Range | Affects | Rationale |
|---|---|---|---|---|
| `kintsugi_enabled` | `false` | bool | Whole of System A | Ships off, like `blade_wave_enabled`; flipped on after playtest |
| `TEMPER_MAX` | `3` | 2–5 | Escalation ceiling and pacing | 3 gives three visibly distinct states without a legibility problem |
| `TEMPER_SPEED_STEP` | `0.133` | 0.05–0.25 | Reaction time against a hot blade | ×1.40 at T3 — fast enough to matter, inside dodge-reaction range |
| `GUARD_PIERCE_TEMPER` | `2` | 1–3 (or 99 = never) | How quickly guard stops answering | At 2, one clash is not enough to break the guard economy |
| `COOL_INTERVAL_S` | `6.0` | 2.0–15.0 | Anti-camping pressure | A full T3 → T0 decay takes 18 s of nobody engaging |
| `HOT_DURATION_S` | `3.0` | 1.0–6.0 | Severity of the T3 miss penalty | Long enough for one or two screen-wrap passes |
| `HOT_SELF_IMMUNITY_S` | `0.5` | 0.083–1.5 | Self-kill fairness on a point-blank miss | Distinct from `self_hit_immunity_s` (0.083), which is for the throw itself |
| `round_time_s` | `60.0` | `0` = off, 30–180 | Round pacing | Per brief |
| `KILN_TIME_S` | `15.0` | 5.0–30.0 | Length of the escalated endgame | A quarter of a default round |
| `sudden_death_enabled` | `true` | bool | Heart-tie resolution | Off = draw round instead |
| `SUDDEN_DEATH_TIME_S` | `20.0` | 10.0–60.0 | Overtime length | Short — one heart each resolves fast |

---

## Acceptance Criteria

### Temper accrual (unit-testable, no autoloads required)
- [ ] A clash between two temper-0 blades leaves both at temper 1.
- [ ] A clash where one blade is already at `TEMPER_MAX` leaves that blade at `TEMPER_MAX` and raises the other by 1.
- [ ] A clash between two `TEMPER_MAX` blades changes neither temper.
- [ ] `deflect(by_slot, ...)` raises temper by 1 and sets `thrower_slot = by_slot`.
- [ ] With `kintsugi_enabled == false`, a clash sets `ricocheted = true` and leaves temper at 0 — today's behaviour is bit-for-bit preserved.

### Temper effects
- [ ] `speed_multiplier(0..3)` returns 1.00 / 1.13 / 1.27 / 1.40 within 0.005.
- [ ] A blade at `temper >= GUARD_PIERCE_TEMPER` is not blocked by a raised guard; a blade below it is.
- [ ] A dodge-catch succeeds at every temper level, including 3.
- [ ] Damage is exactly 1 heart at every temper level.

### Cooling
- [ ] A stuck temper-3 blade reaches temper 0 after `3 × COOL_INTERVAL_S` and no sooner.
- [ ] A blade held in a stash does not lose temper over 60 s of held time.
- [ ] An airborne blade does not cool.
- [ ] No cooling occurs while `kiln_active`.

### Hot phase
- [ ] A temper-3 blade striking terrain reflects and does not stick.
- [ ] It damages a non-thrower on contact during the hot phase.
- [ ] It does not damage its thrower within `HOT_SELF_IMMUNITY_S`, and does after.
- [ ] After `HOT_DURATION_S` it is temper 0, stuck, and retrievable.
- [ ] It cannot be picked up off the ground while hot, but can be caught or deflected.

### Round clock
- [ ] The clock starts at `round_time_s` when the countdown completes, not at `MATCH_INTRO`.
- [ ] The readout shows whole seconds and turns gold at exactly `KILN_TIME_S`.
- [ ] `round_time_s == 0` disables the clock and no readout is drawn.
- [ ] Every stuck blade gains exactly 1 temper at the Kiln threshold, once.
- [ ] An elimination during the final second ends the round by elimination, not by clock.

### Expiry resolution
- [ ] Two alive, hearts 4 vs 2 → round awarded to the 4-heart fighter, score +1, no kill credited.
- [ ] Two alive, hearts 3 vs 3, `sudden_death_enabled` → both set to 1 heart, all stuck blades at `TEMPER_MAX`, clock = `SUDDEN_DEATH_TIME_S`.
- [ ] Two alive, hearts 3 vs 3, `sudden_death_enabled == false` → round ends, no score awarded.
- [ ] FFA, hearts 5 / 5 / 2 / 1 → the two leaders enter Sudden Death, the other two are eliminated without kill credit.
- [ ] Sudden Death expiring with two alive awards no score and starts the next round.

### Online (ADR-0003)
- [ ] Temper and hot state replicate; a client renders a gold blade as gold within one snapshot.
- [ ] The host alone resolves expiry and Sudden Death; the client never does.
- [ ] The clock continues to run on both sides while an online pause overlay is open.
- [ ] Snapshot size grows by no more than 2 bytes per blade.

### Integration
- [ ] A full match can be played start to finish with both toggles off and is byte-identical in behaviour to today's build.
- [ ] `--online-autotest` completes with both toggles on.
- [ ] A boot smoke test (`--headless --quit-after 120`) produces no script errors with both toggles on.

---

## Open Questions

1. **Heart tie-break alternative.** Rule 14 chooses Sudden Death. The quieter option is to break
   the tie on **total temper held in stash**, rewarding the player who contested more, and only
   fall through to a draw if that is also level. Cheaper, less dramatic, no overtime. Worth an
   A/B once both are playable.
2. **`infinite_shurikens` interaction.** With infinite ammunition there is no cost to sitting on
   a hot blade. Options: force cooling in-stash when the variant is on, or accept it as a
   deliberately silly variant. Needs play, not theory.
3. **Should the Kiln flare also reach blades held in stashes?** Currently arena-only, which
   rewards the player who has been retrieving rather than hoarding. The opposite choice is
   defensible.
4. **Bot competence.** Rule interactions make the current bot measurably worse. Whether
   `bot_logic.gd` is updated in the same change or immediately after determines whether the
   feature can ship enabled by default.
5. **Splitting this document.** Systems A and B ship independently; if both survive playtest,
   System B may be better folded into a rewritten `round-flow.md` that matches the shipped
   `main.gd` rather than the abandoned `RoundFlow` autoload design.

---

## Originality Note

The base game names TowerFall as its touchstone, so this document names its own. **An object that
becomes more dangerous the more it is volleyed is not unprecedented** — the nearest relatives are
*Lethal League* (a ball that accelerates with every hit and kills whoever it touches) and
*Windjammers*. Anyone comparing will compare to those.

What is different here: there are **many blades, not one ball**; they are **carried ammunition**
with a stash, not a single field object; temper is about **transfer of ownership and decay**
rather than raw speed; and the miss penalty (Rule 5) has no equivalent in either game. The
kintsugi framing — that the break is where the gold goes — is ours, and it is already in the
soundtrack.

The deliberate design guard against plagiarism is Rule 4's prohibition on damage scaling and the
absence of any container that *grants* power. Power here is never given by the world; it is
produced by conflict between players. That is what makes it this game's mechanic rather than a
reskin of a chest.
