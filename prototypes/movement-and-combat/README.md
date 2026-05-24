# Four Clans — Movement & Combat Prototype

**Status:** Prototype / vertical slice — throwaway code, standards intentionally relaxed.
**Engine:** Godot 4.6 · **Players:** local 2-player (gamepad or keyboard) · **Resolution:** 800×450.

**Hypothesis under test:** *Does the throw → dodge → retrieve loop feel fun in local 2-player play?*

![Four Clans gameplay — Sakura Temple arena](screenshots/04_gameplay.png)

---

## Screenshots

| Title | Mode select | Clan select | Map select |
|---|---|---|---|
| ![Title](screenshots/01_title.png) | ![Mode select](screenshots/02_mode_select.png) | ![Clan select](screenshots/02_clan_select.png) | ![Map select](screenshots/03_map_select.png) |

---

## What this is

A TowerFall-inspired couch-versus arena fighter. Two ninjas face off on a single
screen: throw shurikens, dodge to catch them out of the air, retrieve spent ammo,
and eliminate your opponent. It is built as a throwaway vertical slice to validate
the core combat *feel* before any production code is written.

---

## How to run

1. Open **Godot 4.6**.
2. **Project → Import →** select `project.godot` in this directory.
3. Press **F5** to launch. If prompted for the main scene, pick `Main.tscn`.

Plug in a controller before launching to play with a gamepad (recommended). A
DualSense (PS5) over USB or Bluetooth is detected automatically.

---

## Controls

### Gamepad — DualSense (primary)

Mapping follows the **TowerFall-on-PlayStation** layout. Player 1 = first connected
controller, Player 2 = second controller.

| Action | Button | Notes |
|---|---|---|
| Move / aim | **D-pad** or **Left Stick** | 8-directional; also aims throws and the dash |
| Jump | **Cross ✕** | double jump in air; wall-jump off walls; also confirms menus |
| Throw shuriken | **Square ▢** | **hold to aim** (reticle shows the 8-way direction), **release to fire**; a quick tap is a quick-draw. See *Throwing & aiming* below. |
| Dash-dodge | **L2**, **R2**, **Circle ◯** | one move: 8-way burst + i-frames that catch a shuriken (see below) |
| Katana | **Triangle △** | melee swing; deflects shurikens, damages enemies |

### Keyboard (Player 2)

**Player 1 is controller-only** (use the gamepad table above). Player 2 plays on the keyboard:

| Action | Key |
|---|---|
| Move / aim left | **A** |
| Move / aim right | **D** |
| Aim up | **W** |
| Aim down | **S** |
| Jump | **Space** |
| Throw shuriken | **L** (hold to aim, release to fire) |
| Katana | **K** |
| Dash-dodge | **Right Shift** or **double-tap A / D** |

The double-tap is P2-only (so the gamepad stick can't trigger it). On a gamepad the
dash-dodge is L2 / R2 / Circle, as in the table above.

### Menu navigation (any controller or the keyboard, on every screen)

- **Title** — any key or any controller button begins
- **Move cursor** — D-pad / stick, or A/D
- **Confirm** — **Cross ✕** / Space
- **Back / cancel** — **Circle ◯** / Esc
- **Un-confirm** a clan pick — down (D-pad / S)
- **Random map** — **Triangle △** / X

---

## Core mechanics

### Movement
- **Run** at a fixed top speed; **double jump** (one ground + one air jump, refreshed on landing).
- **Wall grab**: hold *into* a wall while airborne to slide down slowly.
- **Wall jump**: jump while wall-grabbing for an upward kick away from the wall.
- **Head-stomp**: land on an opponent's head to deal damage and bounce off.
- **Screen wrap**: fall off the bottom and reappear at the top (and vice-versa).

### Dash-dodge (L2 / R2 / Circle ◯)
**The dash and the dodge are one move** — a directional burst that *is* a dodge.
A short 8-way burst toward the held aim (incl. straight up and diagonals; gravity is
suspended for its duration so up/diagonal dashes hold a clean line), with brief
**invincibility frames** that **catch** an incoming shuriken straight into your stash
(or deflect it back if your stash is full).

- **Time it** — TowerFall-style: short i-frames then a **cooldown (~0.42 s)**, so you
  must dash *just before* a shuriken hits. Blanket-dashing won't catch them.
- **One air charge** — airborne you get exactly one until you touch a **floor or wall**
  (no infinite climbing). After spending it, the charge returns **0.5 s after** you land.
- **No glow** — the move reads from its dash pose/animation, not a flash.
- Direction comes from the stick/keys, not from which trigger you press.

**Shurikens vanish only on a clean hit.** Landing a damaging hit on an opponent spends the
blade and removes it — the *only* way a shuriken leaves the round. Every other interaction
keeps it in play and retrievable: a katana deflect or a shuriken-vs-shuriken counter sends
it flying off to stick somewhere, and a miss sticks where it lands. So blades only thin out
when someone actually gets hit.

### Throwing & aiming (TowerFall-style)
- **Hold** the throw button to aim: a clan-colored **reticle** appears showing which of
  the **8 directions** you're aiming, and you **stand still** (movement input becomes
  pure aim) — this makes diagonals easy. **Release** to fire that way.
