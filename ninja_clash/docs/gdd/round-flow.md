# Round Flow

> **Status**: Approved
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-18
> **Implements Pillar**: Indirect — *The Couch Is the Game*, *Game-Feel First*, *Restraint over Spectacle*

## Overview

The Round Flow system is the match-and-round orchestrator for Four Clans.
It owns the lifecycle that turns kills into rounds and rounds into matches:
spawning players at the start of each round, listening for kill events from
Combat, declaring a round winner when only one player remains alive, holding
a brief inter-round delay so the room can breathe, and ending the match
when one player reaches the win threshold (default first-to-10). It is the
system that consumes the `MatchContext` GSM hands it on InMatch entry and
emits the `match_won(winner)` signal GSM consumes to transition out. Round
Flow is the only Feature-tier system that no other gameplay system depends
on — it sits at the top of the dependency stack, conducting Combat,
Movement, Map, CC, and CouchInput rather than being conducted by them. The
player never sees Round Flow directly; they feel it as the rhythm of the
couch-night — the snap of a round ending, the half-breath of "ready up,"
the next round spawning before anyone has finished talking trash about the
last one.

## Player Fantasy

The player should never think about Round Flow. They should only feel its
absence of friction. A kill lands; the round resolves within a heartbeat;
the scoreboard ticks; the next round spawns before the dead player has
finished swearing. Match-end appears the moment someone hits ten, not a
beat later. Nothing waits, nothing celebrates, nothing pads.

This is the *couch-night rhythm* made concrete. TowerFall's pacing is the
explicit reference: rounds end fast and decisively, the respawn delay is
just long enough for the room to breathe, and the next round arrives before
momentum dies. Per the concept doc, *"the round ends, the scoreboard ticks
up, the next round spawns immediately"* — that single beat is the
player-facing surface of Round Flow.

The fantasy lives in what *doesn't* happen. No "Round 4 — Fight!" intro
card. No 3-2-1 countdown after each death. No victory pose on the round
winner. No tournament bracket animation between matches. *Restraint over
Spectacle* applied to chrome: every round-end is a verb, and every verb has
to feel as crisp as the dodge. The dead player watching from the sidelines
stays leaning forward, not because anything dramatic is happening, but
because the next round is already a second away.

The other emotional anchor is *fairness across the match*. Per *Fairness Is
Sacred*, no slot gets an inherent positional advantage across a 10-round
match. Spawn assignment rotates round-over-round so that nobody is
permanently positioned next to a wall they like or near a contested
chokepoint. The friend group should never be able to say "you only won
because you had the corner spawn" — Round Flow erases that complaint by
erasing the asymmetry.

## Detailed Design

### Core Rules

1. Round Flow is a Godot autoload singleton (`RoundFlow`). One instance per game session. Dormant when GSM `current_state != InMatch`.

2. Round Flow subscribes to GSM's `state_changed` signal. On transition to `InMatch`: enters active state, runs round-start sequence (Rule 4). On transition out of `InMatch` (to MatchEnd or Paused): see Rule 11/12.

3. Round Flow holds the following per-match state, initialized on InMatch entry, cleared on exit:
   - `round_index: int` — 1-indexed; increments on each round start
   - `scores_by_slot: dict[int, int]` — wins per slot (0 .. N)
   - `alive_by_slot: dict[int, bool]` — true if slot is alive in current round
   - `active_slots: Array[int]` — slot numbers participating in this match (read from `MatchContext`)
   - `player_bodies: dict[int, PlayerCharacterBody]` — per-slot CC instance for current round
   - `round_in_progress: bool` — false during respawn delay; true during active round
   - `match_target: int` — `first_to_n_match_target` from `MatchContext` (default 10)

4. **InMatch entry sequence** (one-shot, on GSM transition to InMatch):
   1. Read `MatchContext` from GSM.
   2. Populate `active_slots` from MatchContext (slots with assigned clans).
   3. Initialize `scores_by_slot[slot] = 0` for each active slot.
   4. Initialize `round_index = 0`.
   5. Trigger `MapLoader.load(MatchContext.map_id)` → instantiate map scene.
   6. Begin round-start sequence (Rule 5) for round 1.

5. **Round-start sequence** (each new round):
   1. Increment `round_index`.
   2. Compute spawn assignment via Formula 1 (cyclic-index rotation).
   3. For each active slot:
      - Instantiate `PlayerCharacterBody` with `slot` field set per CC Rule 14.
      - Add child `PlayerMovement` node (per Movement Rule 1).
      - Set CC position to assigned spawn point (read from `MapResource.spawn_points`).
      - Store in `player_bodies[slot]`.
      - Set `alive_by_slot[slot] = true`.
   4. Set `round_in_progress = true`.
   5. Emit `round_started(MatchContext, round_index)` — Combat consumes (Rule 11) to refill stashes.

6. **Player elimination handler** (on `Combat.player_eliminated(victim_slot, killer_slot, projectile_id)`):
   1. **Already-eliminated guard**: if `alive_by_slot[victim_slot] == false`: ignore (defensive — Combat Rule 7.1 also guards). No-op.
   2. Set `alive_by_slot[victim_slot] = false`.
   3. Compute `alive_count = sum(alive_by_slot.values())`.
   4. **Branch**:
      - `alive_count >= 2` → continue round (no-op beyond bookkeeping).
      - `alive_count == 1` → identify survivor slot; trigger round-end sequence (Rule 7) with `winner_slot = survivor`.
      - `alive_count == 0` → tie; trigger round-end sequence with `winner_slot = -1` (tie marker; no point awarded per Rule 7.3 branch).

7. **Round-end sequence**:
   1. **Same-tick re-entry guard**: if `round_in_progress == false`: ignore (defensive — handles same-tick double-kill where two player_eliminated events both trigger round-end attempts).
   2. Set `round_in_progress = false`.
   3. **Award point**:
      - If `winner_slot >= 1`: `scores_by_slot[winner_slot] += 1`. Emit `score_changed(winner_slot, new_score)`.
      - If `winner_slot == -1` (tie): no score change; no signal emit. Scoreboard unchanged per Decision 3.
   4. Start kill-cam timer: wait `KILL_CAM_DELAY_S` (default 0.5s) before continuing. (Implementation: Godot `Timer` node or `await get_tree().create_timer(KILL_CAM_DELAY_S).timeout`.)
   5. After kill-cam delay elapses: emit `round_ended(winner_slot, round_index)` — Combat consumes (Rule 12) to clean up live projectiles; HUD consumes to show round-end overlay.
   6. Free all `PlayerCharacterBody` instances in `player_bodies` (alive + dead). Clear `player_bodies`.
   7. **Check match-win** (Rule 8). If match continues, start respawn delay (Rule 9).

