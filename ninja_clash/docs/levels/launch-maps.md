# Four Clans — Launch Map Specs

> **Status**: Draft v0.1 — pending Creative Director + Game Designer review
> **Last Updated**: 2026-05-18
> **Maps spec'd**: 4 (Broken Bridge, Shrine Steps, Lantern Court, The Ridge)

This document specs the original arena layouts shipping at launch. Each map is provided with: ASCII layout, exact platform coordinates, spawn points, encounter flow, sight-line analysis, and tile budget. The production codebase consumes the coordinate tables verbatim.

**Originality clause**: No layout in this document reproduces or remakes any map from TowerFall, Duck Game, Samurai Gunn, Nidhogg, or any other copyrighted arena game. Broad arena-design patterns (e.g., "central pillar with symmetric platforms" is a classic 2P pattern across the entire genre) are referenced; every concrete layout is original.

---

## Critical Constraints Carried Forward from GDDs

- **Internal resolution**: 480 × 270 px (matches prototype `project.godot`), 16 × 16 tiles (30 × 17 cell grid).
- **Player body**: 20 px wide × 32 px tall.
- **Jump strength** (prototype): 480 px/s ground, 420 px/s air. **Gravity 1400 px/s²** (prototype).
- **Ground-jump peak height**: ≈ 82 px. **Ground + air jump combo max height**: ≈ 145 px.
- **Dodge dash**: 320 px/s × 0.30 s ≈ 96 px horizontal travel.
- **Slide**: 520 px/s × 0.22 s ≈ 114 px horizontal.
- **Wall-jump kick**: 280 px/s horizontal.
- **Shuriken throw velocity** (Combat GDD): 200 px/s flat. **Projectile gravity (GDD)**: 600 px/s².
- **Screen wrap**: horizontal enabled by default on every map (per Map GDD).
- **No hazards, no pickups** in v1.
- **Shurikens must always be 100% recoverable**: every map must pass the build-time recoverability validator (Map GDD).
- **4 spawn points per map**, all in open space.

