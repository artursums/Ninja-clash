# DEV-002: AI enemy behavior rework — full toolkit, environment use, last-resort head-stomp

**Status:** 🔵 Backlog   **Priority:** P1   **Area:** AI / gameplay
**Created:** 2026-05-28

## Idea (raw)
> next task oleks seadistada AI vaenlast, kuan hetkel ta ei arvesta kogu võimalike
> funktsionaalsustega. Aga selles taskis tuleb mainida, et pc-l poleks vajadust
> hüpata pea peale reaalsele vastasele ainult juhul kui tal on shurikenid ja katana
> löögid otsas. Aga ta peaks oskama kasutama keskkonda effektiivselt, et reaalsest
> mängijast jagu saada. AI käitumine tuleb väga hästi läbi töödelda.

(Translation for context: "The next task is to set up the AI enemy, because right now
it doesn't account for all the possible functionalities. But this task must mention
that the computer should NOT need to head-stomp the real opponent EXCEPT only in the
case when it has run out of shurikens and katana charges. But it should know how to use
the environment effectively to beat a real player. The AI behavior must be very
thoroughly worked out.")

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
Thoroughly rework the enemy (bot) AI in the production game (`ninja_clash/`) so it
fights like a smart human: it uses the **full mechanical toolkit** the game offers (not
just shuriken-throwing + occasional katana), it **uses the level environment
effectively** (high ground, walls, cover, gaps) to beat a real player, and it treats
**head-stomping the opponent as a strict last resort** — the bot should only pursue a
head-stomp when it has run out of BOTH shurikens AND katana charges (and has no loose
shuriken worth retrieving). This is a careful, well-structured behavior pass, not a
quick patch — the AI behavior must be very thoroughly designed.

### Context
The production game lives entirely in `ninja_clash/` (Godot 4.6 2D couch-PvP arena
fighter; the `src/` tree is archived — see memory `reference_production_project_setup`).

**Where the AI lives.** Bot behavior is a single large function `_bot_think(t)` in
`ninja_clash/player.gd` (≈ lines 699–971). Players are `CharacterBody2D` nodes running
the same script; a fighter is a bot when `is_bot` is true. Bots drive themselves by
edge-setting/holding fake inputs in `_bot_pressed` / `_bot_held`, which the shared
`_pressed()`/`_held()` helpers read instead of real input. Difficulty is
`bot_difficulty` (1 GENIN / 2 CHUNIN / 3 JONIN); `game_state.gd` sets which slots are
bots (`slot_is_bot`) and the difficulty. The AI deliberately models human feel:
reaction lag before answering a new threat, capped dodge reliability (even JONIN lets
~20% of throws through), per-action cooldowns, and per-tier knobs for fire rate,
spacing, aggression, dash/parry chances.

**What the AI already uses well:** shuriken throws (full 8-way aim, leads a moving
target), katana parry of incoming shurikens, katana clash vs the foe's blade, dodge
(i-frames), katana duels with deliberate windup/recovery pacing, wall-jump climbing
toward a higher foe, ground + air dashes (`input_slide`), opportunistic blade pickup
when `stash < 5`, edge-guard via a short ground-ahead raycast (`_bot_ground_ahead`),
and "out of shurikens → hunt with the blade / scavenge dropped blades."

**What it does NOT use (the "doesn't account for all functionality" gap):**
- **Head-stomp.** `_check_headstomp()` (≈ line 1338) hard-returns when `is_bot`
  (line 1344: "The AI never head-stomps"), so the bot never stomps at all — not even
  incidentally, despite a contradictory comment at ≈ line 861 claiming incidental
  stomps can still happen. The documented design intent (≈ lines 826-827: "head-stomp
  when we don't [have a charge]") was never wired up. This task implements it, gated.
- **Guard / block.** The defend mechanic (`input_defend`, `is_defending`, the guard
  meter) lets a fighter plant the katana to block front shurikens & strikes. The bot
  never presses `input_defend`. A smart bot should block when cornered with no dodge
  ready / facing a wall of fire.
- **Environment beyond ledges.** It only reasons about "is there floor one step ahead."
  It does not seek high ground, use walls/platforms as cover to break the player's
  shuriken line-of-fire, bait the player over gaps, or deny the player's blade
  retrieval. Level geometry comes from `maps.gd` / `decorations.gd`.
- Down-throw as a mobility/pressure tool and shuriken-pogo bounce (`shuriken_pogo`,
  `SHURIKEN_POGO_BOUNCE`) — minor, evaluate whether worth using.

### The hard rule (head-stomp = last resort)
A human only resorts to risky head-stomping when disarmed. Encode exactly that:

- The bot may **deliberately pursue / set up a head-stomp ONLY when**
  `stash <= 0` AND `katana_charges <= 0` AND there is no reachable loose shuriken worth
  scavenging (reuse `_bot_nearest_stuck_shuriken()` / the existing scavenge gate).
- While it still has shurikens or any katana charge, it must **never** path toward
  landing on the opponent's head as an attack. (Incidental same-frame landings are
  fine — just don't *aim* for them.)
- `_check_headstomp()` currently disables stomps for all bots. Change it so a bot CAN
  execute a stomp, but only consistent with the gate above — and update the now-false
  comments at ≈ line 861 and ≈ line 1342 to match the new behavior.

### Relevant files
- `ninja_clash/player.gd` — `_bot_think()` (≈ 699), the bot helpers
  (`_bot_nearest_enemy`, `_bot_incoming_shuriken`, `_bot_nearest_stuck_shuriken`,
  `_bot_ground_ahead` ≈ 973), `_check_headstomp()` (≈ 1338), `hit_by_stomp()` (≈ 1328),
  and the per-tier knob tables at the top of `_bot_think`. This is the core of the task.
- `ninja_clash/game_state.gd` — `DIFFICULTY_NAMES`, `ai_difficulty`, `slot_is_bot`,
  `num_players` (FFA = 1 human + 3 bots, so bot-vs-bot targeting must keep working).
- `ninja_clash/maps.gd` + `ninja_clash/decorations.gd` — level geometry / platform &
  wall layout the AI should reason about for "use the environment." Inspect what data
  is available (platform rects, wall positions, spawn points) to drive high-ground and
  cover logic; add lightweight queries if needed rather than per-frame heavy scans.
- `ninja_clash/combat.gd` — `Combat` autoload: clash registration, self-hit immunity,
  live-tunable combat params the AI interacts with.
- `ninja_clash/shuriken.gd` — projectile (`stuck`, `thrower_slot`, `velocity_v`,
  groups) used by the incoming-threat and scavenge queries.
- `ninja_clash/player_tuning.gd` / `player_tuning.tres` — keep all balance numbers
  data-driven; AI knobs that affect feel should live as named values, not magic numbers.

### Requirements
1. **Last-resort head-stomp** exactly as specified in "The hard rule" above: gated on
   `stash <= 0 && katana_charges <= 0 && no scavengeable blade`; implement deliberate
   pursuit (close in, jump to land on the foe's head) only under that gate; relax the
   `is_bot` block in `_check_headstomp()` accordingly; fix the misleading comments.
2. **Use the full toolkit.** Add the missing tools the bot ignores:
   - **Guard/block** (`input_defend`): block when it's the best survival option (e.g.
     cornered, dodge on cooldown, multiple incoming throws) — respecting the guard
     meter so it doesn't over-commit.
   - Evaluate and, where it improves play, use **down-throw** and **shuriken-pogo**.
   - Keep existing tools (dodge, parry, clash, dashes, wall-climb, pickup) and make
     their selection coherent within one decision model rather than ad-hoc checks.
3. **Use the environment effectively.** The bot should actively exploit geometry:
   contest **high ground**, use **walls/platforms as cover** to break the player's
   shuriken line-of-fire, **deny the player's blade retrieval**, and **bait** the
   player toward gaps/edges — all without ever walking itself off a ledge (preserve the
   edge-guard). Use level data from `maps.gd`/`decorations.gd`; prefer cheap geometry
   queries (raycasts / cached rects) over per-frame brute force.
4. **Difficulty tiers.** Preserve the GENIN/CHUNIN/JONIN model and the human-feel layer
   (reaction lag, capped dodge success, error/jitter). The richer toolkit and
   environment awareness should scale with tier — GENIN uses the basics with clear
   tells; JONIN reads the player and uses cover/high-ground tightly — but JONIN must
   still feel *fair*, not frame-perfect-unbeatable.
5. **Structure it well (thorough design).** `_bot_think` is already a long monolith;
   refactor toward a clear, documented decision model (priority/utility selection or a
   small behavior tree) so each behavior (survive threat → block/dodge/parry; rearm;
   melee duel; spacing/positioning; last-resort stomp) is legible and tunable. Consider
   extracting bot logic into its own module/class to keep `player.gd` focused. Keep all
   feel knobs data-driven.

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`); training data
  predates 4.4–4.6 — cross-check unfamiliar APIs there.
- Follow CLAUDE.md: ask before writing files, keep tuning data-driven (no new magic
  numbers — name them), match existing conventions/style in `ninja_clash/` (typed
  GDScript, snake_case, the `_bot_pressed`/`_bot_held` input pattern).
- Preserve the "beatable by a human" principle: the AI should feel smart and fair, not
  cheat (no perfect reactions, no reading inputs the player can't see). Keep the
  reaction-lag + capped-success + error model.
- Must keep working in all modes that use bots: HUMAN_VS_AI, AI_VS_AI, and FFA (1 human
  + 3 bots) — bots target the nearest live enemy via `_bot_nearest_enemy()`.
- Performance: bot thinking runs every physics tick for up to 4 fighters at 60 fps;
  keep environment queries cheap (the 16.6 ms frame budget in technical-preferences.md).
- Consider delegating the implementation to the `ai-programmer` agent.

### Assumptions
- "Run out of shurikens and katana charges" = `stash <= 0` AND `katana_charges <= 0`
  (the runtime fields in `player.gd`); a reachable loose shuriken means re-arming, so
  the bot prefers scavenging over a desperation stomp.
- "Use the environment" targets the existing 2D platform/wall geometry; no new
  navmesh/pathfinding system is required (ray + geometry reasoning is enough for these
  arena sizes).
- Difficulty tiers and the human-feel model are kept; this task enriches behavior, it
  does not remove the deliberate imperfection that makes bots beatable.

### Acceptance criteria
- [ ] While the bot has any shuriken OR any katana charge (and/or a scavengeable
      blade), it **never initiates** a head-stomp — verified by watching/logging that
      `_check_headstomp` only credits a bot stomp when the gate holds.
- [ ] When the bot is fully disarmed (no shurikens, no katana charges, no reachable
      loose blade), it **does** deliberately pursue and execute head-stomps.
- [ ] The bot demonstrably uses the guard/block (`input_defend`) in appropriate
      situations (e.g. cornered under fire with no dodge ready).
- [ ] The bot demonstrably uses the environment: contests high ground and/or uses a
      wall/platform as cover to break the player's shuriken line — observable in a
      playtest, not just code.
- [ ] GENIN / CHUNIN / JONIN remain clearly distinct; JONIN is hard but a skilled human
      can still beat it (it does not react with impossible precision).
- [ ] Bots still function in HUMAN_VS_AI, AI_VS_AI, and FFA without regressions
      (no walking off ledges, no freezing, no machine-gunning).
- [ ] Misleading comments at ≈ player.gd:861 and ≈ player.gd:1342 are corrected.
- [ ] Project parses/imports headless clean (see `reference_godot_headless_verify`);
      any extracted bot module is covered by GUT tests where logic is pure-testable.

### Out of scope
- New player-facing mechanics or abilities (only the AI changes; it uses existing moves).
- Networked/online AI sync.
- A full navmesh/pathfinding system (keep geometry reasoning lightweight).
- Rebalancing core combat numbers (shuriken damage, HP, katana timing) beyond AI knobs.
- The pre-match variants menu (that is DEV-001) — though if DEV-001 ships first, the AI
  should respect a disabled katana/shuriken by treating that tool as unavailable.