8. **Match-win check**:
   - Find slots where `scores_by_slot[slot] >= match_target`.
   - If exactly one slot qualifies → trigger match-end sequence (Rule 10) with that slot as winner.
   - If multiple slots qualify simultaneously (impossible under tie-no-point rule, but defensive): pick the highest-scoring; if still tied, pick lowest-slot-number. Log warning.
   - If no slot qualifies → no match-end; proceed to next round.

9. **Inter-round respawn delay**:
   - Wait `RESPAWN_DELAY_S` (default 3.0s) after `round_ended` emit.
   - On timer expiry: begin next round-start sequence (Rule 5).
   - During respawn delay: `round_in_progress = false`; HUD shows scoreboard; no player bodies exist in scene.

10. **Match-end sequence**:
    1. Write final scores into `MatchContext.final_scores: dict[int, int]` (copy of `scores_by_slot`).
    2. Write winner: `MatchContext.winner_slot: int = winner`.
    3. Write rounds played: `MatchContext.rounds_played: int = round_index`.
    4. Emit `match_won(winner_slot)` — GSM consumes, transitions InMatch → MatchEnd.

11. **Pause handling** (GSM transitions InMatch → Paused):
    - Round Flow does nothing special. `get_tree().paused = true` (per GSM Rule 7) freezes Round Flow's timers along with everything else. Resume on InMatch return continues from where it paused.

12. **InMatch exit cleanup** (GSM transitions out of InMatch to anywhere except Paused):
    - If match-end did NOT just fire (e.g., user quit to menu): free all `player_bodies` instances; clear `scores_by_slot`, `alive_by_slot`, `active_slots`, `player_bodies`, `round_index = 0`.
    - If match-end did fire (Rule 10): same cleanup, but `MatchContext` retained per GSM Rule 3 (discarded by GSM on MatchEnd → MainMenu transition).
    - Trigger `MapLoader.unload()` (per Map states table).

13. **Mid-round controller disconnect** (on `CouchInput.controller_disconnected(slot)`):
    - If `round_in_progress == true` AND `alive_by_slot[slot] == true`: treat as elimination — call internal eliminate path with `victim_slot = slot, killer_slot = -1` (disconnect marker; no killer attribution; not credited to anyone). Fires same round-end check as Rule 6.
    - If `round_in_progress == false`: no in-round eliminate; CouchInput's slot lifecycle handles next-round re-join (per CouchInput Core Rule 5).
    - **Reconnect**: handled entirely by CouchInput; slot becomes available for next round's round-start sequence (Rule 5 reads `active_slots` from `MatchContext`, which CouchInput updates).

14. **All-controllers-disconnected** (on `CouchInput.all_controllers_disconnected()`):
    - GSM auto-pauses (per GSM Edge Case + CouchInput Rule 11). Round Flow's timers freeze via `get_tree().paused`.
    - Round Flow takes no separate action.

15. **No round-time-cap in MVP**: rounds run indefinitely until elimination. The `round_time_cap_s` tuning knob exists in concept doc but is locked to `None` in v1. Stalemate-breaker mechanic deferred to v1.x post-MVP playtest (per Decision 5).

16. **Identical across clans**: spawn assignment, scoring, round/match rules apply identically to every slot. Per Pillar 2 (Fairness Is Sacred).

### States and Transitions

Round Flow has a small, explicit state machine driven by GSM's `current_state` and internal `round_in_progress`. Unlike Combat (which is purely dict-based), Round Flow has a real lifecycle.

| State | Entry | Exit | Behavior |
|---|---|---|---|
| Dormant | App boot; GSM transitions out of InMatch (cleanup completed) | GSM transitions to InMatch | All internal state cleared; no signals processed |
| RoundActive | After Round-start sequence (Rule 5) completes; `round_in_progress = true` | `alive_count <= 1` triggers Round-end | Combat / Movement / CC are live; player_eliminated signals processed per Rule 6 |
| RoundEnding | Round-end sequence (Rule 7) entered | `KILL_CAM_DELAY_S` elapses + round_ended emit + bodies freed | Kill-cam delay running; no new eliminations counted (re-entry guard per Rule 7.1) |
| RespawnDelay | Match continues after Rule 8 → Rule 9 | `RESPAWN_DELAY_S` elapses | No player bodies in scene; HUD shows scoreboard; next round-start queued |
| MatchEnding | Match-win detected (Rule 8 → Rule 10) | `match_won` emitted to GSM → GSM transitions to MatchEnd | Final scores written to MatchContext; brief; transitions out immediately |

**Transitions table**:

| From | To | Trigger |
|---|---|---|
| Dormant | RoundActive | GSM `state_changed` → InMatch; InMatch entry sequence (Rule 4) → Round-start (Rule 5) completes |
| RoundActive | RoundEnding | `Combat.player_eliminated` reduces `alive_count` to ≤1 |
| RoundEnding | RespawnDelay | Round-end sequence completes + match not won |
| RoundEnding | MatchEnding | Round-end sequence completes + match-win detected |
| RespawnDelay | RoundActive | `RESPAWN_DELAY_S` timer elapses → next Round-start (Rule 5) |
| MatchEnding | Dormant | `match_won` emit → GSM transitions to MatchEnd → InMatch exit cleanup (Rule 12) |
| (any) | Dormant | GSM transitions out of InMatch unexpectedly (user quit, etc.) → Rule 12 cleanup |

