# Game State Manager

> **Status**: Approved
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-17
> **Implements Pillar**: Indirect — serves *The Couch Is the Game*, *Restraint over Spectacle*, *Game-Feel First*

## Overview

The Game State Manager (GSM) is the top-level state machine for Four Clans. It
tracks what mode of the game is currently active — booting up, sitting on the
main menu, configuring a match, playing a match, or showing match results —
and owns every transition between those modes. It is the spine that the rest
of the game hangs from: UI Flow consumes it to know which screen to render,
Round Flow consumes it to know when the in-match loop is alive, and audio /
input subsystems consume it to know what controls and music are appropriate
for the current context. The player never sees the GSM directly; they only
feel its absence when transitions are instant and obvious.

## Player Fantasy

**The player should never notice the Game State Manager.** Its presence is
felt only as the absence of friction: there are no loading screens, no
"Press Start" ambiguity, no transition animations longer than a heartbeat,
no menus that take more inputs than they need.

When a friend hands over a controller at the start of a match, that controller
should be active in the menu before the friend has finished sitting down.
When the final round of a match ends, the match-end screen should appear
instantly and clear out the moment the next match is queued. When the players
pause to argue a ruling or open a beer, the pause should land within a single
frame of the button press and lift just as fast.

This is *Game-Feel First* applied to chrome: every state transition is a verb,
and every verb has to feel as crisp as the dodge.

## Detailed Design

### Core Rules

1. GSM is implemented as a Godot autoload singleton (`GameStateManager`).
2. GSM owns one canonical state variable: `current_state: State` (enum).
3. GSM owns the canonical `MatchContext` Resource (created on entry to MatchSetup, persists through MatchEnd, discarded on return to MainMenu).
4. State transitions are requested via `request_transition(target: State) -> bool`. Direct mutation of `current_state` from outside GSM is prohibited.
5. `request_transition` validates the request against the transitions table below. Invalid transitions return `false` and log a warning; they never silently succeed.
6. On a valid transition, GSM emits — in order:
   - `state_changing(old, new)` — pre-transition; subscribers run cleanup
   - updates `current_state`
   - `state_changed(old, new)` — post-transition; subscribers run enter logic
7. Pause is requested via `request_pause(controller_id)` from Couch Input. GSM applies a 1-second per-controller debounce and validates that `current_state == InMatch`. Invalid pause requests are rejected silently (no error log — pause spam is expected on couch).
8. Unpause is requested via `request_unpause(controller_id)` from any controller (also debounced).
9. Settings is reachable from MainMenu, Paused, or MatchEnd. GSM stores the `return_to_state` on entry; on exit, transitions back to it.
10. Quit-to-desktop is a Godot engine action (`get_tree().quit()`), not a GSM state. GSM is responsible for ensuring no transitions are in flight when quit is requested.

### States and Transitions

| State | Entry From | Exit To | Behavior |
|---|---|---|---|
| **Boot** | App launch | → MainMenu (when ready); or remain in Boot if preload fails (see Edge Cases) | Splash (UI owned by UI Flow); preload of main menu UI scene + autoload singletons; controller enumeration via `Input.get_connected_joypads()` |
| **MainMenu** | Boot, MatchEnd, Settings (return) | → MatchSetup, → Settings, → engine quit | Title art; menu nav |
| **Settings** | MainMenu, Paused, MatchEnd | → previous (via `return_to_state`) | Volume / video / controller config; overlay UI |
| **MatchSetup** | MainMenu, MatchEnd ("Play Again") | → InMatch (all confirmed), → MainMenu (cancel) | Clan select per controller; map select; N config |
| **InMatch** | MatchSetup confirmed | → MatchEnd (Round Flow `match_won`), → Paused | Round Flow drives gameplay; GSM dormant |
| **Paused** | InMatch (`request_pause` valid) | → InMatch (resume), → MainMenu (quit), → Settings | Freezes simulation via `get_tree().paused = true`; overlay UI |
| **MatchEnd** | InMatch (`match_won`) | → MatchSetup ("Play Again", reuses MatchContext), → MainMenu (back), → Settings | Victory screen; score recap; controller-friendly nav |

### Interactions with Other Systems

GSM is the contract every other system reads against. The interactions below are canonical — these are commitments. Downstream GDDs (Round Flow, UI Flow, etc.) must align to these or escalate a change request back to this GDD.

| Consumer | Interaction | Direction |
|---|---|---|
| **UI Flow** | Connects to `state_changed`; switches active UI scene per `new` state | GSM signals → UI Flow |
| **UI Flow** | Calls `request_transition` to drive menu nav (MainMenu → MatchSetup, etc.) | UI Flow → GSM |
| **Round Flow** | Reads `MatchContext` on entry to InMatch (clan choices, map, N) | GSM provides → Round Flow |
| **Round Flow** | Emits `match_won(winner)` → GSM transitions InMatch → MatchEnd | Round Flow signals → GSM |
| **Round Flow** | Writes per-round score updates to `MatchContext` (HUD + MatchEnd read it) | Round Flow writes → MatchContext |
| **Couch Input** | Emits `pause_requested(controller_id)` → GSM applies debounce + validates | Couch Input signals → GSM |
| **Couch Input** | Reads `current_state` getter to switch input layer (gameplay vs menu) | GSM exposes → Couch Input reads |
| **Audio** | Connects to `state_changed`; swaps music tracks per state | GSM signals → Audio |
| **HUD / Visual FX** | Visible only in InMatch and Paused; UI Flow handles the show/hide routing | (UI Flow concern) |