> **⚠️ Gravity discrepancy (Open Question #1)**: The prototype's `player.gd` uses `GRAVITY = 1400`; the Combat GDD references Projectile gravity of `600`. The arc analyses in this document use the GDD value (600) as authoritative for throw arcs. The two gravity values cannot coexist in the same physics system. This must be reconciled before maps are implemented in production code.

> **Resolution discrepancy**: This document was drafted assuming 480×270 (per prototype `project.godot`). The Art Bible recommends 384×216 (cleaner 5× scale to 1080p). If the resolution decision goes to 384×216, all coordinate tables in this document must be re-scaled by a factor of 0.8. **Lock with art-director + technical-director before tile authoring begins.**

---

## 1. Map Design Principles

### Principle 1: No Escape Corner — Every Perch Has a Counter-Flank
No platform may be a terminal defensive position. If a player can occupy a high vantage, at least two approach routes must exist: direct (from below/adjacent) and wrap-assisted (exploiting horizontal screen-wrap). *Pillar tie: Fairness Is Sacred.*

### Principle 2: The Floor Is Always a Retrieval Surface
Every map's floor must be traversable within two seconds of normal walking from any spawn. Floor shurikens must rest on a surface reachable without a platform sequence. *Pillar tie: Every Shuriken Matters.*

### Principle 3: Two-Jump Vertical Budget
No platform may require more than one ground-jump plus one air-jump to reach from the floor (max height delta ≈ 145 px). If a map element should feel high, lower the floor — don't stack platforms beyond the jump budget. *Constraint: JUMP_STRENGTH=480, AIR_JUMP_STRENGTH=420, GRAVITY=1400.*

### Principle 4: Throw Arc Sight Lines Are a Design Tool
Platform edges are placed intentionally relative to throw trajectories. Each map spec notes which throws are blocked by which geometry. *Pillar tie: Game-Feel First.*

### Principle 5: 2P and 4P Mode Share One Layout
All four spawn points are authored on every map. 2P uses `spawn[0]` and `spawn[1]` via Round Flow Formula 1. 2P spawn pair must be far enough that neither player starts with a direct throw line. *Constraint: Round Flow Formula 1; Map Core Rule 7.*

### Principle 6: Shuriken Clutter Drifts Toward the Center
Platform slopes, walls, and floor topography are designed so missed shurikens drift toward the contested center, not pool in one player's "home corner." Achieved primarily by making central floor the largest unobstructed walking surface. *Pillar tie: Every Shuriken Matters.*

### Principle 7: Each Map Teaches One Skill Cluster First
The four launch maps collectively cover: vertical traversal, throw-arc prediction, wall-grab, retrieval routing, close-quarter dodge timing. Each map has one dominant skill — not by excluding others, but by creating situations where that skill resolves encounters fastest. Map Pool Order places the simplest skill-emphasis map first.

---

## 2. Map Roster

---

### Map 01: Broken Bridge

**One-sentence concept**: A wide, flat battlefield split by a collapsed central span, forcing players to contest a pair of low lateral platforms or risk the gap.

**Footprint**: 480 × 270 px

**Theme**: Crumbling stone bridge over a dark ravine. Ukiyo-e stonework. Night sky background.

**Recommended player count**: 2–4

**What This Map Teaches**: Throw-arc prediction across open horizontal space. Minimal vertical structure, longest unobstructed horizontal throw lines in the roster. This is the "first lesson" map.

#### ASCII Layout Sketch

One cell ≈ 16 px. Grid: 30 wide × 17 tall. Y increases downward.

```
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 0
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 1
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 2
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 3
. . . # # # # . . . . . . . . . . . . . . . # # # # . . . .   row 4   (high side ledges)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 5
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 6
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 7
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 8
. . . . . . . . # # # # . . . . . # # # # . . . . . . . . .   row 9   (mid gap platforms)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 10
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 11
.S1. . . . . . . . . . . . . . . . . . . . . . . . . .S2. .   row 12  (deck spawns)
# # # # # # # # # . . . . . . . . . . # # # # # # # # # # .   row 13  (bridge decks)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 14
.S3. . . . . . . . . . . . . . . . . . . . . . . . . .S4. .   row 15  (lower spawns)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #   row 16  (floor)
```

**Layout description**: Two bridge deck sections (9 tiles each / 144 px wide) at mid-height, separated by a 12-tile / 192 px central gap. Two high side ledges (4 tiles / 64 px) near top corners, reachable with ground-jump from deck. Two mid platforms (4 tiles / 64 px each) partially cover the central gap at row 9 but do not meet — an open center remains. Floor (row 16) runs full width.

**Counter-flank**: high ledges feel dominant but horizontal screen-wrap means an opponent can exit the right edge and arrive behind from the left.

#### Platform Coordinate Table

| # | Description | center_x | center_y | width | height | Tile type |
|---|---|---|---|---|---|---|
| 1 | Left bridge deck | 72 | 216 | 144 | 16 | Solid |
| 2 | Right bridge deck | 408 | 216 | 144 | 16 | Solid |
| 3 | High left ledge | 88 | 72 | 64 | 16 | Solid |
| 4 | High right ledge | 392 | 72 | 64 | 16 | Solid |
| 5 | Mid gap platform left | 152 | 152 | 64 | 16 | Solid |
| 6 | Mid gap platform right | 328 | 152 | 64 | 16 | Solid |
| 7 | Floor | 240 | 262 | 480 | 16 | Solid |

Horizontal screen-wrap enabled. No ceiling geometry (players can't reach y=0 under normal jump budget).

#### Spawn Points

| Spawn | 2P mode | 4P mode | Coordinates |
|---|---|---|---|
| S1 | Player 1 | Player 1 | (48, 200) — left bridge deck |
| S2 | Player 2 | Player 2 | (432, 200) — right bridge deck |
| S3 | — | Player 3 | (48, 246) — floor, left |
| S4 | — | Player 4 | (432, 246) — floor, right |

#### Encounter Flow
Both players open on elevated decks, roughly symmetric. Central gap forces immediate decision: cross via mid-gap platforms (exposed), retreat to high ledge (strong but flankable), or throw across and force a response. Retrieval naturally pools on floor beneath the gap — both players must expose to collect.

#### Sight Lines and Throw Arcs
- **Flat horizontal throw S1 → S2** (384 px, same elevation): at v=200, g=600, drop after 1.92 s ≈ 1106 px. A flat throw across the full gap from deck height **lands on the floor, not the opponent**. Players must aim upward — intentional, rewards arc reading.
- **High ledge → floor**: delta-y 190 px. Steep downward angle covers central floor — strong for harassing retrieval attempts.
- **Mid-gap platforms** block direct sight lines between decks at their elevation. A player crouching behind a mid-gap platform edge is safe from horizontal throws from the opposite deck.

#### Spawn Rotation Compliance
Cyclic rotation (Round Flow Formula 1) across 10 rounds (4P). No spawn provides shuriken-cache proximity advantage (no pickups v1). Floor spawns (S3, S4) start lower but are harder to throw-hit from decks above (thrower sacrifices arc range to aim down).

---

### Map 02: Shrine Steps

**One-sentence concept**: A staggered three-tier stepped arena ascending left-to-right, with a narrow top platform that dominates downward but invites wrap-around ambushes.

**Footprint**: 480 × 270 px

**Theme**: Stone shrine stairway ascending into mist. Mossy platform edges. Lanterns as non-interactive background.

**Recommended player count**: 2–4

**What This Map Teaches**: Vertical movement and positional read. Wall-grab is a viable tool — the left wall is a natural grab surface between steps.

#### ASCII Layout Sketch

```
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 0
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 1
. . . . . . . . . . . . . . . . . . . . . . . . . . # # # .   row 2   (top step — right)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 3
. . . . . . . . . . . . . . . . . # # # # # # . . . . . . .   row 4   (mid step — center-right)
. . . . . . . . . . . . . . . . . . . . . . S2 . . . . . .   row 5
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 6
. . . . . . # # # # # # # . . . . . . . . . . . . . . . .    row 7   (low step — center-left)
. . S1 . . . . . . . . . . . . . . . . . . . . . . . . S3 .   row 8
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 9
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 10
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 11
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 12
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 13
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 14
. . . . . . . . . . . . . . . S4 . . . . . . . . . . . . .   row 15
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #   row 16  (floor)
```

**Layout description**: Three staggered platforms ascending left-to-right. Low platform (7 tiles / 112 px) at center-left at row 7 (y≈112). Mid platform (6 tiles / 96 px) at center-right at row 4 (y≈64). Narrow top platform (3 tiles / 48 px) at top-right at row 2 (y≈32). No platform on the left side above floor — left-hand space is open vertical air. Left wall is a genuine wall-grab surface. Floor is full-width.

**Intentional asymmetry**: The roster's "tall" map. Left side is open air; right side is a stair of control points. Top step player has strong downward angle on everything, but left-wall + wrap can put an opponent behind them instantly.

#### Platform Coordinate Table

| # | Description | center_x | center_y | width | height | Tile type |
|---|---|---|---|---|---|---|
| 1 | Low step | 112 | 120 | 112 | 16 | Solid |
| 2 | Mid step | 264 | 72 | 96 | 16 | Solid |
| 3 | Top step | 424 | 40 | 48 | 16 | Solid |
| 4 | Floor | 240 | 262 | 480 | 16 | Solid |
| 5 | Left wall | 0 | 135 | 16 | 270 | Solid (wall-grab) |
| 6 | Right wall | 480 | 135 | 16 | 270 | Solid (wrap disabled this edge) |

**Asymmetric wrap (Open Question #2)**: This map disables horizontal screen-wrap on the right edge — right wall is solid geometry. Left-edge wrap remains enabled. Alternative: full horizontal wrap on both edges; remove the right solid wall. **Needs playtest validation.**

#### Spawn Points

| Spawn | 2P mode | 4P mode | Coordinates |
|---|---|---|---|
| S1 | Player 1 | Player 1 | (32, 246) — floor, left |
| S2 | Player 2 | Player 2 | (344, 88) — on mid step |
| S3 | — | Player 3 | (432, 246) — floor, right |
| S4 | — | Player 4 | (240, 246) — floor, center |

2P opens with intentional asymmetry — S1 (floor-left) vs S2 (mid-step). Height differential creates immediate tension; cyclic rotation ensures both players experience both positions.

#### Encounter Flow
Territorial contest: top step is obvious power position, low step is safer interim, floor is retrieval zone. Top-step occupant gains persistent downward throw advantage but is exposed to wrap-ambushes from the left. Open left airspace rewards air-jump maneuvering and wall-grab climbing. Shurikens thrown downward bury in left wall or floor — both highly retrievable.

#### Sight Lines and Throw Arcs
- **Top step → floor**: delta-y ≈ 222 px. A 45° downward throw (v_x=141, v_y=141 at v=200) reaches floor in ≈ 0.66 s, landing ≈ 93 px horizontally. Tight range — top-step player must lead a moving target.
- **Low step → mid step**: delta-y ≈ 48 px, delta-x ≈ 152 px. Nearly flat over moderate gap — the core engagement.
- Top step is invisible to a player standing below the mid step on the left (mid step blocks the sight line). Teaches prediction, not reaction.

#### Spawn Rotation Compliance
Each slot uses floor (×3 over 10 rounds) and one elevated spawn (×2-3), distributing elevated advantage evenly. No floor shuriken cache (no pickups v1).

---

### Map 03: The Lantern Court

**One-sentence concept**: A symmetric, four-quadrant arena with two slightly offset central shelves and four corner alcoves — the closest thing to a "pure" 4P map in the roster.

**Footprint**: 480 × 270 px

**Theme**: Courtyard of a clan fortress. Stone floor, paper-screen walls as background. Hanging lanterns (non-interactive).

**Recommended player count**: 4 (functional at 2P)

**What This Map Teaches**: Close-quarter dodge timing and stash counting. Compact quadrant geometry keeps players within one-throw range at nearly all times. There is no "safe distance."

#### ASCII Layout Sketch

```
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 0
.S1. . . . # # # . . . . . . . . . . . . # # # . . . .S2. .   row 1   (top spawns + alcoves)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 2
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 3
. . . . . . . . . . . . . # # # . . . . . . . . . . . . . .   row 4   (center-left shelf)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 5
. . . . . . . . . . . . . . . . # # # . . . . . . . . . . .   row 6   (center-right shelf)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 7
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 8
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 9
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 10
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 11
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 12
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 13
.S3. . . . # # # . . . . . . . . . . . . # # # . . . .S4. .   row 14  (bottom spawns + alcoves)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 15
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #   row 16  (floor)
```

**Layout description**: Four corner alcove-ledges (3 tiles each / 48 px), one per spawn, at rows 1 and 14. Near-center, two offset shelves (3 tiles each) at rows 4 and 6, slightly left and right of true center — a "broken staircase" rather than symmetric pillar. No large central platform; center is open air with long floor. Horizontal wrap enabled.

**Why offset shelves, not a central pillar**: a symmetric central pillar produces strong camping geometry. Two offset small shelves create a different dynamic — neither player "owns" center without risk, and one shelf partially conceals the other depending on elevation.

#### Platform Coordinate Table

| # | Description | center_x | center_y | width | height | Tile type |
|---|---|---|---|---|---|---|
| 1 | Top-left alcove | 104 | 24 | 48 | 16 | Solid |
| 2 | Top-right alcove | 376 | 24 | 48 | 16 | Solid |
| 3 | Center-left shelf | 216 | 72 | 48 | 16 | Solid |
| 4 | Center-right shelf | 264 | 104 | 48 | 16 | Solid |
| 5 | Bottom-left alcove | 104 | 232 | 48 | 16 | Solid |
| 6 | Bottom-right alcove | 376 | 232 | 48 | 16 | Solid |
| 7 | Floor | 240 | 262 | 480 | 16 | Solid |

#### Spawn Points

| Spawn | 2P mode | 4P mode | Coordinates |
|---|---|---|---|
| S1 | Player 1 | Player 1 | (32, 16) — top-left |
| S2 | Player 2 | Player 2 | (448, 16) — top-right |
| S3 | — | Player 3 | (32, 246) — floor, bottom-left |
| S4 | — | Player 4 | (448, 246) — floor, bottom-right |

#### Encounter Flow
The chaotic-intensity map. No large platform to dominate; every player within 200 px of center at round-start. Rounds resolve quickly. **Stash counting becomes paramount** — players at 0 shurikens are defenseless and must sprint for floor retrieval. Offset shelves create brief standoffs (one shelf shields you momentarily), but both players know the shield is small. Horizontal wrap makes retreating to a "far" corner futile — the map has no far corner.

#### Sight Lines and Throw Arcs
- **S1 → S4 diagonal**: ~455 px straight-line. 45° downward throw covers diagonal in ≈ 1.6 s — opponent has exactly enough reaction time to dodge if they react immediately. Intentional close-quarter timing.
- **Center shelves → floor**: delta-y ≈ 70 px and 38 px. Nearly vertical — strong for harassing retrieval but hard to arc accurately toward a moving target.
- **Alcoves → floor**: delta-y ≈ 238 px (top alcove). Longest vertical throw line in the roster.

#### Spawn Rotation Compliance
All four spawns equidistant from center (within 30 px of each other in path-length). Top-spawn players start higher (potential first-throw advantage) but are immediately visible. 10-round rotation gives each slot 2-3 rounds at each spawn type.

**2P balance flag (Open Question #5)**: 2P mode (S1 top-left vs S2 top-right) puts both players at same high elevation facing across a 416 px gap — may produce excessive passivity. Consider playtest-driven adjustment to S1 vs S4 for asymmetric 2P opening.

---

### Map 04: The Ridge

**One-sentence concept**: A wide horizontal map with a tall central ridge dividing the arena into two "lanes," rewarding wrap-around strategy and overhead arc throws.

**Footprint**: 480 × 270 px

**Theme**: Mountain ridge at dawn. Silhouetted pine-tree profile as background art. Fog below the ridge line.

**Recommended player count**: 2–4

**What This Map Teaches**: Screen-wrap mastery and overhead arc throws. The central ridge blocks direct sight lines between players in opposing lanes. Crossing requires a visible jump (committed risk) or screen-wrap entry from unexpected vector.

#### ASCII Layout Sketch

```
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 0
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 1
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 2
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 3
. . # # # . . . . . . . . . . . . . . . . . . . . # # # . .   row 4   (wing ledges)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 5
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . .   row 6
. . . . . . . . . . . # # # # # # # # . . . . . . . . . . .   row 7   (ridge top)
. . . . . . . . . . . # . . . . . . # . . . . . . . . . . .   row 8   (ridge body)
. . . . . . . . . . . # . . . . . . # . . . . . . . . . . .   row 9
. . . . . . . . . . . # . . . . . . # . . . . . . . . . . .   row 10
.S1. . . . . . . . . .#. . . . . . .#. . . . . . . . .S2. .   row 11  (mid-height lane spawns)
. . . . . . . . . . . # . . . . . . # . . . . . . . . . . .   row 12
. . . . . . . . . . . # . . . . . . # . . . . . . . . . . .   row 13
.S3. . . . . . . . . .#. . . . . . .#. . . . . . . . .S4. .   row 14  (near-floor lane spawns)
. . . . . . . . . . . # . . . . . . # . . . . . . . . . . .   row 15
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #   row 16  (floor)
```

**Layout description**: Solid central ridge (8 tiles wide / 128 px, 10 tiles tall / 160 px) runs from floor to row 7. Ridge top (row 7) is a standable platform surface. Two wing ledges (3 tiles / 48 px) at row 4 elevation on left and right, reachable with ground jump from spawn. Floor is full-width but split by the ridge into two lanes at floor level (ridge body is solid). Horizontal wrap enabled.

**The ridge serves three functions**: (1) separates spawn zones, preventing round-opening instant-throws; (2) its top is contested high-ground; (3) its body blocks flat throws, forcing arc-throws over the top or wrap-around plays.

#### Platform Coordinate Table

| # | Description | center_x | center_y | width | height | Tile type |
|---|---|---|---|---|---|---|
| 1 | Central ridge | 240 | 192 | 128 | 176 | Solid |
| 2 | Left wing ledge | 48 | 72 | 48 | 16 | Solid |
| 3 | Right wing ledge | 432 | 72 | 48 | 16 | Solid |
| 4 | Floor (left lane) | 88 | 262 | 176 | 16 | Solid |
| 5 | Floor (right lane) | 392 | 262 | 176 | 16 | Solid |

Central ridge is a single StaticBody2D collision rect. Ridge-top surface at y=120 (row 7 bottom edge). Reachable from either lane by one ground-jump from spawn height — delta-y ≈ 64 px, well within single-jump budget.

#### Spawn Points

| Spawn | 2P mode | 4P mode | Coordinates |
|---|---|---|---|
| S1 | Player 1 | Player 1 | (80, 174) — left lane, mid-height |
| S2 | Player 2 | Player 2 | (400, 174) — right lane, mid-height |
| S3 | — | Player 3 | (80, 230) — left lane, near floor |
| S4 | — | Player 4 | (400, 230) — right lane, near floor |

2P: both players start in separate lanes, separated by ridge. Neither has a throw line at round-start — ridge blocks horizontal throws completely. **No round-opening kills from spawn.**

#### Encounter Flow
Most strategically layered map. Opposing-lane players cannot see each other directly. Primary plays: climb ridge top (visible commitment, strong position), use screen-wrap to appear in opponent's lane from behind (map-reading skill), or throw arc over ridge top (arc prediction skill). Wing ledges provide a "sky lane" above the ridge — wing-ledge occupants can throw downward into either lane or arc over the ridge at close range. Shurikens thrown over the ridge land in opponent's lane — retrieval geography favors the defender.

#### Sight Lines and Throw Arcs
- **Ridge-top → either lane floor**: delta-y ≈ 142 px. Strong position but ridge-top occupant is visible to both lanes and both wing ledges.
- **Arc throw over ridge from lane floor** (y=174 → over ridge top at y=120, into opposite lane): requires ≥ 54 px peak above throw point. At v=200, peak ≈ 16.5 px at 45° upward — **insufficient**. **At GDD throw velocity and gravity, arc throws over the ridge from lane floor are difficult.** Players must be elevated (wing ledge or ridge top) to throw over. This makes the ridge a genuine barrier. **Open Question #3.**
- **Screen-wrap throw from right side**: a leftward throw from the right lane wraps and arrives from the right edge of the left lane — anti-intuitive angle that rewards experienced players.

#### Spawn Rotation Compliance
S1, S3 are left-lane spawns; S2, S4 are right-lane spawns. 10-round cyclic rotation gives each slot 2-3 rounds per lane. Neither lane is structurally advantaged (symmetric geometry).

---

## 3. Tile Budget per Map

Based on platform coordinate tables. "Tile instances" = each distinct solid rectangle counted as 1 (TileMap implementation may divide into individual cells).

| Map | Platform shapes | Total tile cells (@ 16 px) |
|---|---|---|
| Broken Bridge | 7 shapes | ≈ 2,800 cells |
| Shrine Steps | 6 shapes | ≈ 1,400 cells |
| Lantern Court | 7 shapes | ≈ 1,200 cells |
| The Ridge | 5 shapes | ≈ 3,100 cells |

All well within Map GDD memory budget (< 50 MB). Tile count is not a risk.

---

## 4. Spawn Rotation Compliance

The Map GDD resolved spawn rotation as cyclic-index (Round Flow Formula 1):

```
spawn_index(slot, round_index, active_slots) =
    (active_slots.find(slot) + (round_index - 1)) mod len(active_slots)
```

**Compliance check per map**:
- All four maps define exactly 4 spawn points (satisfies Map Core Rule 7).
- All spawn points in open space with floor below (verified per description; build-time validator confirms before ship).
- In 2P mode, only `spawn[0]` and `spawn[1]` are used. S1 and S2 are placed far apart on equivalent geometry where possible.
- No spawn is structurally closer to a shuriken cache (no pickups in v1).
- No "lucky spawn" within rotation: cyclic rotation ensures each slot experiences each elevation class across a 10-round match.
- The Shrine Steps 2P pair (floor vs. mid-step) is the only persistent positional asymmetry — intentional, counterbalanced by rotation.

---

## 5. Map Pool Order

Recommended default rotation for a match:

| Order | Map | Rationale |
|---|---|---|
| 1st | **Broken Bridge** | Widest, most open. Teaches throw-arc basics with maximum reaction time. Lowest complexity — first match of the night. |
| 2nd | **Lantern Court** | Symmetric and readable, but close-quarter pressure. Players comfortable with Broken Bridge's spacing will be surprised by the reduced distance. |
| 3rd | **Shrine Steps** | Vertical traversal becomes the main skill. Requires wall-grab comfort and positional reading. Medium complexity. |
| 4th | **The Ridge** | Highest strategic complexity. Wrap mastery and arc-over-obstacle throws. Best experienced after simpler maps warm players up. |

Explicit learning curve: **open → compact → vertical → strategic.**

---

## 6. Open Questions

| # | Question | Owner | Priority |
|---|---|---|---|
| 1 | **Gravity discrepancy**: prototype `player.gd` uses `GRAVITY=1400`; Combat GDD references Projectile gravity `600`. The two cannot coexist. Map specs use GDD value (600) as authoritative for throw arcs. Must reconcile before maps are implemented in production. | game-designer + gameplay-programmer | **BLOCKER before map implementation** |
| 2 | **Shrine Steps asymmetric wrap**: right-wall-as-solid, left-edge-as-wrap. Only map with non-standard wrap. Alternative: full horizontal wrap (both edges). Decision before Shrine Steps tilemap is authored. | game-designer + level-designer | Before alpha |
| 3 | **The Ridge arc-over barrier feasibility**: at v=200, g=600, arc throws over central ridge from lane-floor are insufficient. Options: (a) reduce ridge height by 2-3 tiles, (b) increase throw velocity, (c) add a "gap" in ridge at floor level for shurikens (not players). Needs playtest measurement. | game-designer | Before alpha |
| 4 | **Broken Bridge gap width**: 192 px central gap sized so flat throw at v=200 barely reaches across at same elevation (requires upward arc). Primary tuning lever — narrow if players avoid center entirely; widen if too easy to cross. | level-designer | MVP playtest |
| 5 | **Lantern Court 2P balance**: 2P mode (S1 top-left vs S2 top-right) puts both players at same high elevation across 416 px — may produce excessive passivity. Consider adjusting 2P spawn pair to S1 vs S4 for elevation asymmetry. | level-designer + game-designer | Before vertical slice |

---

## Dependencies

- **Map GDD** (`docs/gdd/map.md`): spawn rotation rules, loading state, validator requirements.
- **Round Flow GDD** (`docs/gdd/round-flow.md`): how rounds consume map data.
- **Combat GDD** (`docs/gdd/combat.md`): throw velocity, projectile gravity (the disputed value).
- **Movement** (`prototypes/movement-and-combat/player.gd`): jump strength, dodge/slide ranges, current gravity value (the disputed value).
- **Art Bible** (`docs/art-bible.md`): tile palette skins per map, decorative props, native resolution.
- **Game Concept** (`docs/gdd/game-concept.md`): no-hazards-no-pickups v1 constraint, scope.