Pause does NOT appear as a transition because `get_tree().paused = true` freezes Round Flow without changing its state — it resumes in whatever state it was in.

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **Game State Manager** | Round Flow subscribes to GSM `state_changed` for InMatch entry/exit. Reads `MatchContext` Resource on InMatch entry (active slots, map_id, match_target). Emits `match_won(winner_slot)` for GSM to transition to MatchEnd. Writes match results back into `MatchContext` (`final_scores`, `winner_slot`, `rounds_played`) before emit. | GSM ↔ Round Flow |
| **Map** | Round Flow calls `MapLoader.load(map_id)` on InMatch entry; reads `MapResource.spawn_points` for spawn assignment. Calls `MapLoader.unload()` on InMatch exit cleanup. | Map → Round Flow |
| **Combat** | Round Flow emits `round_started(MatchContext, round_index)` → Combat refills stashes per Combat Rule 11. Round Flow emits `round_ended(winner_slot, round_index)` → Combat cleans up live projectiles per Combat Rule 12. Round Flow subscribes to `Combat.player_eliminated(victim_slot, killer_slot, projectile_id)` for alive tracking + round-end detection. | Round Flow ↔ Combat |
| **Movement** | Round Flow instantiates `PlayerMovement` as child of each `PlayerCharacterBody` at round-start (per Movement Rule 1). Frees Movement+CC instances at round-end (after kill-cam delay) per Rule 7.6. Movement's `set_dead()` is called by Combat, not by Round Flow. | Round Flow → Movement (instantiation/free only) |
| **Character Controller** | Round Flow instantiates `PlayerCharacterBody` with `slot: int` field set (CC Rule 14) at each round-start. Sets initial position to spawn point. Frees all CCs (alive + dead) at round-end. | Round Flow → CC |
| **Couch Input** | Round Flow subscribes to `controller_disconnected(slot)` for mid-round elimination (Rule 13). Reads slot↔clan mapping from `MatchContext` (CouchInput populates during MatchSetup per CouchInput Rule 6 / interactions table). Does NOT subscribe to throw/move signals — those go to Combat/Movement directly. | CouchInput → Round Flow |
| **HUD** (forward contract — undesigned) | HUD subscribes to `round_started`, `round_ended`, `score_changed`, `match_won` for scoreboard + round overlay + match-end UI. HUD reads `scores_by_slot`, `round_index`, `alive_by_slot` via public queries. | Round Flow → HUD |
| **Visual FX** (forward contract — undesigned) | Visual FX may subscribe to `round_started` (e.g., spawn flash), `round_ended` (round-clear FX), and the kill-cam window during RoundEnding state. Visual FX reads dead-body state during the kill-cam window. | Round Flow → Visual FX |
| **Audio** (forward contract — undesigned) | Audio subscribes to `round_started`, `round_ended`, `match_won` for stings + music transitions. | Round Flow → Audio |

**Public API for HUD/UI**:
- `get_score(slot: int) -> int`
- `get_round_index() -> int`
- `get_alive_count() -> int`
- `is_round_in_progress() -> bool`
- Signals: `round_started(MatchContext, round_index)`, `round_ended(winner_slot, round_index)`, `score_changed(slot, new_score)`, `match_won(winner_slot)`

**Cross-system updates required** (caught during this section draft):

1. **`design/gdd/map.md` Loading state row** doesn't credit Round Flow as the caller of `MapLoader.load()`. Recommend clarifying: Round Flow triggers the load on InMatch entry sequence Rule 4.5.
2. **`design/gdd/couch-input.md` Core Rules** never explicitly define the `controller_disconnected(slot)` signal name — only appears in the Interactions table. Recommend adding to CouchInput's Core Rules signal list.
3. **`MatchContext` schema** is under-specified across GSM + concept docs. Round Flow now writes 3 new fields (`final_scores`, `winner_slot`, `rounds_played`) AND reads `map_id`, `active_slots`, `match_target`. Recommend documenting the full schema (most natural home: GSM GDD).

All 3 will be applied/flagged in the post-design step.

## Formulas

Round Flow's math is small — it's orchestration, not simulation. 4 formulas total.

### Formula 1: Spawn assignment (cyclic-index rotation)

Resolves the GSM + Map open question on spawn rotation. Deterministic, no RNG, no positional advantage across a 10-round match.

```
spawn_index(slot, round_index, active_slots) :=
    (active_slots.find(slot) + (round_index - 1)) mod len(active_slots)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `slot` | int | 1..4 | per-slot | Player slot to compute spawn for |
| `round_index` | int | ≥1 | Round Flow internal | 1-indexed current round number |
| `active_slots` | Array[int] | length 2..4 | MatchContext | Sorted list of active player slots |

**Returns**: index into `MapResource.spawn_points` array (0..3).

**Examples** (4-player match, `active_slots = [1, 2, 3, 4]`):

| Round | Slot 1 | Slot 2 | Slot 3 | Slot 4 |
|---|---|---|---|---|
| 1 | spawn[0] | spawn[1] | spawn[2] | spawn[3] |
| 2 | spawn[1] | spawn[2] | spawn[3] | spawn[0] |
| 3 | spawn[2] | spawn[3] | spawn[0] | spawn[1] |
| 4 | spawn[3] | spawn[0] | spawn[1] | spawn[2] |
| 5 | spawn[0] | spawn[1] | spawn[2] | spawn[3] | *(cycle repeats)* |

**Examples** (2-player match, `active_slots = [1, 2]`):

| Round | Slot 1 | Slot 2 |
|---|---|---|
| 1 | spawn[0] | spawn[1] |
| 2 | spawn[1] | spawn[0] |
| 3 | spawn[0] | spawn[1] | *(cycle repeats)* |

Over a 10-round match, no slot occupies the same spawn for more than 3 rounds (4-player) or 5 rounds (2-player) — fair distribution.

### Formula 2: Match-win check

```
match_won_slot(scores_by_slot, match_target) :=
    winners := [slot for slot in scores_by_slot if scores_by_slot[slot] >= match_target]
    if len(winners) == 1: return winners[0]
    if len(winners) == 0: return -1  # no winner yet
    # tiebreak (defensive, shouldn't trigger under tie-no-point rule)
    max_score := max(scores_by_slot[w] for w in winners)
    return min(w for w in winners if scores_by_slot[w] == max_score)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `scores_by_slot` | dict[int, int] | per-slot 0..∞ | Round Flow internal | Wins per slot |
| `match_target` | int | 1..50 (default 10) | MatchContext | `first_to_n_match_target` |

**Returns**: winning slot (≥1), or `-1` if no winner.

**Example**: `scores = {1: 10, 2: 7, 3: 6}`, `match_target = 10` → returns `1`.

### Formula 3: Respawn delay timer

```
respawn_complete(t_now, t_round_ended) := (t_now - t_round_ended) >= RESPAWN_DELAY_S
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `t_now` | float (s) | wall clock | engine | Current time |
| `t_round_ended` | float (s) | wall clock | Round Flow internal | Time `round_ended` was emitted |
| `RESPAWN_DELAY_S` | float (s) | 0 – 10 (default 3.0) | tuning knob | Inter-round delay |

**Returns**: boolean. `True` → trigger next round-start sequence (Rule 5).

**Example**: round_ended fires at `t = 45.000 s` with default `RESPAWN_DELAY_S = 3.0`. Next round starts at `t = 48.000 s`.

### Formula 4: Kill-cam delay timer

```
kill_cam_complete(t_now, t_round_end_started) := (t_now - t_round_end_started) >= KILL_CAM_DELAY_S
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `t_round_end_started` | float (s) | wall clock | Round Flow internal | Time Rule 7 entered (alive_count fell to ≤1) |
| `KILL_CAM_DELAY_S` | float (s) | 0 – 2 (default 0.5) | tuning knob | Delay between round-deciding kill and `round_ended` signal emit |

