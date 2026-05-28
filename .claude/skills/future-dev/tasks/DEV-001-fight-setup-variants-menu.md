# DEV-001: Pre-match Fight Setup / Variants menu (TowerFall-style)

**Status:** 🔵 Backlog   **Priority:** P2   **Area:** systems / UI / gameplay
**Created:** 2026-05-28

## Idea (raw)
> tuelvikus on vaja ehitada funktionaalsus nupu näol character select menüüs, mille
> peale vajutades saan mugavalt configureeirda leveli fighti, nt eemaldada katana,
> väljalõlitada katana cooldown (et kui bar tühjeneb, siis ei taastu enam) või, et
> oleks ilma shurikenita, või ise otsustada, mitu shurikeni. Towerfallis on sama
> funkstionaalsus olemas. Te enagu seal. Mõtle ka minu eest, mis ja kuidas antud
> mängu funktsionaalussega arvestades saaks veel configureerida sellisel moel

(Translation for context: "I need a button in the character-select menu that opens a
screen where I can conveniently configure the level's fight — e.g. remove the katana,
turn off katana recharge (so once the bar empties it never comes back), play with no
shurikens, or decide how many shurikens. TowerFall has this exact feature. Do it like
there. Also think for me about what else could be configured this way given this
game's mechanics.")

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
Add a **Fight Setup / Variants** screen to the production game (`ninja_clash/`),
reachable from a button on the clan/character-select screen. It lets the player
toggle and tune the rules of the upcoming match before fighters lock in — TowerFall's
"Variants" menu is the reference. Variants are **global** (one ruleset for all
fighters this match) and **persist to disk** so a configured ruleset survives
relaunches. The goal is player-facing replay variety: silly/hardcore custom matches
(no katana, finite katana, 1 shuriken, etc.) without code edits.

### Context
The production game lives entirely in `ninja_clash/` (the `src/` tree is archived —
see memory `reference_production_project_setup`). It is a Godot 4.6 2D couch-PvP
arena fighter. Screen flow is a state machine in `game_state.gd`
(`GameState` autoload): TITLE → MODE_SELECT → CLAN_SELECT → MAP_SELECT →
MATCH_INTRO → ROUND → ROUND_END → MATCH_END. Each screen is a `Control` built in code
and shown/hidden by `main.gd` reacting to `GameState.state_changed`.

Today there is **no match-config layer**. A fighter's per-round loadout is hardcoded
in `player.gd` `respawn()`:

```gdscript
stash = 3                 # shurikens
hp = MAX_HP               # 5
katana_charges = MAX_KATANA   # 3
```

Balance numbers already flow through a data-driven resource:
`player_tuning.tres` → `PlayerTuning` (`player_tuning.gd`) → `player.gd._apply_tuning()`
copies them into runtime fields (`MAX_KATANA`, `MAX_HP`, throw speeds, etc.). The
katana already does NOT recharge mid-round — once all 3 charges are spent it is locked
out until the next respawn (`player.gd` ~line 499-501). So "turn off katana recharge"
in the idea means: make charges finite for the **whole match** (do not refill them on
respawn), as a toggle, distinct from today's per-round refill.

Autoload singletons follow a clear pattern (`GameState`, `Combat`, `Audio`,
`Settings`). The new config should be a sibling autoload (e.g. `MatchConfig`).
Persistence should mirror `settings_store.gd` (`Settings` autoload): a section in
`user://settings.cfg`, load+apply on boot, save on change, with clamping — and that
file already has unit-tested pure load/save (see `tests/` GUT harness in
`reference_production_project_setup`).

The clan-select screen (`clan_select.gd`, `GameState.State.CLAN_SELECT`) is where the
entry button goes. P1 navigates with `p1_left`/`p1_right`/`p1_jump` (confirm) /
`p1_aim_down` (back) / `p1_skin`; `menu_cancel` exits to MODE_SELECT. Reuse these
input actions for the variants screen so it feels native. In FFA mode only P1 picks;
keep the variants screen P1-controlled too.

### Relevant files
- `ninja_clash/clan_select.gd` — character-select screen; add the "FIGHT SETUP" /
  "VARIANTS" entry button here and route into the new screen. Study `_process()`
  input handling and `_build()`/`_refresh()` UI construction to match the style.
- `ninja_clash/game_state.gd` — add a new `State` (e.g. `MATCH_SETUP`) if using a
  dedicated screen, or keep it as an overlay. `target_score` (rounds to win, default 5)
  lives here and should be surfaced as a variant.
- `ninja_clash/main.gd` — instantiates every screen via
  `load("res://<screen>.gd")` and shows/hides on `state_changed`; register the new
  screen + the new `MatchConfig` autoload here (or in `project.godot` autoloads).
- `ninja_clash/player.gd` — `respawn()` (~line 1390) sets `stash`/`hp`/`katana_charges`;
  `_apply_tuning()` (~line 208); katana fire gate (~line 501) and throw input
  (~line 342/360). This is where variants must take effect at round start and gate
  inputs.
- `ninja_clash/player_tuning.gd` + `player_tuning.tres` — existing data-driven tuning;
  the variant defaults (start shuriken count, katana charge count, max HP) should read
  from here so nothing is hardcoded.
- `ninja_clash/settings_store.gd` — copy this pattern for `MatchConfig` persistence to
  `user://settings.cfg`.
- `ninja_clash/combat.gd` — `Combat` autoload holds live-tunable combat params (clash,
  self-hit immunity, etc.); some variants (e.g. disable clash) toggle behavior wired
  through here.
- `ninja_clash/tuning_panel.gd` — the in-round live-tuning panel; a precedent for a
  simple list-of-controls UI you can borrow from (sliders/steppers).

### Requirements
1. Add a clearly labeled entry on the clan-select screen (e.g. a "FIGHT SETUP" button
   or a `p1_skin`-style cycle prompt) that opens the variants screen, and a way back
   to clan-select. Do not block the normal lock-in flow when the player ignores it.
2. Build a `MatchConfig` autoload holding the variant state, defaulting every value to
   today's standard behavior (so an untouched config plays exactly as the game does
   now). Read numeric defaults (start shurikens, katana charges, max HP, target score)
   from `PlayerTuning`/`GameState` rather than re-hardcoding them.
