# Couch Input

> **Status**: Approved
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-17
> **Implements Pillar**: Primary — *The Couch Is the Game*; Secondary — *Fairness Is Sacred*, *Game-Feel First*

## Overview

The Couch Input system is the input layer for Four Clans. It owns controller
detection, controller-to-player-slot assignment, button-mapping per game
context (menu vs in-match), hot-plug handling for controllers joining and
leaving mid-game, and the routing of player-intent signals to gameplay
systems. It is the only system in the game that touches Godot's raw
`InputEvent` stream — every other system consumes player intent through
typed signals or polled actions exposed by Couch Input. It is designed for
1–4 simultaneous controllers in a single shared room, and treats every
controller identically: no controller is "host," no controller has special
menu authority, and all four clan choices are reachable from any controller.

## Player Fantasy

Couch Input should disappear into the controller. When a player picks up a
controller and presses any button, they should join immediately — no menu
prompt, no "Press A to confirm controller assignment," no waiting for the
host to acknowledge them. When a friend swaps controllers mid-session
("here, you try"), the new controller should claim that slot in the same
gesture.

The button mapping should be conventional enough that anyone who has played
a 2D platform fighter can play Four Clans without instruction. Throw is the
right face button. Jump is the bottom face button. Dodge is a shoulder.
Movement is the left stick or D-pad. There are no hidden verbs, no two-button
combos, no menu nesting.

Pause is sacred — any controller, any time during a match. A pause should
land within a frame of the press, and a child accidentally bumping the pause
button should not derail a tense round (per the 1-second debounce in GSM).

This is *The Couch Is the Game* and *Fairness Is Sacred* at the input layer:
no controller is privileged, no input mapping rewards system mastery over
skill mastery, and the system never gets between four friends and the match
in front of them.

## Detailed Design

### Core Rules

1. CouchInput is a Godot autoload singleton (`CouchInput`).
2. CouchInput is the **only system** that touches Godot's raw `InputEvent` stream. All other systems consume player intent via typed signals or polled actions exposed by CouchInput.
3. Up to 4 controllers may be active simultaneously. Each connected controller is mapped to a player slot in `[1, 4]` (or unassigned).
4. **Press-any-button-to-join**: in menu-layer states, any button press from an unassigned controller claims the next free slot.
5. **Slot persistence:**
   - Non-match states (Boot, MainMenu, MatchSetup, MatchEnd): disconnect releases the slot immediately.
   - InMatch: disconnect holds the slot. Player is eliminated for the current round. Reconnect (any device) reclaims the lowest-numbered Reserved slot for the next round (see Tuning Knob `SLOT_RECONNECT_PRIORITY_MODE` for configurable behavior).
   - Paused: disconnect holds the slot. Reconnect resumes.
6. **Forced clan uniqueness**: two slots cannot claim the same clan in MatchSetup (TowerFall parity).
7. CouchInput emits **typed signals for unambiguous verbs**: `throw_pressed(slot)`, `pause_requested(controller_id)`, `menu_confirm(slot)`, `menu_cancel(slot)`, `menu_direction(slot, dir)`.
8. The **A button is contextual** (jump-or-dodge, per TowerFall). CouchInput emits a primitive `primary_action_pressed(slot)`; **Movement** owns the jump-vs-dodge semantic resolution based on character state. This keeps CouchInput as raw routing and Movement as semantic interpretation, preventing a circular dep.
9. CouchInput subscribes to GSM `state_changed`. Active input layer = `gameplay` iff `state == InMatch`; otherwise `menu`.
10. `pause_requested` is emitted from both layers (so a paused player can request unpause). GSM applies debounce and validates against current state.
11. When 0 controllers are connected during InMatch, CouchInput emits `all_controllers_disconnected()` → GSM auto-pauses with synthetic `controller_id = -1` (per GSM Edge Case).
12. **No keyboard support in v1 shipping build.** Keyboard mappings exist for dev builds only, gated behind a debug flag (`DEBUG_KEYBOARD_INPUT`).