**Returns**: boolean. `True` → emit `round_ended` + free bodies + check match-win.

**Example**: last enemy dies at `t = 30.000 s`. Kill-cam runs from `t = 30.000` to `t = 30.500 s`. `round_ended` fires at `t = 30.500 s`. With default `RESPAWN_DELAY_S = 3.0`, next round starts at `t = 33.500 s`. Total inter-round gap: 3.5s (kill-cam + respawn delay).

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Two players die same tick (rapid-fire burst hits two victims simultaneously) | Both `Combat.player_eliminated` events processed sequentially per Godot signal queue. First event: alive_count drops from 2→1 → Rule 6 routes to Rule 7 with survivor as winner. Second event: alive_count drops from 1→0; Rule 7.1 re-entry guard catches it (`round_in_progress == false` already); ignored. **Round still ends with original survivor as winner.** | Per signal-order semantics; deterministic |
| Last 2 alive die same tick (true mutual kill) | Both events queued. First event: alive_count drops 2→1; Rule 6 routes to Rule 7 with the (still-alive) other slot as winner. Second event arrives; Rule 6.1 already-eliminated guard catches it (target was already false); ignored. **The "survivor" of the first event then dies via the second event — BUT the second event's already-eliminated guard fires BEFORE Rule 7.1's re-entry guard.** **CRITICAL**: in this corner case, Rule 6.1's guard fires on the *first* tick's processing of the second event, and the second event's `set alive_by_slot[v] = false` IS skipped. Net: the round ends with the "first-survivor" as winner, even though they're now in fact dead. This is a known limitation — Round Flow processes signals in queue order, not via simultaneous resolution. Acceptable for v1 (rare; concept-doc-permitted tie). If desired, can be made stricter in v1.x via single-tick coalescing. | Documented limitation; favors signal-order determinism over true simultaneous-resolution complexity |
| All players die same tick (true 4-way mutual kill in 4P match) | Process events in queue order. After first 3 events: alive_count = 1, Rule 7 triggers with the 4th-queued slot as "winner." When the 4th event arrives, Rule 6.1 already-eliminated guard catches the survivor (alive_by_slot[survivor] now false after Rule 7 hasn't actually mutated alive_by_slot — re-check: alive_by_slot[v] is set in Rule 6.2 BEFORE the alive_count check. So 4th event sets survivor to false, alive_count = 0, Rule 6.4 routes to Rule 7 with winner_slot = -1). Rule 7.1 re-entry guard catches this; ignored. **Net: round ends with the 4th-queued-victim as "winner" (the false survivor)**. Edge-case mis-attribution. Same v1 limitation as row above; mark for v1.x improvement. | Concept-doc-permitted tie; rare; mark as known v1 limitation |
| Controller disconnect mid-round (Rule 13 fires) | Treated as elimination with `killer_slot = -1`. No score credit. Round-end check runs. If disconnect leaves 1 alive → round ends with survivor as winner; if leaves 0 alive (1v1 with disconnect from sole opponent) → tie. | Per Rule 13 + concept doc edge case "Player is eliminated immediately; round continues" |
| Controller reconnect mid-round | CouchInput handles slot reclamation (per CouchInput Rule 5); reconnected slot is eligible for *next* round-start (Rule 5 reads `active_slots`). NOT re-spawned mid-round. | Per concept Edge Case + CouchInput Rule 5; Round Flow is passive observer |
| All controllers disconnect during InMatch | GSM auto-pauses (synthetic transition per GSM Edge Case + CouchInput Rule 11). Round Flow's timers freeze via `get_tree().paused`. State preserved; match resumes on reconnect. | Per GSM Edge Case "dog tripped over wires"; no Round Flow special handling |
| Match-end fires during respawn delay (last round's score change caused match-win, but Rule 8 already checked) | Cannot happen — Rule 8 (match-win check) runs in Rule 7.7, BEFORE Rule 9 (respawn delay) starts. If match-win is detected, Rule 9 is skipped entirely. | Sequence: Rule 7 → Rule 8 → branch: Rule 10 (match-end) OR Rule 9 (respawn delay). Mutually exclusive |
| Score reaches threshold from a tie round (impossible) | Cannot happen — tie awards no point per Rule 7.3 second branch. Match-win check (Rule 8) sees no score change. | Logical impossibility under current rules |
| `MatchContext.match_target` is 0 or negative (config error) | Defensive: clamp to `max(1, match_target)` at Rule 4 init time; log warning. Match ends after 1 round. | Pragmatic; bad config shouldn't crash |
| `MapResource.spawn_points.size() < active_slots.size()` (map has fewer spawns than players) | Build-time validator catches this (per Map Rule 9 + Edge Case "fewer than 4 spawn points"). At runtime if it slips through: spawn_index formula wraps via modulo on active_slots length, but maps to invalid index. Defensive: clamp `spawn_index = min(formula_result, spawn_points.size() - 1)`. | Validator is primary defense; runtime clamp is fallback |
| 2-player match (only 2 active slots) | `active_slots = [1, 2]`; Formula 1 rotates between spawn[0] and spawn[1]; spawn[2] and spawn[3] unused but still defined on map. All round/match logic slot-agnostic — dict-based scaling. | 2-player is the MVP target; explicitly supported |
| 1-player match attempted (e.g., all but one disconnect at MatchSetup) | MatchSetup wouldn't allow start (per CouchInput Rule 5 / Edge Case "Disconnect of a Ready slot reverts all other Ready slots to Locked"). Defensive: if Rule 4 sees `active_slots.size() < 2`, abort match — emit `match_won(active_slots[0])` or `match_aborted` (TBD signal in GSM). | Edge case for broken state; defer aborting signal to GSM Open Question resolution |
| Player dies during respawn delay (cannot happen — no live bodies) | Cannot happen by construction. During RespawnDelay state, no `PlayerCharacterBody` instances exist (Rule 7.6 frees them). No collision possible; no Combat signal possible. | Stateful guarantee |
| `Combat.player_eliminated` fires after `round_ended` (late signal) | Rule 6.1 already-eliminated guard catches it (alive_by_slot was cleared in Rule 12 cleanup OR will be re-initialized at next round-start Rule 5.3 with fresh alive=true values — neither path produces a false round-end). Defensive guards prevent spurious round-end retrigger. | Defensive guards layered across Rules 6.1 and 7.1 |
| Round Flow signal subscribers (HUD, Visual FX) take >1 frame to process `round_ended` | Acceptable. Round Flow's kill-cam delay (0.5s) + respawn delay (3s) gives subscribers plenty of slack. No frame-perfect ordering requirement for downstream consumers. | Round Flow is intentionally slow-paced at round boundaries |
| Pause exactly at match-end (player presses Start the same tick `match_won` emits) | Pause is rejected — by the time the GSM processes pause request, state has transitioned to MatchEnd, where Pause is not permitted (per GSM Core Rule 7 + State table). | GSM owns this rejection |
| User quits to MainMenu mid-match | GSM transitions to MainMenu; Round Flow exit cleanup (Rule 12) frees everything. MatchContext discarded by GSM (per GSM Rule 3). No "are you sure?" in v1 (per GSM Open Question — deferred). | Per GSM behavior |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| **Game State Manager** | Round Flow depends on GSM | Subscribes to `state_changed` for InMatch entry/exit (Rule 2); reads `MatchContext` Resource (Rule 4); writes final results to `MatchContext` (Rule 10); emits `match_won(winner_slot)` GSM consumes |
| **Map** | Round Flow depends on Map | Calls `MapLoader.load(map_id)` on InMatch entry (Rule 4.5); reads `MapResource.spawn_points` per round (Rule 5.3, Formula 1); calls `MapLoader.unload()` on exit (Rule 12) |
| **Combat** | Round Flow ↔ Combat | Emits `round_started(MatchContext, round_index)` Combat consumes per Combat Rule 11; emits `round_ended(winner_slot, round_index)` Combat consumes per Combat Rule 12; subscribes to `Combat.player_eliminated(victim_slot, killer_slot, projectile_id)` for alive tracking + round-end detection (Rule 6) |
| **Movement** | Round Flow depends on Movement | Instantiates `PlayerMovement` as child of each `PlayerCharacterBody` at round-start (per Movement Rule 1); frees Movement+CC instances at round-end after kill-cam delay (Rule 7.6). Does NOT call `Movement.set_dead()` — Combat owns that |
| **Character Controller** | Round Flow depends on CC | Instantiates `PlayerCharacterBody` per active slot at round-start with `slot: int` field set (CC Rule 14); sets initial position to assigned spawn point (Formula 1); frees all CCs at round-end (Rule 7.6) |
| **Couch Input** | Round Flow depends on CouchInput | Subscribes to `controller_disconnected(slot)` for mid-round elimination (Rule 13); reads slot↔clan mapping from `MatchContext` (which CouchInput populates during MatchSetup) |
| **HUD** (forward contract — undesigned) | HUD depends on Round Flow | Subscribes to `round_started`, `round_ended`, `score_changed`, `match_won`; queries `get_score`, `get_round_index`, `get_alive_count`, `is_round_in_progress` |
| **Visual FX** (forward contract — undesigned) | Visual FX depends on Round Flow | Subscribes to `round_started` (spawn flash), `round_ended` (round-clear FX); reads dead-body state during kill-cam window |
| **Audio** (forward contract — undesigned) | Audio depends on Round Flow | Subscribes to `round_started`, `round_ended`, `match_won` for music transitions + stings |

**External dependencies:**
- Godot 4.6 autoload system (RoundFlow registered as `RoundFlow` autoload)
- Godot 4.6 signal system (subscribe + emit)
- Godot 4.6 `SceneTree.paused` (frozen during Paused state per Rule 11)
- Godot 4.6 `Timer` node OR `await get_tree().create_timer(...).timeout` (kill-cam + respawn delays)
- Godot 4.6 `dict` + `Array[int]` (per-slot tracking)

**Bidirectional consistency checks** (cross-referencing the 6 approved dep GDDs):

- ✅ GSM GDD Interactions table row for Round Flow (line 76): says "Round Flow emits `match_won(winner)` → GSM transitions InMatch → MatchEnd" — **matches Rule 10.4**. ✓
- ✅ GSM GDD line 77: "Round Flow writes per-round score updates to `MatchContext`" — **matches Rule 10.1-3** (we write final state, not per-round; minor wording difference but compatible). ✓
- ✅ GSM Dependencies table line 140: "Round Flow depends on GSM" — present. ✓
- ✅ Map GDD Interactions table row for Round Flow (line 99): "Reads `MapResource.spawn_points` at round start; reads currently-loaded map ID from `MatchContext`" — **matches Rule 5.3 + Rule 4.5**. ✓
- ⚠️ Map GDD Loading state (line 88): doesn't credit *who* calls `MapLoader.load()`. **Cross-system fix #1 queued.**
- ✅ Combat GDD Dependencies row for Round Flow (line 288): "Round Flow signals `round_started(MatchContext)` + `round_ended()` — Combat consumes per Rules 11, 12. Round Flow consumes `player_eliminated`" — **matches Rules 5.5, 7.5, 6**. ✓
- ⚠️ Combat GDD signal signature: writes `round_started(MatchContext)` (1 arg). This GDD writes `round_started(MatchContext, round_index)` (2 args). **Cross-system fix #2 queued: align Combat GDD signal to 2-arg signature** (Combat doesn't use `round_index`, but signature must match).
- ✅ Movement GDD Dependencies row for Round Flow (line 353): "Round Flow depends on Movement... instantiates PlayerCharacterBody + child PlayerMovement at round start... controls free timing for kill-cam... frees all surviving instances at round end" — **matches Rule 5.3 + Rule 7.6**. ✓
- ✅ CC GDD Dependencies row for Round Flow (line 210): "Round Flow depends on CC... Instantiates PlayerCharacterBody instances at round start at assigned spawn points; frees them at round end or on death" — **matches Rule 5.3 + Rule 7.6**. ✓
- ✅ CC GDD Rule 14: slot field set by Round Flow at instantiation — **matches Rule 5.3**. ✓
- ✅ CouchInput GDD Dependencies row for Round Flow (line 205): "Round Flow depends on CouchInput. Subscribes to `controller_disconnected(slot)` for mid-round elimination; reads slot↔clan mapping via `MatchContext`" — **matches Rule 13**. ✓
- ⚠️ CouchInput GDD: `controller_disconnected(slot)` signal name appears in Interactions table (line 120, 205) but NOT in Core Rules signal list (Rule 7 enumerates `throw_pressed, pause_requested, menu_confirm, menu_cancel, menu_direction` only). **Cross-system fix #3 queued: add `controller_disconnected(slot)` to CouchInput Core Rule 7 explicit signal list.**

**Concept doc consistency** (`design/gdd/game-concept.md`):

- ✅ Round Flow dep row (line 368): "Combat, Movement, Map, Game State Manager, Couch Input" — **matches this GDD** (plus CC implicit via Movement). ✓
- ⚠️ Concept doc adds CC indirectly via Movement; this GDD lists CC as a direct dep (Round Flow directly instantiates `PlayerCharacterBody`). **Cross-system fix #4 queued: concept doc should add CC to Round Flow's "depends on" list.**
- ✅ Tuning knob `round_time_cap_s` (line 392): "60-90s (or none)" — this GDD picks "none" for v1. Concept doc range still valid; **cross-system fix #5 queued: pin to "None (locked in v1)" in concept doc**.
- ✅ Tuning knob `first_to_n_match_target` (line 393): "N = 10 (TowerFall default)" — **matches this GDD** (Rule 3, `match_target = 10` default). ✓
- ✅ Tuning knob `respawn_delay_s` (line 394): "3-5 s" — this GDD pins to 3.0s. **Cross-system fix #6 queued: pin to 3.0s in concept doc.**
- ⚠️ Concept Edge Case "Round ends with no kills (stalemate)" (line 345): "Sudden-death mechanic to be designed" — **resolved to "No stalemate mechanic in v1; rounds run indefinitely until kill"**. **Cross-system fix #7 queued: update concept doc edge case row.**
- ⚠️ Concept Edge Case "Two players die in the same frame" (line 346): "Both deaths register; round may end in tie. No tie-break in v1 (no one banks the round win)" — **matches** but this GDD adds the specific corner-case limitation (last-2-mutual-kill produces signal-order-dependent attribution). **Cross-system fix #8 queued: enrich the edge case row with the v1 limitation note.**

**Systems-index consistency** (`design/gdd/systems-index.md`):

- ✅ Row #8 (line 40): "Round Flow | Feature | MVP | Not Started | — | Game State Manager, Combat, Movement, Map, Couch Input, Character Controller" — **matches this GDD's 6 deps**. ✓ (Status will change to Approved after design-review.)
- ✅ Feature Layer row 8 (line 106): "Round Flow — depends on: Game State Manager, Combat (kill events), Movement (death trigger), Map (spawn points), Couch Input (`controller_disconnected` for mid-round elimination), Character Controller (instantiates `PlayerCharacterBody` at round start)" — **matches**. ✓
- ✅ Progress Tracker will move 7→8 designs / 7→8 approved post-review.

**All 8 cross-system fixes batched for post-design step (Phase 5c).**

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `RESPAWN_DELAY_S` | 3.0 s | 0 – 10 s | More breathing room between rounds; risks momentum loss | Tighter rhythm; couch may feel rushed; <1s is jarring |
| `KILL_CAM_DELAY_S` | 0.5 s | 0 – 2 s | More dramatic kill moment; longer total inter-round gap | Snappier round-end; less HUD/audio register time for kill |
| `MATCH_TARGET_DEFAULT` | 10 | 3 – 50 | Longer matches; more rounds to enjoy game-feel iteration | Shorter matches; faster session rotation; less chance for skill to assert |
| `SPAWN_ROTATION_MODE` | `"cyclic"` (Formula 1) | `"cyclic"` / `"random"` / `"fixed"` | `"random"` adds variance; `"fixed"` violates Pillar 2 spirit | (default) `"cyclic"` is deterministic, fair across 10-round arc |
| `ROUND_TIME_CAP_S` | `None` (no cap, v1) | `None` / 30 – 180 s | Adds stalemate-breaker (when defined for v1.x); shorter cap = more forced action | (default) `None` lets game-feel drive pacing |
| `STALEMATE_BEHAVIOR` | `"none"` (no cap → no stalemate handling) | `"none"` / `"kill_all"` / `"shrinking_arena"` / `"hunter_buff"` | Defines what happens when ROUND_TIME_CAP_S is non-null; v1.x decision | (default) `"none"` because no cap in MVP |

**Referenced from other systems (not owned here):**

- `MATCH_CONTEXT_SCHEMA` (GSM-owned, currently under-specified) — Round Flow reads `map_id`, `active_slots`, `match_target`; writes `final_scores`, `winner_slot`, `rounds_played`. Schema should be formalized in GSM GDD.
- Per-system tuning that affects round duration indirectly: `DODGE_IFRAME_DURATION_S` (Movement; longer = more stalemates), `SHURIKEN_THROW_VELOCITY` (Combat; faster = quicker kills), `STASH_MAX` (Combat; more shurikens = longer rounds).

**Interactions to watch:**

- `RESPAWN_DELAY_S` × `KILL_CAM_DELAY_S`: total inter-round gap = sum (default 3.5 s). If both pushed up, gap balloons; if both 0, transitions feel glitchy. Tune together.
- `MATCH_TARGET_DEFAULT` × `RESPAWN_DELAY_S`: total match duration ≈ rounds × (avg round + KILL_CAM + RESPAWN). At 10 rounds × 60s = 10 minutes. Tune to keep matches in the 15-45 min target band (per concept).
- `ROUND_TIME_CAP_S` × `STALEMATE_BEHAVIOR`: meaningless when cap is None. If activating cap in v1.x, must pick a behavior simultaneously.
- `SPAWN_ROTATION_MODE` × `MapResource.spawn_points` count: cyclic rotation produces fair distribution iff spawn_points.size() >= active_slots.size(). Map validator guarantees this.

**Not knobs**: tie behavior (locked to "no point awarded" per Decision 3); match-end timing (locked to "deciding round's round-end" per Decision 7); body lifecycle (locked to "free at round-end" per Decision 8); MatchContext schema (architectural, owned by GSM); identical-across-clans (locked by Pillar 2).

**Concept doc updates required** (queued for post-design step):
- `respawn_delay_s` row: pin to **3.0 s**.
- `first_to_n_match_target` row: already matches (N=10) — no change.
- `round_time_cap_s` row: pin to **None (locked in v1; sudden-death deferred to v1.x)**.

## Visual/Audio Requirements

Round Flow is infrastructure — visuals and audio are owned by HUD, Visual FX,
and Audio systems (all undesigned). This section is a *contract* of what
Round Flow exposes to those systems and what feedback the player should
receive at each round-flow event.

**Round Flow exposes** (events HUD / Visual FX / Audio subscribe to):

| Event | Visual hook | Audio hook |
|---|---|---|
| `round_started(MatchContext, round_index)` | Round-number badge briefly visible ("ROUND 3"); spawn-flash on each PlayerCharacterBody | Round-start sting (short, restrained) |
| `score_changed(slot, new_score)` | Scoreboard tick animation on winner's clan tile | Tally beep (subtle) |
| `round_ended(winner_slot, round_index)` | Round-clear overlay (brief, ~0.5s before respawn delay); winner-clan flash | Round-end sting + transition tone |
| `match_won(winner_slot)` | Match-end transition; winner spotlight; final scoreboard | Match-win fanfare (most prominent stinger in the game) |
| Kill-cam window (0.5s during RoundEnding state) | Time-dilated VFX optional; freeze-frame on round-deciding kill optional | Hit-stop SFX (per concept doc "snappy hit-stop on kills") |

**Restraint constraints** (Pillar 1: *Restraint over Spectacle*):

- No 3-2-1 countdown before round-start. Players spawn, round begins.
- No "ROUND X — FIGHT!" overlay. A small unobtrusive round-counter on HUD only.
- No victory pose / cinematic on round winner. They simply remain standing.
- Match-end may have *one* moment of celebration (per concept: *"victory screen; score recap"*). Reserved for `match_won`, not per-round.

**HUD reads** (per-frame queries):
- Scoreboard: `get_score(slot)` for each active slot
- Round counter: `get_round_index()`
- Alive indicator: `get_alive_count()` or `alive_by_slot` dict (TBD how exposed)

**Forward contract for HUD GDD**: HUD must subscribe to all 4 signals + poll the 3 queries every frame OR cache via signal-driven updates.

**Forward contract for Audio GDD**: Music transitions should align with round state — louder/tense during RoundActive, softer during RespawnDelay. Per concept: ~3-5 music tracks; Audio may choose one per match state.

## UI Requirements

The two screens Round Flow directly informs:

**In-match HUD** (always visible during RoundActive + RespawnDelay):
- Per-slot clan tile (color + emblem) with stash count (from Combat) and current round wins (from Round Flow)
- Small round counter ("Round N of first-to-M") — unobtrusive, corner-positioned
- Kill feed (from Combat's `player_eliminated`) — fades after ~3s

**MatchEnd screen** (post `match_won`):
- Winner's clan emblem large, centered
- Final scoreboard (all slots, round wins, listed in score order)
- "Play Again" → MatchSetup with same `MatchContext` (per GSM Rule 9)
- "Back to Menu" → MainMenu (discards MatchContext per GSM Rule 3)

**Forward contracts**:
- HUD GDD owns the in-match HUD layout, scoreboard ergonomics, kill-feed UX
- UI Flow GDD owns the MatchEnd screen navigation + Play-Again hookup
- Round Flow contributes: `get_score`, `get_round_index`, `alive_by_slot`, `match_won`, `score_changed`, `MatchContext.final_scores/winner_slot/rounds_played`

**Accessibility considerations** (deferred to accessibility-specialist per concept doc anti-pillar 1.x scope):
- Round Flow should NOT use color alone to indicate round winner (colorblind safety) — winner's clan emblem must be readable in monochrome
- Match-win fanfare should have visual equivalent for hearing-impaired players (large emblem + score)
- Respawn delay countdown (if added in v1.x) should be both visual and audio

## Acceptance Criteria

### InMatch entry

- [ ] GSM transition to InMatch triggers Round Flow's entry sequence (Rule 4) within ≤1 frame
- [ ] `active_slots` populated from `MatchContext` (matches CouchInput's MatchSetup output)
- [ ] `scores_by_slot` initialized to 0 for each active slot
- [ ] `round_index = 0` on entry; becomes 1 after first round-start
- [ ] `MapLoader.load(map_id)` called; map scene live before round-start begins
- [ ] Round-start sequence (Rule 5) fires for round 1

### Round-start

- [ ] `round_index` increments by 1
- [ ] Spawn assignment matches Formula 1 (cyclic rotation): round 1 slot N → spawn[N-1]; round 2 slot N → spawn[N]; etc.
- [ ] For each active slot: `PlayerCharacterBody` instantiated with correct `slot` field (CC Rule 14)
- [ ] `PlayerMovement` added as child of each `PlayerCharacterBody`
- [ ] CC positioned at correct spawn point
- [ ] `alive_by_slot[slot] = true` for each active slot
- [ ] `round_in_progress = true`
- [ ] `round_started(MatchContext, round_index)` emitted; Combat receives + refills stashes

### Player elimination tracking

- [ ] `Combat.player_eliminated` event: `alive_by_slot[victim] = false`
- [ ] Already-eliminated guard (Rule 6.1) ignores duplicate elimination events for same victim
- [ ] Round continues while `alive_count >= 2`
- [ ] Round-end triggered when `alive_count <= 1`

### Round-end

- [ ] Round-end re-entry guard (Rule 7.1) ignores duplicate round-end attempts (same-tick)
- [ ] `round_in_progress = false` after round-end entered
- [ ] Winner with `slot >= 1` gets `+1` to `scores_by_slot`; `score_changed` emitted
- [ ] Tie (`winner_slot == -1`) awards no point; no `score_changed` emitted
- [ ] Kill-cam delay of `KILL_CAM_DELAY_S` (default 0.5s) elapses before `round_ended` emit
- [ ] `round_ended(winner_slot, round_index)` emitted; Combat receives + cleans projectiles
- [ ] All `PlayerCharacterBody` instances (alive + dead) freed at round-end
- [ ] `player_bodies` dict cleared after free

### Match-win + match-end

- [ ] Match-win check runs in Rule 7.7 (after kill-cam, after round-end emit)
- [ ] If exactly one slot reaches `match_target`, match-end triggered
- [ ] Final scores written to `MatchContext.final_scores`
- [ ] `MatchContext.winner_slot` set correctly
- [ ] `MatchContext.rounds_played` reflects total rounds in match
- [ ] `match_won(winner_slot)` emitted; GSM transitions to MatchEnd
- [ ] If no match-win, Rule 9 (respawn delay) fires instead

### Inter-round respawn delay

- [ ] `RESPAWN_DELAY_S` (default 3.0s) elapses between `round_ended` emit and next round-start
- [ ] During respawn delay: `round_in_progress = false`; no player bodies in scene
- [ ] Next round-start (Rule 5) fires automatically on timer expiry

### Mid-round controller disconnect

- [ ] `controller_disconnected(slot)` while alive + round in progress: treated as elimination (no killer attribution)
- [ ] Round-end check runs; round may end if survivor count drops to ≤1
- [ ] No score credit for disconnected slot's death (`killer_slot = -1`)

### All-controllers-disconnected

- [ ] GSM auto-pauses (per GSM Edge Case)
- [ ] Round Flow timers freeze via `get_tree().paused`
- [ ] Resume on reconnect continues from frozen state

### InMatch exit cleanup

- [ ] User quit to MainMenu mid-match: all bodies freed; state cleared
- [ ] Match-end natural exit: state cleared; `MatchContext` retained for MatchEnd UI
- [ ] `MapLoader.unload()` called on exit

### Spawn rotation invariants

- [ ] Across 10 rounds (4-player match), each spawn point used 2-3 times per slot (fair distribution)
- [ ] Same `(round_index, slot, active_slots)` always produces same spawn assignment (deterministic)
- [ ] 2-player match: spawn assignment alternates between spawn[0] and spawn[1] each round

### Cross-system integration (verified at consumer side)

- [ ] Combat receives `round_started` + refills stashes (Combat-side test)
- [ ] Combat receives `round_ended` + cleans projectiles (Combat-side test)
- [ ] Combat's `player_eliminated` correctly routed to Round Flow (this side test)
- [ ] CouchInput's `controller_disconnected` correctly routed (this side test)
- [ ] GSM transitions InMatch ↔ MatchEnd on `match_won` (GSM-side test)
- [ ] Map's `MapLoader.load`/`unload` called correctly (Map-side test)

### Performance

- [ ] Round-start sequence (Rule 5): instantiate + signal emit completes within ≤16.6 ms (1 frame at 60 fps) for up to 4 slots
- [ ] Round-end sequence (Rule 7 first phase, pre-kill-cam): branch + score update completes within ≤1 ms
- [ ] `player_eliminated` signal handler (Rule 6): branch + alive-count check completes within ≤0.5 ms
- [ ] Round Flow per-frame overhead (idle in RoundActive): ≤0.1 ms (essentially zero — no per-tick work)

### Stash invariants (cross-checked with Combat)

- [ ] At round-start, every active slot's stash is exactly `STASH_MAX` (verified by Combat's stash_changed signals)
- [ ] At round-end + cleanup, all live projectiles are freed (verified by scene tree count)

### Code hygiene

- [ ] Round Flow is autoload registered as `RoundFlow`
- [ ] All tuning knobs (Section G) exposed via config Resource, not hardcoded
- [ ] No direct GSM state mutation (only `request_transition` calls)
- [ ] No direct `MatchContext` mutation outside Rules 4 + 10 (well-scoped writes)
- [ ] Signal payloads are typed (`signal round_started(MatchContext, round_index: int)`)
- [ ] All public queries (`get_score`, `get_round_index`, `get_alive_count`, `is_round_in_progress`) documented with semantics
- [ ] Spawn rotation formula (Formula 1) implemented as a pure function, unit-testable in isolation

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| **Map GDD Loading state** should credit Round Flow as caller of `MapLoader.load()`. | post-design step | This GDD's Phase 5c | Queued for cross-system batch |
| **Combat GDD signal signature mismatch**: Combat lists `round_started(MatchContext)` (1 arg); this GDD emits `round_started(MatchContext, round_index)` (2 args). Align Combat to 2-arg. | post-design step | This GDD's Phase 5c | Queued for cross-system batch |
| **CouchInput Core Rule 7** doesn't list `controller_disconnected(slot)` in explicit signal list (only in Interactions table). | post-design step | This GDD's Phase 5c | Queued for cross-system batch |
| **Concept doc Round Flow dep row** should add Character Controller (Round Flow directly instantiates CC, not just indirectly via Movement). | post-design step | This GDD's Phase 5c | Queued for cross-system batch |
| **Concept doc Tuning Knobs**: pin `respawn_delay_s = 3.0`, `round_time_cap_s = None`, update Edge Case row for stalemate behavior. | post-design step | This GDD's Phase 5c | Queued for cross-system batch |
| **GSM `MatchContext` schema** is under-specified. Round Flow now writes 3 new fields (`final_scores`, `winner_slot`, `rounds_played`) AND reads `map_id`, `active_slots`, `match_target`. | GSM GDD author + game-designer | Before HUD/UI Flow implementation | Recommend documenting the full schema; most natural home: GSM GDD or a new `match-context.md` resource doc |
| **Same-tick mutual-kill attribution** (last 2 alive die same tick): documented limitation that signal-order produces deterministic-but-arbitrary "winner." Acceptable for v1 (rare); single-tick coalescing is a v1.x option. | game-designer | Post-MVP playtest if observed | Accept as v1 limitation |
| **GSM Open Question on round-time-cap stalemate signal**: GSM asked if Round Flow emits `match_won(null)` or `match_aborted` for "nobody won" case. This GDD resolves: **NO stalemate in v1** (no time cap), so neither signal is needed. v1.x sudden-death design will need to revisit. | post-design step (note in GSM Open Questions) | This GDD's Phase 5c | Queued: mark GSM Open Question as "resolved for v1 by Round Flow design — no stalemate, no aborted-match signal needed" |
| **Map Open Question on spawn rotation**: Map asked if slot 1 always spawns at spawn[0]. Resolved: **cyclic rotation per Formula 1**. Update Map GDD Open Question. | post-design step | This GDD's Phase 5c | Queued: mark resolved |
| **MatchEnd "are you sure?" before discarding match** (GSM Open Question): Round Flow has no opinion — discard is GSM's call. Concept doc says no stat persistence in v1, so confirmation is unnecessary. | game-designer | v1.x if stats added | Deferred |
| **Spawn invulnerability frames at round-start**: should spawned players have brief i-frames (~0.5s) to prevent same-frame retaliation from a previously-thrown shuriken? Concept doc doesn't mention. **Probably not needed in MVP because Combat Rule 12 frees all live projectiles at round-end** — no inter-round carryover. Flagged for MVP playtest verification. | game-designer | MVP playtest | TBD; defer unless observed |
| **Tunable values are placeholders**: `RESPAWN_DELAY_S = 3.0`, `KILL_CAM_DELAY_S = 0.5`, `MATCH_TARGET_DEFAULT = 10`. MVP playtest priorities: respawn delay (the named "round-to-round rhythm" lever from concept), match target (calibrates total session time). | game-designer + Round Flow implementer | MVP playtest cycles | Defer to playtest |
| **Visual/Audio direction for round-start spawn flash, kill-cam, round-end overlay**: Round Flow exposes the events; art-director + audio-director own how they look/sound. | art-director + audio-director + Visual FX/Audio GDD authors | Before Visual FX/Audio GDDs approved | Forward contract |
| **HUD forward contract**: subscribe to all 4 signals + poll 4 queries; design scoreboard layout, round-counter ergonomics, kill-feed UX. | HUD GDD author | Before HUD GDD approved | Forward contract |
