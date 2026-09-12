# Launch arenas

The four playable arenas are authored in `maps.gd`. The world is **880 × 495**,
10% wider and taller than the earlier 800 × 450 prototype (21% more area).
A fixed overview camera keeps the complete battlefield visible. UI coordinates
remain 800 × 450, and movement speeds, jump strength, and combat timings stay intact.

## Arena identities

| Arena | Landmark and encounter flow | Primary alternatives |
| --- | --- | --- |
| Verdant Cistern | A broad aqueduct with solid support piers and a contested upper perch. | Two side tunnels, thick lower banks, and a central vertical passage. |
| Sakura Temple | A solid moon-gate roof above an open courtyard. | Climb either outer shrine, flank the gate, or cross the unobstructed lower courtyard. |
| Neo Tokyo | Staggered rooftop machinery and asymmetric upper catwalks. | Climb the service-tunnel steps, contest asymmetric catwalks, or flank the central machinery. |
| Sky Temple | Broken cloisters and hanging garden decks around an open aerial centre. | A ring of side landings, offset upper perches, and lower recovery banks. |

Each arena has four dedicated spawn points. Duel modes use the first pair;
free-for-all uses all four. Starts have clear 20 × 32 fighter bounds, a landing
up to 12 pixels below the feet, and at least 200 pixels of separation between any pair.
Positions remain assigned by fighter slot across rounds.

## Traversal and readability

- Primary climbs use the existing 480 px/s jump, 1400 px/s² gravity and
  158.4 px/s horizontal speed. Most ascents are 58–72 pixels.
- Every primary platform connects to every other through ordinary jumps and
  drops. Wall jumps, air dashes, and wrapping provide additional routes.
- Open side passages are at least 40 pixels wide; tunnels have at least 44 pixels of height.
  This leaves 20 pixels beside or 12 pixels above the 20 × 32 fighter.
- Upper decks are offset where necessary to leave room to launch a jump.
  Lower recovery islands have an ordinary route back into combat.
- The visible terrain rectangles match their static collision rectangles.
  Decorative fixtures have no collision. Low ceilings and unnecessary hanging supports have been removed from the central routes.
- Backgrounds use subdued contrast. Bright terrain edges identify walkable tops.
- Both axes wrap when the fighter centre crosses the actual 880 × 495 world bounds. Overshoot
  is preserved. Border bodies carry translated collision shapes beyond each seam,
  so a straddling fighter retains support and cannot clip the opposite corner. Thrown shurikens clear their trail history when wrapping;
  charged blade waves expire outside the same world bounds.
- Opposite edge openings align, including the ceiling/floor passages. Wrapping does
  not deposit fighters behind a solid wall.
- Bot targets use exposed landing spans with full headroom, including the narrow
  service steps. Covered sections of a larger floor are excluded.

## Rendering budget

Each arena uses one **960 × 540 panorama** and its original **384 × 128 masonry
atlas** at native pixel density. The four materials retain their authored detail:
moss and carved stone, petal-strewn temple bricks, industrial panels and vents,
and pale sanctuary masonry with gold inlays. The approved geometry is unchanged.
A single static renderer tiles the interiors and samples textured caps, side faces,
and undersides only along exposed contours. Opposite screen edges share their contour.
Terrain and collision read the same rectangles; art is cropped, never stretched.
There are at most 32 permanent bodies and one or two optional crumbling bodies per map.
An opaque panorama replaces the fallback background fill, avoiding redundant overdraw.

Atmosphere uses two drawing nodes, updated at 30 Hz, with bounded arrays:

- Neo Tokyo: 24 animated hovercars across six opposing traffic lanes, 96 rain
  streaks in three speed layers, neon lamps, sun bloom, low mist, and occasional lightning.
- Sakura Temple: seven animated birds, 24 petals, warm torch flames, rising embers, swinging banners, moon bloom, drifting clouds, and mist.
- Verdant Cistern: 24 motes, animated waterfall strands, warm torch flames, rising embers, swinging banners, and water mist.
- Sky Temple: seven birds, 24 wind motes, warm sanctuary braziers and swinging banners, sun bloom, drifting clouds, and mist.

Cars and birds reuse the existing small sprite sheets. All glows share a 64 × 64
radial texture and an additive canvas material. No real-time Light2D nodes, blur
passes, or per-particle nodes are needed. Hidden atmosphere stops advancing; visible
atmosphere uses wall-clock time so combat hit-stop does not freeze the landscape.
Lamp bases are authored alongside arena geometry in world coordinates. Their visual
positions are converted into the atmosphere layer's scale once when loading the map.
Tests verify platform support, fixture clearance, and alignment after scaling.

The arena-selection preview shows the actual geometry. After editing layouts or art,
rebake the previews with a graphics backend, then import the resulting WebP files.
The bake captures a deterministic atmosphere pose as well as the terrain:

```sh
godot --path ninja_clash --script res://tools/bake_arena_previews.gd
godot --headless --path ninja_clash --editor --import --quit
```

