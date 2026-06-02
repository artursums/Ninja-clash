# DEV-006: Pre-round controls / tutorial modal (TowerFall-style button legend)

**Status:** 🔵 Backlog   **Priority:** P2   **Area:** UI / gameplay
**Created:** 2026-05-29

## Idea (raw)
> enne iga roudni algust peaks tulema modal, millel on tutorial mis nupud teevad.
> Sama nagu towerfallis Tee selliselt.

(Translation for context: "Before each round starts there should be a modal with a
tutorial showing what the buttons do. Same as in TowerFall. Make it like that.")

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
Add a **pre-round controls modal** to the production game (`ninja_clash/`): a small overlay
shown at the start of each round, before the fight begins, that displays a **button legend /
controls tutorial** (move, jump, throw shuriken + aim, katana, guard, dodge/dash, pause), the
way TowerFall reminds players of the scheme before a match. It should read at a glance, list
both the gamepad (PlayStation/DualSense) and keyboard (P2) bindings, and not slow players who
already know the controls down — they can dismiss it / it auto-advances into the countdown.

### Context
- **Round flow.** Rounds are driven by `GameState` (`ninja_clash/game_state.gd`), state enum
  `MATCH_INTRO → ROUND → ROUND_END` (and `MATCH_END`). Entering a new round calls
  `change_state(State.MATCH_INTRO)` (`game_state.gd` ≈ 165 for round 1, ≈ 174 for later
  rounds). `is_round_active()` is true only in `State.ROUND`.
- **Countdown / intro orchestration.** `ninja_clash/main.gd` handles `MATCH_INTRO`:
  `_enter_match_intro()` (≈ 418) sets up the arena, then `_start_countdown()` (≈ 546) runs a
  staged sequence via `_advance_countdown_stage()`. Stage 0 is the **"ROUND N" banner**
  (`STAGE_DURATIONS[0] = 2.0` s; `STAGE_TEXTS`/`STAGE_SOUNDS` at ≈ 19-21), then stages 1-4 are
  the premium **3 / 2 / 1 / FIGHT!** stone sprites. The controls modal should sit at the very
  start of this flow — e.g. a new pre-countdown gate (modal up, fighters frozen, countdown
  doesn't start until it's dismissed/times out), or shown over the "ROUND N" banner stage.
- **Control scheme (source of truth).** All bindings are registered in `main.gd` (`_setup_input`
  ≈ 100, `_add_pad` ≈ 137). The legend MUST match these exactly:
  - **Move / aim:** D-pad or left stick (P2 keyboard: `A`/`D` move, `W`/`S` aim up/down).
  - **Jump:** Cross ✕ (P2: `Space`).
  - **Throw shuriken (hold to aim, release to fire):** Square ▢ (P2: `L`).
  - **Katana melee:** Triangle △ (P2: `K`).
  - **Guard (hold):** L2 (P2: `J`).
  - **Dodge / dash:** Circle ◯ / L1 / R1, and dash on R2 (P2: Right `Shift`; dash = double-tap `A`/`D`).
  - **Pause:** Start (P2: `Esc`).
- **Overlay patterns to mirror.** `ninja_clash/match_setup.gd` is a `Control`-based, pad+keyboard
  navigable full-screen menu (rows, highlight, input lockout window) — a good reference for a
  clean, self-built overlay. `ninja_clash/pause_menu.gd` and `ninja_clash/hud.gd` show how
  overlays are layered over the arena. The countdown stage banners in `main.gd` show how
  intro-phase UI is created and timed.
- **Existing button-glyph art.** Controls are referenced by face-button shape (✕ ◯ ▢ △) and L1/
  L2/R1/R2; check `ninja_clash/sprites/` for any existing controller-glyph art before drawing
  text-only. If none exists, a clean text legend (with the ✕ ◯ ▢ △ glyphs) is acceptable for v1.

### Relevant files
- `ninja_clash/main.gd` — round-intro + countdown orchestration (`_enter_match_intro` ≈ 418,
  `_start_countdown` ≈ 546, `_advance_countdown_stage` ≈ 551, `STAGE_*` ≈ 19-28). Inject the
  modal at the start of the intro flow and gate the countdown on its dismissal.
- `ninja_clash/game_state.gd` — state machine + `current_round`; check whether a dedicated
  pre-round step is cleaner than overloading `MATCH_INTRO`.
- A new `ninja_clash/controls_modal.gd` (suggested) — the overlay `Control` (legend layout,
  dismiss/auto-advance, pad+keyboard input), sibling in spirit to `match_setup.gd`.
- `ninja_clash/settings_store.gd` — if a persisted "show controls each round" preference (or a
  one-time "don't show again") is added, follow the existing settings save/load pattern.
- `ninja_clash/sprites/` — controller-glyph art, if any exists, for the legend.

### Requirements
1. **Appears before every round.** The modal shows during the round intro, before fighters can
   act, for round 1 and every subsequent round (TowerFall-style reminder, not a one-time
   tutorial). Fighters/input are frozen while it's up (reuse the existing non-`ROUND`-state
   freeze — `is_round_active()` is already false during `MATCH_INTRO`).