- A quick **tap** is a *quick-draw* — fires immediately in the held/facing direction.
- Aiming freezes you only on the ground; in the air you keep your momentum (no
  air-control while aiming). Hold duration does not affect throw speed.

### Combat
- **5 HP** per life, shown as hearts above the ninja. Shurikens, katana hits, and
  head-stomps each deal **1 damage**; reaching 0 HP is an elimination.
- **Shuriken stash**: start with **3**, hold up to **5**. Throwing spends one; pick a
  spent shuriken back up by walking over it, or catch one mid-air with a dodge.
- **Katana**: **3 charges**. A swing **deflects** shurikens in front of you (free) and
  **strikes** an enemy for 1 damage (costs a charge).
- Brief hurt-invulnerability after a non-lethal hit prevents stun-locking.

---

## Match flow

1. **Title** — "FOUR CLANS". Press any input to begin.
2. **Mode select** — **P1 vs P2** / **P1 vs AI** / **AI vs AI** / **P1 vs 3 (FFA)**, plus AI
   difficulty (←/→ mode, ↑/↓ difficulty). See *Modes & AI* below.
3. **Clan select** — players pick from **Shadow / Storm / Frost / Fire** (same-clan picks
   rejected in duels). In **FFA** only P1 picks; the three bots take the remaining clans.
4. **Map select** — choose the arena.
5. **Match** — first to **5 round-wins** takes the match. A round runs until **one ninja is
   left standing** (the survivor scores), opening with a 3-2-1-FIGHT countdown and pausing
   ~1.6 s on the winner before the next round.
6. **Match end** — winning clan + final score; rematch or return to title.

## Modes & AI

| Mode | Who controls whom |
|---|---|
| **P1 vs P2** | both human (controller + keyboard) |
| **P1 vs AI** | you (P1) vs a bot (P2) — *beat the AI* |
| **AI vs AI** | both bots fight — *watch a demo* |
| **P1 vs 3 (FFA)** | you (P1) vs **three bots**, free-for-all — last ninja standing wins the round |

The bot has three skill tiers, named after ninja ranks — **GENIN** (already a competent
fighter), **CHUNIN** (hard), **JONIN** (brutal). Higher tiers dodge your shurikens more
reliably, fire faster, space tighter, and press melee harder. Even GENIN dodges, retrieves
ammo, throws on-line, jumps to chase, and swings up close. The match mode + tier is shown
top-right during a round.

---

## Map

**Sakura Temple** — a pagoda arena with layered platforms, lanterns, and a moonlit
backdrop. (Currently the only map in the prototype; spawn points are fixed.)

---

## Tuning knobs

A **live tuning panel** (sliders, bottom-left during a round) exposes the most
consequential balance levers:

1. **Dodge i-frame duration** (`0.20 s`)
2. **Shuriken throw velocity** (`600`)
3. **Pickup radius** (`12 px`)
4. **Self-hit immunity** window (`0.083 s`)
5. **Wall-grab fall speed** (`80`)

Dash feel is tuned by constants at the top of `player.gd`:
`SLIDE_SPEED` (400), `SLIDE_DURATION_S` (0.20), `SLIDE_COOLDOWN_S` (0.417),
`SLIDE_AIR_REFRESH_S` (0.5).

---

## Known limitations

- **Local 2-player only** — no online, no 4-player yet.
- **One map** (Sakura Temple).
- **Procedural beep SFX** generated at startup — no music or final sound design.
- Some **on-screen menu hints are stale** (e.g. they still list keyboard-only keys);
  the tables in this README reflect the actual bindings in `main.gd`.
- Maps and round flow are simplified prototype variants of the design-doc specs.

---

## After playtest

Record outcomes in [`REPORT.md`](REPORT.md). Decision criteria (from the concept doc):

- **PROCEED** — ≥3 of 5 first-time testers call the dodge timing "satisfying"/"fair" and voluntarily ask for a rematch.
- **PIVOT** — the loop works but a specific value or mechanic needs changing before MVP.
- **KILL** — the loop is not fun even with extreme tuning.