3. Implement at minimum the variants the user named:
   - **Katana: ON / OFF** — OFF removes the katana entirely (no charges, swing input
     is a no-op, no katana HUD marks).
   - **Katana recharge: PER-ROUND (default) / NEVER** — NEVER = charges are granted at
     match start only and are not refilled on respawn (finite for the whole match).
   - **Shurikens: ON / OFF** — OFF starts with 0 and disables throwing.
   - **Starting shuriken count** — integer stepper, 0..5 (default 3, the
     `PlayerTuning`/stash max).
4. Wire `player.gd` to honor the config: `respawn()` sets `stash`/`katana_charges` from
   `MatchConfig`; the katana fire gate and throw input check the enabled flags; finite
   katana skips the respawn refill (grant only on the match's first spawn). Keep HUD
   icon rows (`stash_icons`, `katana_icons`) consistent with the active config.
5. Persist the config to `user://settings.cfg` (own section) using the
   `settings_store.gd` pattern: load+apply on boot, save on change, clamp on load.
   Include a **RESET TO DEFAULTS** action on the screen.
6. The screen is keyboard/controller navigable using the existing menu input actions,
   with audio feedback (`Audio.play("click"/"confirm")`) consistent with other menus.

### Suggested additional variants (the "think for me" ask)
Curated to this game's actual mechanics — implement the high-value ones and leave the
rest as documented stretch toggles. Group them in the UI.

- **Weapons**
  - Infinite shurikens (never deplete on throw).
  - Katana charge count (0..N stepper) — independent of the ON/OFF and recharge knobs.
- **Combat feel**
  - Hits to kill / max HP (stepper) — surfaces existing `MAX_HP`.
  - Dodge i-frames ON/OFF (uses `Combat.dodge_iframe_duration_s`).
  - Guard / block ON/OFF (the defend/guard meter mechanic in `player.gd`).
  - Head-stomp kills ON/OFF (the stomp-bounce mechanic).
  - Wall-jump ON/OFF.
  - Katana clash ON/OFF (`combat.gd` `register_clash`/`clash_occurred`).
  - Friendly fire / self-hit toggle (`Combat.self_hit_immunity_s`).
- **Match**
  - Rounds to win (`GameState.target_score`) stepper — natural fit for this screen.
- **Movement (fun/stretch)**
  - Low gravity, fast match (move speed multiplier) — TowerFall-style silly modes;
    drive off `PlayerTuning.gravity`/`max_hspeed` so they stay data-driven.

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`); the LLM's
  training data predates 4.4–4.6, so cross-check any unfamiliar API there.
- Follow CLAUDE.md: ask before writing files, keep gameplay values data-driven (no new
  hardcoded tuning — read from `PlayerTuning`/`GameState`/`Combat`), match existing
  conventions and code style in `ninja_clash/` (typed GDScript, snake_case fields,
  in-code UI construction, autoload pattern).
- Variants are **global** for the match (not per-player) for this task.
- Defaults must reproduce current behavior exactly so existing matches are unaffected.
- Add GUT unit tests for the pure parts (config load/save/clamp, and that
  default config yields today's loadout), mirroring how `SettingsStore` is tested.

### Assumptions
- "Character select menu" = `clan_select.gd` (the clan/character pick screen).
- "Turn off katana cooldown so the bar doesn't recover" = the finite/NEVER-recharge
  variant described in Requirement 3, not removal of the per-swing cooldown gate.
- A new dedicated screen state (`MATCH_SETUP`) is preferred over an in-place overlay,
  but either is acceptable if it keeps `clan_select.gd` clean.
- The screen is P1-controlled (consistent with FFA pick flow).

### Acceptance criteria
- [ ] From clan-select, a visible button/prompt opens the Fight Setup screen and
      returns cleanly without disturbing clan lock-in.
- [ ] Toggling **Katana OFF** → fighters spawn with no katana, swing input does
      nothing, no katana HUD marks; a round plays normally with shurikens only.
- [ ] **Katana recharge NEVER** → charges spent in round 1 are gone for the rest of
      the match (not refilled on respawn); PER-ROUND restores current behavior.
- [ ] **Shurikens OFF** → fighters spawn with 0 shurikens and cannot throw.
- [ ] **Starting shuriken count = N** → each fighter spawns with exactly N shurikens.
- [ ] Config persists across an app relaunch; **RESET TO DEFAULTS** restores standard
      rules.
- [ ] Untouched config plays identically to the current build (regression check).
- [ ] `MatchConfig` registered as an autoload; GUT tests cover load/save/clamp and the
      default-equals-current-loadout invariant; project parses headless clean
      (see `reference_godot_headless_verify`).

### Out of scope
- Per-player / asymmetric variants (each fighter a different ruleset).
- Online/networked sync of the config.
- New art/sprite assets — reuse existing menu UI styling and fonts.
- Reworking how katana/shuriken mechanics fundamentally behave beyond gating/counting.