2. **Clear button legend.** Lists each action with its gamepad glyph (✕ ◯ ▢ △, L1/L2/R1/R2,
   D-pad/stick, Start) AND the P2 keyboard key, matching `main.gd`'s bindings exactly. Readable
   at 800×450 (the game's resolution) at a glance.
3. **Dismiss + auto-advance.** Any player can dismiss it (e.g. jump/confirm or pause-cancel) to
   start the countdown immediately; if no one dismisses, it auto-advances after a short timeout
   so a round never stalls. Then the normal "ROUND N" → 3/2/1/FIGHT countdown proceeds as today.
4. **Doesn't break the existing flow.** The 3/2/1/FIGHT countdown, round banner, audio cues, and
   `MATCH_END` transitions all still work; the modal is purely an added pre-countdown phase.
5. **Pad + keyboard navigable.** Works with a controller and the keyboard, like the other menus
   (`menu_*` actions, `p1_/p2_` actions), with an input-lockout window on open so a held button
   from the previous round doesn't insta-dismiss it (see `match_setup.gd`'s `_input_lockout_until`).

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`); cross-check `Control`/
  `CanvasLayer`/input APIs there.
- Follow CLAUDE.md: ask before writing files, keep any tuning data-driven (modal timeout,
  whether it shows every round), match existing conventions in `ninja_clash/` (typed GDScript,
  self-built `Control` overlays, the `Audio.play(...)` cue pattern).
- Don't add input latency or a stall to the start of a round — the modal must be dismissible
  instantly and have a sane auto-timeout.
- Keep it bot-safe: an AI-only match (`AI_VS_AI`) must still auto-advance past the modal.

### Assumptions
- The modal shows every round by default (matches the raw idea). A "show only on round 1" or a
  settings toggle to disable it is OPTIONAL polish — add via `settings_store.gd` if cheap,
  otherwise note it as a follow-up.
- v1 may use a text legend with the ✕ ◯ ▢ △ glyphs if no controller-glyph sprite art exists yet;
  richer glyph art can be a later pass.
- Auto-advance timeout default ≈ 2.5–3 s (a tuning knob), tuned so it doesn't drag between rounds.
- The legend reflects the CURRENT fixed bindings in `main.gd`; full rebindable controls are out
  of scope (see below).

### Acceptance criteria
- [ ] A controls/legend modal appears at the start of every round, before fighters can move,
      and the fighters are frozen while it is up.
- [ ] The legend lists move/aim, jump, throw (+aim), katana, guard, dodge/dash, and pause with
      the correct gamepad glyphs AND the P2 keyboard keys, matching `main.gd`'s bindings.
- [ ] Any player can dismiss it to start the countdown immediately; if no one does, it
      auto-advances after the timeout (no stalled round, including in `AI_VS_AI`).
- [ ] After dismissal/timeout the normal "ROUND N" → 3 / 2 / 1 / FIGHT! countdown plays exactly
      as today, with its audio cues, and the round then starts.
- [ ] An accidental held button from the previous round does not instantly skip the modal
      (input-lockout window on open).
- [ ] Project parses/imports headless clean (`reference_godot_headless_verify`); modal verified
      on screen with a screenshot per coding-standards.md.

### Out of scope
- Rebindable / remappable controls or a full options-menu controls screen (this only DISPLAYS
  the current fixed scheme).
- An interactive, step-by-step tutorial that makes the player perform each move — this is a
  static reminder/legend, like TowerFall's.
- Localizing the legend text (single-language for now).
- New controller-glyph art beyond a simple set if none already exists.