### Button Mapping (TowerFall parity)

**In-match (gameplay) layer — Xbox-style naming:**

| Verb | Button | CouchInput signal | Consumer | Notes |
|---|---|---|---|---|
| Movement | Left stick / D-pad | `move_input(slot, vector)` | Movement | Continuous per-frame |
| Jump-or-Dodge | A (bottom face) | `primary_action_pressed(slot)` | Movement | Movement resolves: airborne/moving = jump, stationary on ground = dodge |
| Throw | X (left face) | `throw_pressed(slot)` | Combat | Discrete press |
| Pause | Start (Menu) | `pause_requested(controller_id)` | GSM | GSM debounces (`PAUSE_DEBOUNCE_S`) |

**Menu layer (MainMenu / MatchSetup / Settings / MatchEnd / Paused):**

| Verb | Button | CouchInput signal | Notes |
|---|---|---|---|
| Navigate | D-pad / left stick | `menu_direction(slot, vector)` | Discrete events, not continuous |
| Confirm / Ready / Join | A (bottom face) | `menu_confirm(slot)` | Also serves as the "press any button to join" trigger |
| Back / Un-ready | B (right face) | `menu_cancel(slot)` | |
| Cycle clan (MatchSetup) | D-pad left/right | `menu_direction(slot, (±1, 0))` | Locked to D-pad to avoid stick-drift accidental cycling |

**Unused in v1** (reserved for future expansion): Y, LB, RB, LT, RT, Select/View.

### States and Transitions

**Layer state** (driven by GSM signal `state_changed`):

| Layer | When | Behavior |
|---|---|---|
| Menu | GSM ∈ {Boot, MainMenu, Settings, MatchSetup, MatchEnd, Paused} | Menu signals active; gameplay suppressed; `pause_requested` still permitted |
| Gameplay | GSM == InMatch | Gameplay signals active; menu suppressed (except `pause_requested`) |

**Per-controller state:**

| State | Entry | Exit | Behavior |
|---|---|---|---|
| Unassigned | Boot; disconnect during non-match states | First button press in menu layer → Assigned to next free slot | Only `controller_connected` signal (diagnostic) |
| Assigned | Press any button while unassigned (in menu layer) | Disconnect during non-match state | Receives slot N (1-4); all signals tagged with slot N |
| Reserved | Disconnect during InMatch or Paused | Reconnect (any physical device, no priority for same device) | Slot N held; reconnect reclaims slot N for next round |

**Per-slot state during MatchSetup:**

| State | Entry | Exit | Behavior |
|---|---|---|---|
| Browsing | Enter MatchSetup; or B from Locked | A on highlighted available clan → Locked | D-pad cycles available clans (skips clans Locked by other slots) |
| Locked | A while Browsing on available clan | B → Browsing; A → Ready | Clan reserved for this slot; greyed for other slots |
| Ready | A while Locked | B → Locked | Committed; MatchSetup transitions InMatch when all assigned slots are Ready |

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **GSM** | Subscribes to `state_changed` for input-layer switching | GSM → CouchInput |
| **GSM** | Receives `pause_requested(controller_id)` and `all_controllers_disconnected()` | CouchInput → GSM |
| **Movement** | Subscribes to `move_input(slot, vector)` and `primary_action_pressed(slot)`; resolves A semantics (jump vs dodge) based on own character state | CouchInput → Movement |
| **Combat** | Subscribes to `throw_pressed(slot)` | CouchInput → Combat |
| **Round Flow** | Receives `controller_disconnected(slot)` to trigger mid-round elimination; reads slot↔clan mapping from `MatchContext` (which CouchInput writes during MatchSetup) | CouchInput → (MatchContext) → Round Flow |
| **UI Flow** | Subscribes to menu signals; reads per-slot MatchSetup state for clan-select UI rendering | CouchInput → UI Flow |