## Formulas

GSM has minimal mathematical content — state transitions are conditional logic,
not numerical computation. The two formula-like elements are the pause debounce
and the transition-latency budget.

### Pause debounce

```
pause_eligible(controller_id, t) :=
    (t - last_pause_request[controller_id]) >= PAUSE_DEBOUNCE_S
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `t` | float | wall clock time, seconds since boot | engine | Current time |
| `last_pause_request[c]` | dict[int, float] | wall clock time | GSM internal | Time of last pause/unpause request from controller `c` |
| `PAUSE_DEBOUNCE_S` | float | 0.5 – 2.0 | tuning knob | Debounce window. Default 1.0 s. |

**Expected output**: boolean. `True` = pause request honored; `False` = rejected silently.

### Transition latency budget

```
transition_complete_time :=
    (state_changing emit) + (subscriber cleanup)
  + (state mutation)
  + (state_changed emit) + (subscriber enter logic)
```

Not a formula in the usual sense — a budget. **Target: ≤ 1 frame (16.6 ms at 60 fps).**
If a transition takes longer, the player perceives lag, violating *Game-Feel First*.
This drives the corresponding entry in **Acceptance Criteria** below.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Invalid transition requested (e.g., MainMenu → InMatch directly) | Return `false`, log warning, no state change | Per Core Rule 5; transition table is the authority |
| Simultaneous transition requests from multiple subsystems | First request wins (single-threaded serialization); second is re-evaluated against the new state | Godot main-thread guarantees atomicity |
| All controllers unplugged mid-match | Auto-pause via synthetic transition (InMatch → Paused with `controller_id = -1`) | "Dog tripped over the wires" recovery; resumes when ≥1 controller reconnects |
| Pause pressed at the exact frame InMatch → MatchEnd transitions | Pause request rejected (invalid from MatchEnd) | Transitions are atomic; second event sees the new state |
| Settings exited with unsaved changes | Settings system decides (out of GSM scope) | Boundary: GSM owns state; Settings owns its data |
| "Play Again" with stale MatchContext (e.g., a player disconnected during MatchEnd) | MatchSetup re-validates on entry and falls back to defaults | MatchSetup is the validator; GSM just hands off the Resource |
| `request_transition` called from a `state_changing` subscriber (re-entrancy) | Reject with warning; subscriber must use `call_deferred` | Prevents re-entrancy bugs and infinite-loop risk |
| Boot fails (asset preload error) | Stay in Boot indefinitely; show non-dismissible error overlay; log error | v1 simplicity: no crash, no silent failure, no advance into broken state |
| Quit-to-desktop fires mid-transition | Godot's quit handler cleans up; GSM does not block quit | v1 simplicity; revisit if observed in QA |

## Dependencies

GSM is a Foundation system with **zero upstream dependencies** — it is depended
on, not depending. Downstream consumers below.

| System | Direction | Nature of Dependency |
|---|---|---|
| — | This depends on nothing | Foundation system; no internal deps |
| UI Flow | UI Flow depends on GSM | Reads `state_changed` to switch active UI scene; calls `request_transition` for menu nav; queries `current_state` |
| Round Flow | Round Flow depends on GSM | Reads `MatchContext` Resource on InMatch entry; emits `match_won` signal GSM consumes |
| Couch Input | Couch Input depends on GSM | Subscribes to `state_changed` to switch input layer (gameplay vs menu); emits `pause_requested` GSM consumes |
| Audio | Audio depends on GSM | Subscribes to `state_changed` to swap music tracks per state |
| HUD | HUD depends on GSM (indirect, via UI Flow) | UI Flow shows/hides HUD per state |
| Visual FX | Visual FX depends on GSM (indirect, via UI Flow) | UI Flow shows/hides VFX per state |

**External dependencies:**
- Godot 4.6 autoload system (`GameStateManager` registered as autoload)
- Godot 4.6 signal system (`state_changing`, `state_changed`, `pause_requested`)
- Godot 4.6 `SceneTree.paused` (used in Paused state to freeze simulation)

**Bidirectional consistency** (resolved 2026-05-17):

- `docs/gdd/systems-index.md` updated: Couch Input and Audio now list Game State Manager as a dependency; the Dependency Map's Foundation Layer entry for Couch Input notes the within-layer dep on GSM.
- `docs/gdd/game-concept.md` updated: Round Flow's "Depends on" column now includes Game State Manager.

## Tuning Knobs

GSM is mostly architectural — few real tuning knobs exist. The honest list is short.

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `PAUSE_DEBOUNCE_S` | 1.0 | 0.5 – 2.0 | Less pause-spam tolerance; harder to accidentally re-pause | More pause spam; easier accidental pause/unpause cycles |
| `AUTO_PAUSE_ON_ALL_CONTROLLERS_UNPLUGGED` | `true` | `true` / `false` | *(boolean — if false, match continues in undefined state when no controllers connected; not recommended)* | *(See Edge Cases for rationale)* |
| `STATES_PERMITTING_PAUSE` | `[InMatch]` | subset of `State` enum | More forgiving (e.g., allow pause in MatchSetup) | More restrictive (e.g., disallow pause entirely) |
| `STATES_PERMITTING_SETTINGS` | `[MainMenu, Paused, MatchEnd]` | subset of `State` enum | More entry points to settings | Fewer; may make settings hard to reach |

**Not a knob**: `TRANSITION_LATENCY_BUDGET_MS = 16.6` is an *acceptance criterion*,
not a tuning knob. Designers shouldn't tune it; the implementation team must hit it.

## Acceptance Criteria

### Functional

- [ ] All 7 states are reachable via valid transition paths from Boot
- [ ] All invalid transitions (per the transitions table) return `false` and log a warning; no state change occurs
- [ ] `state_changing` fires before `current_state` is mutated; `state_changed` fires after — verified via instrumented test
- [ ] Pause from InMatch transitions to Paused within ≤1 frame; freezes simulation (`get_tree().paused == true`)
- [ ] Unpause from Paused returns to InMatch within ≤1 frame; resumes simulation
- [ ] Pause request from a non-InMatch state is silently rejected (no error log)
- [ ] Pause debounce: a second request from the same controller within `PAUSE_DEBOUNCE_S` is rejected; from a different controller is honored
- [ ] All controllers unplugged during InMatch auto-transitions to Paused with synthetic `controller_id = -1`
- [ ] Reconnecting at least one controller from the auto-pause state allows unpause via that controller
- [ ] Settings entered from MainMenu / Paused / MatchEnd returns to the originating state on exit
- [ ] "Play Again" from MatchEnd transitions to MatchSetup with the original `MatchContext` preserved
- [ ] "Back to Menu" from MatchEnd discards `MatchContext`

### MatchContext lifecycle

- [ ] `MatchContext` is created on entry to MatchSetup (not before)
- [ ] `MatchContext` persists through InMatch and MatchEnd (Round Flow reads it during InMatch; MatchEnd UI reads it during MatchEnd)
- [ ] `MatchContext` is discarded on transition to MainMenu (from MatchEnd "Back to Menu")

### Performance

- [ ] Transition latency: any single transition completes in ≤16.6 ms (1 frame at 60 fps), measured from `request_transition` call to `state_changed` emission including all subscriber handlers
- [ ] Boot → MainMenu completes within 3 seconds on minimum target hardware (Steam Deck)

### Edge cases (cross-reference Section E)

- [ ] Re-entrant `request_transition` from a `state_changing` subscriber is rejected with warning
- [ ] Simulated Boot failure shows a non-dismissible error overlay; does not crash; does not advance state
- [ ] Simultaneous transition requests are serialized (Godot main thread); the second request is re-evaluated against the new state

### Code hygiene

- [ ] All states reference the `State` enum (no hardcoded state strings)
- [ ] No subsystem directly mutates `current_state`; all changes go through `request_transition`
- [ ] All tuning knobs (per Section G) are exposed in a config file, not hardcoded

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| If a round-time-cap stalemate ends with no winner, does Round Flow emit `match_won(null)` or a new `match_aborted` signal? GSM needs an entry condition into MatchEnd for the "nobody won" case. | Round Flow GDD author | Before Round Flow GDD is approved | **Resolved 2026-05-18**: Round Flow GDD locks `ROUND_TIME_CAP_S = None` for v1 (no stalemate mechanic in MVP; sudden-death deferred to v1.x post-MVP playtest). Neither `match_won(null)` nor `match_aborted` is needed in v1. v1.x sudden-death design will need to revisit this question. |
| Should Settings be reachable from InMatch directly (without going through Paused first)? Current design says no — must pause first. UX concern: changing volume mid-match is annoying if it requires a full pause first. | ux-designer + game-designer | Before alpha menu pass | TBD |
| Should "Back to Menu" from MatchEnd confirm before discarding the match? Not relevant in v1 (no per-match stats persisted), but relevant if stat persistence is ever added. | game-designer | v1.x or later | Deferred |
| Does GSM Boot need a measured timeout? If Boot exceeds 3 s on Steam Deck, what happens — error overlay, or just accept slow boot? Current design says no timeout, only the performance criterion. | gameplay-programmer + QA | During Boot implementation | TBD — likely no timeout in v1 |
| Should `MatchContext` be a `Resource` saved to disk for crash recovery (resume from interrupted match)? Out of v1 scope per concept doc but worth tracking. | game-designer | v1.x | Deferred |
| What is the input layer for the auto-paused state when no controllers are connected? Currently undefined — there is no controller to unpause with until reconnection. Couch Input must define what triggers unpause-on-reconnect. | Couch Input GDD author | Before Couch Input GDD is approved | TBD |
