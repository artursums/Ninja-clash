# Movement and Combat Prototype — Vertical Slice

**Status**: PROTOTYPE — throwaway code, not production. Standards intentionally relaxed.

**Question this prototype answers**: *Does the throw-dodge-retrieve loop with one-hit-kill rules feel fun in 2-player local play?*

**Updated 2026-05-18**: extended to a vertical slice that simulates the full designed match flow (title → clan select → map select → match → match end).

---

## How to run

1. Open **Godot 4.6**.
2. Import this directory as a project: **Project → Import → select `project.godot`**.
3. Press **F5** to launch.
4. If Godot prompts "Select Main Scene", pick `Main.tscn`.

---

## The match flow (what F5 gets you)

1. **Title screen** — "FOUR CLANS". Press any key to enter.
2. **Clan select** — both players pick from Shadow / Storm / Frost / Fire.
   - P1: **A/D** to move cursor, **W** to lock in, **S** to un-lock
   - P2: **←/→** to move cursor, **↑** to lock in, **↓** to un-lock
   - Same-clan picks are rejected (other player must choose a different one)
   - **ESC** to back out to title
3. **Map select** — one player picks the arena.
   - **A/D** or **←/→** to navigate, **W** or **↑** to confirm
   - **X** = random map
   - **ESC** to back to clan select
4. **Match** — first to 5 round wins.
   - Round-start countdown (3-2-1-FIGHT)
   - One hit kills. Score increments. 1.5 s round-end pause shows winner.
   - Repeats until someone reaches 5.
5. **Match end** — winning clan + final score.
   - **W** or **↑** to play again (same arena, same clans)
   - **ESC** or **T** to return to title

**ESC during a match** = quit to title.

---

## Controls (during a round)

| Action | Player 1 | Player 2 |
|---|---|---|
| Move left | **A** | **Left arrow** |
| Move right | **D** | **Right arrow** |
| Jump (always; double-jump available after landing) | **W** | **Up arrow** |
| Crouch (visual squash only) | **S** | **Down arrow** |
| Throw shuriken | **Space** | **Enter** |
| Dodge (i-frames + dash) | **Left Shift** | **Right Shift** |

**Movement tricks**:
- **Double-tap a movement key** for a fast slide
- **Hold direction into a wall while airborne** for slow wall-slide
- **Wall-jump**: jump while wall-sliding

---

## Maps

4 arenas, all randomized spawn positions:

1. **Rooftop Garden** — open, 3 platforms (good first map)
2. **Pagoda Climb** — diagonal staircase, vertical traversal
3. **Twin Pillars** — symmetric, central pillar + bridges
4. **The Ridge** — divided lanes, central wall, wing ledges (newest)

---

## Visual cues (current placeholder art)

- **Clan-colored ninja silhouette** = base appearance
- **Yellow flash** = i-frames active (invincible + can catch shurikens)
- **Grey** = dodge recovery (no i-frames but still locked from re-dodging)
- **Cyan** = sliding
- **Purple** = wall-grabbing
- **Half-height squashed** = crouching (visual only — hitbox unchanged)
- **Faded grey** = dead (waiting for respawn next round)
- **Stash icons in HUD** dim when used (3 max per round)
- **Shuriken** = clan-colored 4-pointed star, spins while flying

---

## Audio (procedural beeps)

No audio assets shipped. Sounds are sine/square waves generated at startup:
- Throw / hit / dodge / countdown / round-start / win-fanfare

If beeps are annoying, mute your speakers — they're placeholder sound design.

---

## Live tuning panel (visible during rounds)

5 sliders at bottom-left for the named balance levers:
1. **Dodge i-frame duration** (single most consequential lever per concept doc)
2. **Throw velocity** (reaction time required to dodge)
3. **Pickup radius**
4. **Self-hit immunity** (spawn-throw self-hit window)
5. **Wall-grab fall speed** (0 = full hang, 80 = TowerFall slow descent, 200 = barely slows you)

Adjust mid-round to dial in the feel.

---

## Known limitations of this prototype

- **2-player keyboard only** (4-player needs controllers + group of friends)
- **Placeholder art** (silhouette SVG ninjas, colored rectangles for walls) — see `design/art-bible.md` for production direction
- **Procedural beep SFX** — no music, no real sound design
- **No menus past clan/map select** (no settings, no options, no clan-emblem detail)
- **Maps don't match `design/levels/launch-maps.md` exact coordinates** — these are 800×450 prototype variants of the spec'd 480×270 launch maps
- **Round flow is simplified** — Round Flow GDD specifies a 5-state machine; here it's a flat state-machine in the prototype's GameState autoload

---

## After playtest

Fill in `Result` / `Metrics` / `Recommendation` sections of [`REPORT.md`](REPORT.md).

Decision criteria from the concept doc MVP Acceptance Criteria:
- **PROCEED**: at least 3 of 5 first-time playtesters describe the dodge timing as "satisfying" or "fair"; at least 3 of 5 voluntarily request another match
- **PIVOT**: the loop is workable but a specific tuning value or mechanic needs to change before MVP commit
- **KILL**: the loop is fundamentally not fun even with extreme tuning — the project's core hypothesis fails