## Crumbling shortcuts

Each arena has one or two visibly cracked optional slabs. Landing starts a **0.65 s**
warning; the top collision remains stable while the stones shake and the crack brightens.
Hairline cracks progressively spread through the original textured slab, followed
by lower-stone vibration and falling grit. The slab then loses collision for **4 s**.
Its original texture is partitioned into 10–16 differently sized fragments with
staggered release, outward velocity, gravity, and stepped rotation. Opaque chips and
short-lived pixel dust complete the burst; stone pieces never dissolve by alpha fading.
Debris draws behind permanent terrain, so lower walls naturally occlude falling pieces.
There are no fragment physics bodies or per-frame node allocations. The same seeded
fracture and host timer produce matching effects on clients. Small corner brackets
signal the absent surface shortly before its return. Restoration waits if a fighter overlaps the slab;
all slabs reset at the next round. Spawn floors and wrap entrances are permanent.
Spent shurikens fall harmlessly when their support disappears.

The host owns the timers and sends their state with the existing 30 Hz world snapshots.
Clients only apply the host state; snapshots for another map are ignored. CPU line-of-sight
checks include intact slabs. The permanent jump graph remains connected after every slab
has broken, and real CPU traversal is tested with dynamic terrain enabled.

## Performance check

Measured on 2026-09-12 with Godot 4.6.2, Apple M3, Metal/Forward+, in a fixed
1280 × 720 SubViewport. Each sample covers 180 frames after 30 warm-up frames;
fighters and HUD are hidden. These are display-paced wall-clock frame times,
not GPU timings. Process-wide rendering monitors include the application window.

| Arena | Mean frame | 95th percentile | Draw calls |
| --- | --- | --- | --- |
| Verdant Cistern | 6.94 ms | 8.63 ms | 27 |
| Sakura Temple | 6.94 ms | 7.99 ms | 23 |
| Neo Tokyo | 6.94 ms | 8.26 ms | 13 |
| Sky Temple | 6.94 ms | 8.48 ms | 23 |

The terrain drawing commands are built once per map. Weather and flames update at
30 Hz; there are no per-particle physics bodies or real-time shadow lights. Chain
links and cloth markings use batched rectangles. The profile tool writes its raw
measurements to `/tmp/arena-render-profile.json`:

```sh
godot --path ninja_clash --script res://tools/profile_arenas.gd
```

## Validation

```sh
godot --headless --path ninja_clash -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
godot --headless --path ninja_clash --script res://tests/integration/arena_flow.gd
godot --headless --path ninja_clash --script res://tests/integration/menu_flow.gd
godot --headless --path ninja_clash --script res://tests/integration/arena_dynamics.gd
godot --headless --path ninja_clash --script res://tests/integration/bot_flow.gd
godot --path ninja_clash --script res://tests/integration/bot_playtest.gd
```

Unit tests check spawn clearance, support and separation; distinct geometry;
non-overlapping solids; atlas budgets; bot landing clearance; and matching wrap portals. Arena integration checks
four-player spawning, visual/collision agreement, retained atmosphere and traffic,
both projectile types, and a graph
of jump/drop trajectories tested against Godot's actual collision bodies. The probe
uses the production tuning values and tests both directions with several air-control
reversal timings. This verifies basic connectivity, not competitive balance or bot skill.
Menu integration checks safe intro skipping, completion during slowed game time,
return navigation, confirm placement, local locks, and online selection permissions.
Dynamic integration moves real fighters through horizontal floors at running and dash speed,
checks vertical portal clearance, landing-triggered collapse, safe restoration, falling pickups,
and host/client terrain snapshots. Fragment checks cover atlas bounds, complete slab
coverage, bounded counts, outward travel and subsequent gravity. A deterministic visual
preview can be captured with `tools/preview_crumble.gd` (180 PNG frames in `/tmp/crumble-frames`).
Human playtesting remains the way to assess camping, chase duration, and spawn advantage.

## Design references

These layouts apply the references' principles to this game's movement and weapons;
they do not reproduce an existing TowerFall arena.

- [TowerFall towers and their individual arena layouts](http://towerfall.wikidot.com/towers)
- [Custom-level showcase: connected masonry, chambers, and alternate routes](https://www.youtube.com/watch?v=3I1UQLbkyWc)
- [Creator interview: TowerFall's readable play and expressive depth](https://www.gamedeveloper.com/design/road-to-the-igf-matt-thorson-s-i-towerfall-ascension-i-)
- [Creator interview: depth, simplicity, and layered movement](https://www.gamedeveloper.com/design/the-magic-of-i-towerfall-i-depth-simplicity-community)
- [Celeste and TowerFall physics: simple actors and solids](https://www.mattmakesgames.com/articles/celeste_and_towerfall_physics/index.html)
- [Godot GPU optimization: batching, texture reuse, and overdraw](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)

Drawing API: [Godot CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html), verified 2026-09-12.