## Formulas

CouchInput is mostly routing logic. Two real formulas exist: stick deadzone
(reject drift, produce clean Vector2) and menu navigation debounce (prevent
held D-pad from rapid-cycling).

### Stick deadzone (analog input → clean Vector2)

Standard radial-deadzone with smooth ramp-up — prevents stick drift from
registering and gives a consistent feel between low- and high-magnitude tilts.

```
if raw.length() < DEADZONE:
    processed = Vector2.ZERO
else:
    scale = (raw.length() - DEADZONE) / (1.0 - DEADZONE)   # 0..1
    processed = raw.normalized() * clamp(scale, 0.0, 1.0)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `raw` | Vector2 | length 0–1 (SDL3 reports nominally normalized) | Godot `InputEventJoypadMotion` | Raw stick input as reported by SDL3 |
| `DEADZONE` | float | 0.15 – 0.30 | tuning knob | Below this magnitude, input is treated as zero. Default 0.20 |
| `processed` | Vector2 | length 0–1 | emitted | Final input vector consumed by Movement / menu nav |

**Expected output**: zero vector for sticks at rest (rejects drift); smoothly-scaled
vector once outside deadzone (no abrupt jump from zero to deadzone value).

### Menu navigation debounce

Prevents holding D-pad-right from cycling rapidly through clans during MatchSetup.

```
menu_nav_eligible(slot, t) := (t - last_nav_emit[slot]) >= MENU_NAV_DEBOUNCE_S
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `t` | float | wall clock seconds | engine | Current time |
| `last_nav_emit[slot]` | dict[int, float] | wall clock seconds | CouchInput internal | Last time CouchInput emitted `menu_direction` for this slot |
| `MENU_NAV_DEBOUNCE_S` | float | 0.15 – 0.40 | tuning knob | Default 0.25 s. Equivalent to ~4 cycles/sec when held. |

**Expected output**: boolean. `True` = emit the navigation event; `False` = swallow.

**Analog-to-discrete threshold**: for analog sticks, a `menu_direction` event is
triggered when the stick's magnitude in any axis crosses `MENU_DISCRETE_THRESHOLD`
(default **0.5**) from below — i.e., a rising edge above 0.5. The opposite edge
(falling below 0.5) "rearms" the trigger. D-pad input bypasses this — D-pad button
events are already discrete.

```
menu_axis_event(slot, axis, magnitude_now, magnitude_prev) :=
    magnitude_prev <  MENU_DISCRETE_THRESHOLD
    AND magnitude_now >= MENU_DISCRETE_THRESHOLD
    AND menu_nav_eligible(slot, t)
```

