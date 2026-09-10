# Launch arenas

The four playable arenas are authored in `maps.gd`. The world is **960 × 540**,
20% wider and taller than the earlier 800 × 450 prototype (44% more area).
A fixed overview camera keeps the complete battlefield visible. UI coordinates
remain 800 × 450, and movement speeds, jump strength, and combat timings stay intact.

## Arena identities

| Arena | Landmark and encounter flow | Primary alternatives |
| --- | --- | --- |
| Verdant Cistern | A broad aqueduct with solid support piers and a contested upper perch. | Two side tunnels, thick lower banks, and a central vertical passage. |
| Sakura Temple | A solid moon-gate roof above an open courtyard. | Climb either outer shrine, flank the gate, or pass below the pillars. |
| Neo Tokyo | Staggered rooftop machinery and asymmetric upper catwalks. | Climb the service-tunnel steps, contest asymmetric catwalks, or flank the central machinery. |
| Sky Temple | Broken cloisters and hanging garden decks around an open aerial centre. | A ring of side landings, offset upper perches, and lower recovery banks. |

Each arena has four dedicated spawn points. Duel modes use the first pair;
free-for-all uses all four. Starts have clear 20 × 32 fighter bounds, a landing
8 pixels below the feet, and at least 200 pixels of separation between any pair.
Positions remain assigned by fighter slot across rounds.

## Traversal and readability

- Primary climbs use the existing 480 px/s jump, 1400 px/s² gravity and
  158.4 px/s horizontal speed. Most ascents are 64–72 pixels.
- Every primary platform connects to every other through ordinary jumps and
  drops. Wall jumps, air dashes, and wrapping provide additional routes.
- Upper decks are offset where necessary to leave room to launch a jump.
  Lower recovery islands have an ordinary route back into combat.
- The visible terrain rectangles match their static collision rectangles.
  Support pillars are solid; the courtyard spaces between them are open.
- Backgrounds use subdued contrast. Bright terrain edges identify walkable tops.
- Both axes wrap at the shared world bounds with an offscreen margin. Overshoot
  is preserved. Thrown shurikens clear their trail history when wrapping;
  charged blade waves expire outside the same world bounds.
- Opposite edge openings align, including the ceiling/floor passages. Wrapping does
  not deposit fighters behind a solid wall.
- Bot targets use exposed landing spans with full headroom, including the narrow
  service steps. Covered sections of a larger floor are excluded.

## Rendering budget

Each arena uses one **960 × 540 panorama**, one **384 × 128 terrain atlas**, and
22–29 static bodies. A single static terrain renderer tiles the shared atlas at
native pixel density. Only exposed faces receive trim, so joined solids have no
false internal borders. Terrain and collisions read the same authored rectangles.
An opaque panorama replaces the fallback background fill, avoiding redundant overdraw.

Atmosphere uses two drawing nodes, updated at 30 Hz, with bounded arrays:

- Neo Tokyo: 24 animated hovercars across six opposing traffic lanes, 96 rain
  streaks in three speed layers, neon lamps, sun bloom, low mist, and occasional lightning.
- Sakura Temple: seven animated birds, 24 petals, warm lantern glows, moon bloom, and mist.
- Verdant Cistern: 24 motes, animated waterfall strands, green lamp glows, and water mist.
- Sky Temple: seven birds, 24 wind motes, pale sanctuary lamps, sun bloom, and drifting mist.

Cars and birds reuse the existing small sprite sheets. All glows share a 64 × 64
radial texture and an additive canvas material. No real-time Light2D nodes, blur
passes, or per-particle nodes are needed. Hidden atmosphere stops advancing; visible
atmosphere uses wall-clock time so combat hit-stop does not freeze the landscape.

The arena-selection preview shows the actual geometry. After editing layouts or art,
rebake the previews with a graphics backend, then import the resulting WebP files.
The bake captures a deterministic atmosphere pose as well as the terrain:

```sh
godot --path ninja_clash --script res://tools/bake_arena_previews.gd
godot --headless --path ninja_clash --editor --import --quit
```

## Performance check

Measured on 2026-09-10 with Godot 4.6.2, Apple M3, Metal/Forward+, and a fixed
1280 × 720 render target. Each sample covers 600 frames after warm-up, with the
arena visible, HUD hidden, and fighter simulation disabled. Both versions used
the same process and rendering setup. The baseline is the original 800 × 450
prototype with its original animated atmosphere; the revised scene includes the
restored effects and expanded arena geometry.

| Arena | Mean frame time, original → revised | Draw calls, original → revised | Process graphics memory, original → revised |
| --- | --- | --- | --- |
| Verdant Cistern | 6.90 → 6.90 ms | 58.0 → 12 | 75.8 → 68.7 MiB |
| Sakura Temple | 6.90 → 6.90 ms | 16.0 → 7 | 85.6 → 68.7 MiB |
| Neo Tokyo | 6.90 → 6.90 ms | 29.0 → 8 | 85.4 → 68.7 MiB |
| Sky Temple | 6.90 → 6.90 ms | 4.0 → 7 | 75.5 → 68.7 MiB |

Wall-clock frame times were display-paced and remained effectively unchanged in
this comparison. Sky Temple now includes atmosphere
that was absent from the original scene, accounting for its additional draw calls.
Older animated-scene counts vary as effects appear. These figures describe arena
rendering on this machine, not GPU timings or a guarantee for every device. Separate
live bot matches and a four-player match were checked visually.

## Validation

```sh
godot --headless --path ninja_clash -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
godot --headless --path ninja_clash --script res://tests/integration/arena_flow.gd
godot --headless --path ninja_clash --script res://tests/integration/menu_flow.gd
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
