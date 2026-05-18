# Movement and Combat Prototype

**Status**: PROTOTYPE — not production code. Throwaway. Standards intentionally relaxed.

**Question this prototype answers**: *Does the throw-dodge-retrieve loop with one-hit-kill rules feel fun in 2-player local play?*

---

## How to run

1. Open **Godot 4.6** (the project is pinned to 4.6 — see `docs/engine-reference/godot/VERSION.md`).
2. Import this directory as a project: **Project → Import → select `project.godot`**.
3. Press **F5** (or click ▶ Run) to launch.
4. First-run gotcha: if Godot prompts "Select Main Scene", pick `Main.tscn`.

If it fails to launch with errors, capture the error text from the bottom panel and report it — likely a Godot 4.6 API change vs. the GDScript I wrote (my training data covers ~4.3).

---

## Controls (keyboard, 2 players)

| Action | Player 1 (red) | Player 2 (blue) |
|---|---|---|
| Move left | **A** | **Left arrow** |
| Move right | **D** | **Right arrow** |
| Jump / Dodge (contextual) | **W** | **Up arrow** |
| Throw shuriken | **S** | **Down arrow** |
| Reset scores | **R** | **R** |

**A-button contextual rule**: If you're stationary on the ground, the jump button **dodges** (with i-frames). If you're moving or in the air, it **jumps**. Same TowerFall pattern.

**Visual cues**:
- **Yellow flash** on a player = i-frames active (they're invincible + can catch shurikens)
- **Grey** = dodge recovery (no i-frames but still locked from re-dodging)
- **Faded grey** = dead (waiting for respawn)
- Number above head = current stash (0–3)

---

## What to playtest

The hypothesis is **the throw-dodge-retrieve loop is fun**. Specifically:

### 1. Dodge timing (the named single most consequential balance lever)
- Default `dodge_iframe_duration_s = 0.20` (~12 frames @ 60 fps)
- Try **0.10** (very tight) → does it feel "unfair"?
- Try **0.30** (generous) → does it feel "stalemate-y"?
- Use the live tuning slider — adjust mid-match. The point is to find the value where the dodge feels like a *parry*, not luck.

### 2. Throw velocity (the named "reaction time required to dodge" lever)
- Default `shuriken_throw_velocity = 200 px/s`
- Try **400** → does the dodge become impossible?
- Try **100** → does it become trivially easy?
- The sweet spot is where reacting is *possible* but requires reading the throw.

### 3. Retrieval feel
- Default `pickup_radius_px = 12`
- Throw a shuriken into the wall. Walk near it. Does the pickup feel responsive? Magnetic? Too fiddly?

### 4. Self-hit immunity
- Default `self_hit_immunity_s = 0.083` (~5 frames)
- Throw down at your feet. Does the shuriken phase through cleanly?
- Try **0.0** → can you self-hit at spawn? (probably yes — annoying)

### 5. The core loop
- Play 5+ rounds (first to 5). After each round, ask yourself:
  - Did the kill feel earned by the killer?
  - Did the death feel fair to the victim?
  - Did the *next* round start fast enough to keep momentum?
- After 5 minutes: do you want to play another match?

---

## Known limitations of this prototype

- **No wall-jump** (deferred to v0.2 if loop is validated)
- **No one-way platforms / drop-through** (single flat floor only)
- **No screen-wrap** (walls bound the play area)
- **No 4-player** (2-player keyboard only — couch chaos test needs controllers + a group)
- **No clans, no menus, no audio, no real art** (colored rectangles only)
- **No round-end pause / kill-cam** (instant respawn after 2s timer)
- **Respawn auto-fires for both players on any kill** (no proper round/match flow — Round Flow GDD's logic is overkill for the validation question)

---

## After playtest

Fill in the `Result`, `Metrics`, and `Recommendation` sections of [`REPORT.md`](REPORT.md). Hypothesis + Approach are pre-filled.

Decision criteria from the concept doc MVP Acceptance Criteria:
- ✅ **PROCEED**: at least 3 of 5 first-time playtesters describe the dodge timing as "satisfying" or "fair"; at least 3 of 5 voluntarily request another match
- ⚠️ **PIVOT**: the loop is workable but a specific tuning value or mechanic needs to change before MVP commit
- ❌ **KILL**: the loop is fundamentally not fun even with extreme tuning — the project's core hypothesis fails

Per the concept doc: *"If this hypothesis fails in MVP testing, the project pivots or stops."*