**Note**: hold-to-repeat ramp-up (e.g., faster cycling after held >1 s) is *not*
implemented in v1 — flat debounce is sufficient for a 4-option clan picker.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Two unassigned controllers press a button on the same frame | Slots assigned in Godot device-index order (deterministic) | Avoids race; testable |
| Slot 1 empty, slot 2 filled, new controller joins | New controller claims slot 1 (next-free = lowest unassigned) | Per Core Rule 4 |
| All 4 slots full, 5th controller presses button | Ignored silently. No signal emitted. | Game caps at 4 players |
| Stick reports magnitude > 1.0 (some controllers misreport) | Clamp to 1.0 before processing through deadzone | Defensive; Godot/SDL3 should normalize but we don't trust |
| Reconnect when multiple slots are Reserved | New controller reclaims the lowest-numbered Reserved slot | Deterministic, simple |
| Player presses A on a clan that became unavailable mid-cycle (race with another slot's Lock) | Reject the lock; emit `menu_invalid_action(slot)` for UI feedback (denied sound, shake). Player must re-navigate. | Forced uniqueness must hold |
| Player Locks clan, presses A to Ready, then disconnects (during MatchSetup) | Slot released; clan freed; **all other Ready slots revert to Locked**. Match start requires fresh consensus. | Prevents starting a match with a dead slot |
| Stuck input (broken D-pad always-pressed) | Menu nav debounce prevents runaway cycling. Gameplay layer treats it as continuous input. No special detection in v1. | Pragmatic; address in v1.x if QA finds prevalent issue |
| Player presses Pause during Boot / MainMenu / Settings / MatchSetup / MatchEnd | CouchInput emits `pause_requested`; GSM silently rejects (per GSM Core Rule 7) | GSM owns validity, not CouchInput |
| Player presses A during the 1-frame transition between GSM states | Event is processed in the destination state's input layer (deferred via Godot signal chain) | Acceptable; verified in Acceptance Criteria |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| **Game State Manager** | CouchInput depends on GSM | Subscribes to `state_changed` for input-layer switching; emits `pause_requested(controller_id)` and `all_controllers_disconnected()` GSM consumes |
| **Movement** | Movement depends on CouchInput | Subscribes to `move_input(slot, vector)` and `primary_action_pressed(slot)`; owns jump-vs-dodge semantic resolution |
| **Combat** | Combat depends on CouchInput | Subscribes to `throw_pressed(slot)` |
| **Round Flow** | Round Flow depends on CouchInput | Subscribes to `controller_disconnected(slot)` for mid-round elimination; reads slot↔clan mapping via `MatchContext` |
| **UI Flow** | UI Flow depends on CouchInput | Subscribes to menu signals (`menu_direction`, `menu_confirm`, `menu_cancel`, `menu_invalid_action`); reads per-slot MatchSetup state for clan-select rendering |

**External dependencies:**
- Godot 4.6 input system: `InputEventJoypadButton`, `InputEventJoypadMotion`, `Input.get_connected_joypads()`, the `device` field for routing
- Godot 4.5+ SDL3 gamepad backend (cross-platform device mapping)
- Godot autoload system (CouchInput registered as `CouchInput` autoload)

**Bidirectional consistency** (resolved 2026-05-17):

- `design/gdd/systems-index.md` updated: Combat and Round Flow rows + Dependency Map Feature Layer entries now include Couch Input.
- `design/gdd/game-concept.md` updated: Round Flow's "Depends on" column now includes Couch Input.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `DEADZONE` | 0.20 | 0.15 – 0.30 | More stick drift tolerated; less precise low-tilt control | More stick sensitivity; drift may register |
| `MENU_NAV_DEBOUNCE_S` | 0.25 | 0.15 – 0.40 | Slower menu cycling when held; less risk of skipping past intended item | Faster cycling; risk of overshooting on a hold |
| `MENU_DISCRETE_THRESHOLD` | 0.5 | 0.35 – 0.65 | Stick must tilt further to register a menu direction; more deliberate navigation | Stick triggers events more easily; risk of accidental cycling on partial tilts |
| `MAX_CONNECTED_CONTROLLERS` | 4 | (hard-locked to 4 in v1) | *(not meaningfully tunable — game design assumes 4)* | *(below 4 would break MatchSetup logic)* |
| `SLOT_RECONNECT_PRIORITY_MODE` | `"lowest_reserved"` | `"lowest_reserved"` / `"same_device_id_match"` | `same_device_id_match` would prefer reuniting a controller with its previous slot; harder to implement, may surprise players | (default) `lowest_reserved` is deterministic and matches the "any controller, any slot" couch vibe |
| `DEBUG_KEYBOARD_INPUT` | `false` | `true` / `false` | (debug only) Enables keyboard fallback mappings for solo dev/test | (default) Keyboard disabled in shipping build |

**Not knobs**: button mappings themselves are *not* designer-tunable in v1 — they
are locked to TowerFall parity (per Pillar 5 *Game-Feel First* — we tune the feel
of those bindings, not the bindings themselves). Per-player remapping is deferred
to v1.x (concept doc Open Questions: accessibility / key-rebinding).

## Acceptance Criteria

### Functional

- [ ] All 4 controller slots can be claimed via press-any-button-to-join
- [ ] After 4 slots are claimed, additional controllers are ignored (no signal, no error)
- [ ] Disconnect during MainMenu / MatchSetup / MatchEnd releases the slot immediately
- [ ] Disconnect during InMatch holds the slot (Reserved); player is eliminated for current round
- [ ] Reconnect during InMatch reclaims lowest-numbered Reserved slot for the next round
- [ ] Reconnect during Paused resumes participation in the same slot
- [ ] Two slots cannot Lock the same clan (forced uniqueness holds even under race)
- [ ] Locked clans appear greyed for other slots during MatchSetup
- [ ] Pressing A on a clan that became unavailable mid-cycle emits `menu_invalid_action(slot)`
- [ ] Disconnect of a Ready slot reverts all other Ready slots to Locked
- [ ] Pause from InMatch emits `pause_requested`; GSM transitions to Paused within ≤1 frame
- [ ] Pause from non-InMatch state emits `pause_requested` but is silently rejected by GSM
- [ ] All controllers unplugged during InMatch emits `all_controllers_disconnected`
- [ ] A-button context resolution (verified via Movement integration test): airborne or moving = jump; stationary on ground = dodge

### Per-slot signal routing

- [ ] Signals emitted by slot N carry slot index N
- [ ] Input from slot N's controller does not produce signals tagged with slot M
- [ ] A controller that disconnects and reconnects to a different slot receives the new slot index in subsequent signals

### Stick processing

- [ ] Stick at rest (raw magnitude < `DEADZONE`) produces zero vector
- [ ] Stick at full deflection produces unit vector
- [ ] Stick between `DEADZONE` and 1.0 produces smoothly-scaled vector (no abrupt jump from zero to the deadzone value)
- [ ] Stick reporting >1.0 magnitude is clamped to 1.0

### Menu navigation

- [ ] D-pad held >`MENU_NAV_DEBOUNCE_S` advances exactly one position per debounce window
- [ ] Press-and-release D-pad emits exactly one `menu_direction` event regardless of hold time <debounce

### Performance

- [ ] CouchInput input-event processing completes within ≤1 ms per frame
- [ ] Signals fire on the same frame as the underlying `InputEvent` (no extra-frame latency)

### Code hygiene

- [ ] All button mappings reference Godot button-index constants (no magic numbers)
- [ ] All tuning knobs (Section G) exposed in config, not hardcoded
- [ ] All action names use `StringName` (`&"action"`) per Godot 4.6 best practice

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Catch mechanic: TowerFall ties catch to dodge timing (no separate catch button). This GDD assumes the same — no separate catch input. If Movement decides to add a dedicated catch button (per concept doc MVP blocker), this GDD's button mapping must be updated. | Movement GDD author | Before Movement GDD approved | TBD — currently assumed dodge-only (no separate catch) |
| Hot-plug reconnect priority: currently `lowest_reserved`. Should we add a "same physical device ID match" heuristic so the same controller reconnecting always reclaims its previous slot? | UX + gameplay-programmer | After MVP playtest if confusion observed | Defer to playtest feedback |
| Stuck-input detection: should we add a fallback (e.g., if a button reports continuously pressed for >30 s, log a warning and treat as released)? | gameplay-programmer + QA | v1.x if QA finds prevalent issue | Defer |
| Per-player remapping for accessibility (concept Open Questions: "key-rebinding"). | accessibility-specialist | v1.x | Deferred |
| Steam Input Action Set: provide a `.vdf` file so Steam Deck / Steam Input users can remap easily, or rely on SDL3 defaults? | release-manager + ux-designer | Before Steam store submission | Defer — likely defaults suffice for v1 |
| Hold-to-repeat ramp for menu nav: not needed for 4-clan picker but may matter for future settings menus. Flat debounce is current behavior. | ux-designer | When settings/options menu is designed | Deferred |
