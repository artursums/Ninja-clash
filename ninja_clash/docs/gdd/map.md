# Map

> **Status**: Approved
> **Author**: artursums + assistant
> **Last Updated**: 2026-05-17
> **Implements Pillar**: Primary — *Every Shuriken Matters*; Secondary — *Game-Feel First*, *Restraint over Spectacle*

## Overview

The Map system defines the physical playing field of Four Clans: every
single-screen arena where matches take place. It owns the data format that
describes a map's geometry (platforms, walls, ceiling), its player spawn
points, its visual presentation (background art, palette), and its metadata
(name, thumbnail, player-count fit). It also owns the registry of available
maps that MatchSetup queries, and the runtime loading of a chosen map at the
start of each match.

The system has a single non-negotiable contract: **every map guarantees 100%
projectile recoverability.** A shuriken thrown anywhere in a map must always
end up in a location a player can reach — stuck in a wall, resting on a
floor, or returned via screen-wrap. No shuriken can ever become permanently
lost. This is the hard rule that the Map system protects, and it is what
makes the *Every Shuriken Matters* pillar mechanically possible.

## Player Fantasy

A Four Clans map should feel like a stage that's *just barely* small enough
to keep four ninjas in constant tension. The eye should never have to scan —
every platform, every wall, every potential vantage point is visible at all
times. The shape of the geometry should suggest tactics without dictating
them: a player who's been around the map twice should already have favourite
approach routes, favourite retrieval lanes, favourite spots to ambush from.

The maps should *remember* the action. A shuriken stuck high on a wall is a
tactical artifact — someone threw and missed, the throw is paid for, and the
next clean throw could need that one back. A floor littered with three
recoverable shurikens after a round-opening volley creates immediate
decisions: who darts in first, who waits, who flanks. Maps should support
this with deliberate retrieval geography: walls where shurikens visibly
stick, floors that collect them, screen-wrap that punishes lazy throws by
sending the shuriken back to the thrower.

Visually: pixel-art, restrained palettes per clan-themed map, deep
silhouettes. The map should feel inhabited but uncluttered — *Restraint
over Spectacle* applied to environment art. No animated foreground
particles, no parallax that pulls focus from the action layer, no visual
storytelling that competes with the throw arcs.

## Detailed Design

### Core Rules

1. A Map is defined by two paired assets in Godot:
   - **`MapResource` (.tres)**: structured metadata (name, thumbnail, spawn points, screen-wrap flags, recoverability assertion, optional music ref)
   - **`MapScene` (.tscn)**: visual + collision geometry, primarily via Godot's `TileMap` node, with `StaticBody2D` overlays for non-grid geometry as needed
2. The Map system exposes:
   - `MapRegistry.all_maps() -> Array[MapResource]` — discoverable map list
   - `MapLoader.load(map_id: StringName) -> MapScene` — instantiates a map scene
   - A query API for downstream systems (spawn points, wall surfaces, screen-wrap config)
3. **Internal resolution**: maps render at **480×270 internal pixels**, scaled to display via integer factor (×2 → 540 p, ×4 → 1080 p, ×8 → 4K). 16:9 displays fill the screen; 16:10 (Steam Deck 1280×800) letterboxes top/bottom (~27 px native bars).
4. **Single-screen contract**: the entire map is visible at all times. Camera is a fixed `Camera2D` centered at (240, 135). No scrolling, no zoom, no parallax that pulls focus from the action layer.
5. **Platform types**:
   - **Solid** — blocks movement and projectiles from all sides; shurikens stick into solid walls
   - **One-way / drop-through** — blocks player movement from above only; allows down+jump (or down-hold) to drop through; shurikens pass through unimpeded and continue along their trajectory with unchanged velocity (they do NOT stick to drop-through tiles)
6. **Screen-wrap**:
   - Horizontal wrap **enabled by default** on every map (override per-map via `MapResource.horizontal_wrap: bool`)
   - Player exiting the left edge re-enters on the right at the same Y, same velocity
   - Shurikens wrap identically — same axis, conserved velocity
   - Vertical wrap **disabled by default**; configurable per map
7. **Spawn points**: each map defines exactly 4 spawn points (`MapResource.spawn_points: Array[Vector2]`) — one per player slot. Statically authored, not procedural.
8. **Spawn assignment**: at round start, Round Flow assigns spawn points to slots, slot-order by default (slot 1 → spawn[0], …). Spawn rotation per round to prevent positional advantage is TBD in Round Flow GDD.
9. **100% projectile recoverability** — both layers required, both must pass:
   - **Build-time validator** (CI step): simulates shuriken trajectories from each spawn point at multiple angles; asserts every projectile settles in a reachable spot (stuck in solid wall, resting on solid floor, or wrapped back into bounds). Validator failure fails the build.
   - **Designer assertion**: `MapResource.recoverability_validated: bool` must be `true`, asserted after manual playtest verification.
10. **Map metadata**: each `MapResource` exposes `id: StringName`, `display_name: String`, `thumbnail: Texture2D`, `recommended_player_count: Vector2i (min, max)`. UI Flow consumes these.
11. **Hazards**: **none in v1** (per concept anti-pillars). No spikes, lava, moving platforms, destructible terrain.
12. **Pickups**: **none in v1** (per concept anti-pillars). Only geometry + spawn points; no pickup zones, no power-up locations.
13. **Tile size**: TileMap at **16×16 pixel tiles** (30×~17 cell grid). Sub-tile geometry (background decoration, half-tile platforms) allowed via non-aligned sprites + StaticBody2D collision shapes.

### States and Transitions

Map system has minimal state — it's mostly a data store + loader. The relevant
state is the currently loaded map during InMatch.

| State | When | Behavior |
|---|---|---|
| Unloaded | All non-InMatch states | No map scene instantiated; only registry available |
| Loading | Transition MatchSetup → InMatch | `MapLoader.load(selected_map_id)` called by Round Flow's InMatch entry sequence (Round Flow Rule 4.5); instantiates scene synchronously; target completion within 1 frame (16.6 ms at 60 fps) *(updated 2026-05-18 during Round Flow GDD design — credited caller)* |
| Loaded | InMatch and Paused | Map scene live; Movement, Projectile, Round Flow query its API |
| Unloading | Transition MatchEnd → MatchSetup or → MainMenu | Map scene freed |

### Interactions with Other Systems

| Consumer | Interaction | Direction |
|---|---|---|
| **Movement** | Reads platform collision (solid, one-way) for character physics; reads screen-wrap config for player position wrapping | Map → Movement |
| **Projectile** | Reads wall surfaces for stick targets; reads one-way platform info (shurikens skip drop-throughs); reads screen-wrap config for projectile wrap | Map → Projectile |
| **Combat** | No direct dependency. Combat does NOT query Map for shurikens — stash is Combat-tracked, recoverable shuriken positions are Projectile-tracked. Map's geometry affects Combat indirectly via Projectile (stick targets) and CC (collision). *(updated 2026-05-17 during Combat GDD design — original row claiming "Combat queries Map for recoverable shurikens" was incorrect)* | (no direct relationship) |
| **Round Flow** | Reads `MapResource.spawn_points` at round start; reads currently-loaded map ID from `MatchContext` | Map → Round Flow |
| **UI Flow** | Reads `MapRegistry.all_maps()` for map-select UI; reads `MapResource.thumbnail` + `display_name` | Map → UI Flow |
| **GSM** | Map system loads on InMatch entry (via `state_changed` listener); unloads on exit | GSM → Map (indirect) |

## Formulas

Map's math is mostly coordinate wrapping and display scaling.

### Position wrap (horizontal screen-wrap)

For maps with `horizontal_wrap = true`:

```
wrapped_x(x: float, width: float) :=
    fmod(fmod(x, width) + width, width)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `x` | float | (-∞, +∞) | entity position (player or projectile) | Pre-wrap world X coordinate |
| `width` | float | typically 480.0 | playfield width (constant 480 for v1) | Internal pixels |
| `wrapped_x` | float | [0, width) | calculated | Post-wrap position; entity is teleported here |

The double-`fmod`-plus-`width` idiom handles negative `x` correctly (GDScript's
`%` operator on floats does not naturally wrap negatives to a positive range).

Vertical wrap (if `vertical_wrap = true`) is analogous on Y with `height = 270`.

### Display scaling (internal → display pixels)

Computed once on application start and on any window-resolution change.

```
scale = floor(min(display_w / INTERNAL_WIDTH, display_h / INTERNAL_HEIGHT))
letterbox_w = (display_w - INTERNAL_WIDTH * scale) / 2
letterbox_h = (display_h - INTERNAL_HEIGHT * scale) / 2
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| `display_w, display_h` | int | ≥ 480, ≥ 270 | OS window | Current window dimensions, physical px |
| `INTERNAL_WIDTH, INTERNAL_HEIGHT` | int | 480, 270 | constants | Internal pixel-art resolution |
| `scale` | int | 1, 2, 3, …, 8 | calculated | Integer scaling factor (pixel-perfect) |
| `letterbox_w, letterbox_h` | int | ≥ 0 | calculated | Black bar widths (px on display) |

**Example resolutions:**

| Display | scale | render area | letterbox |
|---|---|---|---|
| 540 p (960×540) | 2 | 960×540 | 0 |
| 1080 p (1920×1080) | 4 | 1920×1080 | 0 |
| 4K (3840×2160) | 8 | 3840×2160 | 0 |
| Steam Deck (1280×800) | 2 | 960×540 | 160 L/R + 130 T/B |

Steam Deck's significant letterboxing is a known v1 limitation; fractional-scale
or playfield-widen options are deferred to v1.x (see Open Questions).

### Tile-to-world coordinate

```
world_pos = tile_coord * TILE_SIZE      # tile_coord in cells, world_pos in px
```

Trivial but documenting for clarity: `TILE_SIZE = 16` (constant).

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Map file missing or corrupted at load time | `MapLoader.load` raises an error; UI Flow falls back to MainMenu with a non-blocking error toast ("Map could not be loaded") | Don't crash; give the player a way back |
| `MapResource` has fewer than 4 spawn points | Build-time validator fails; map cannot ship | 4 slots are guaranteed; missing spawn is a config error |
| `MapResource.recoverability_validated == false` | Build-time validator fails; map cannot ship | Per Core Rule 9 |
| Map is empty (no collision geometry at all) | Build-time validator catches this (validator would report 100% of projectiles as unreachable) | Defense via validation |
| Two `MapResource` files share the same `id` | Build-time validator fails | Each map must be uniquely addressable |
| Custom `playfield_width != 480` (not used in v1; reserved for v1.x) | Wrap formula honors the configured width; other systems must query `MapResource.playfield_width` rather than assuming 480 | Forward-compatibility — v1 hard-locks to 480 per Tuning Knobs, but the formula is robust for v1.x relaxation |
| Shuriken velocity > playfield width per frame (very high velocity wraps multiple times) | The wrap formula's modulo handles arbitrary velocity in one calculation — wrapped position is always correct regardless of speed | Math is robust |
| Vertical wrap enabled + gravity (player falls forever) | Per Core Rule 6, vertical wrap is disabled by default. If a map enables it, the map's design must include landing surfaces that prevent perpetual falling | Designer responsibility; flag in Open Questions |
| Spawn point placed inside a wall by the level designer | Build-time validator fails (each spawn point must be in open space with a floor below within N tiles) | Validator owns this check |
| Map registry is empty at game start | UI Flow's MatchSetup map-select shows a non-blocking error ("No maps installed"); game cannot start a match | Edge case for broken builds / mod situations |
| Player's screen-wrap moves them onto another player's exact pixel | Allowed; collision rules in Movement handle inter-player overlap (no special wrap-collision case) | Wrap is positional only; physics handles the rest |

## Dependencies

Map is a Foundation system with **zero upstream dependencies**. Six downstream
consumers (one indirect).

| System | Direction | Nature of Dependency |
|---|---|---|
| — | This depends on nothing | Foundation system; no internal deps |
| **Character Controller** | Character Controller depends on Map | Collision geometry (solid vs. one-way); screen-wrap rules (entity position wrapping) |
| **Movement** | Movement depends on Map (indirect via Character Controller) | Drop-through input semantics, wall-jump validation, screen-wrap — all consumed through Character Controller's abstraction |
| **Projectile** | Projectile depends on Map | Collision for stick targets; one-way platforms (shurikens skip drop-throughs); screen-wrap config |
| **Combat** | Combat depends on Map | Queries map for currently-recoverable shurikens (HUD shuriken-count display) |
| **Round Flow** | Round Flow depends on Map | Reads `MapResource.spawn_points` at round start; triggers `MapLoader.load` on InMatch entry |
| **UI Flow** | UI Flow depends on Map | Reads `MapRegistry.all_maps()` for map-select UI; reads thumbnail + display_name |

**External dependencies:**
- Godot 4.6 `TileMap` node (geometry painting + collision in editor)
- Godot 4.6 `Resource` system (.tres for `MapResource`)
- Godot 4.6 `Camera2D` (single fixed camera at (240, 135))
- Godot 4.6 `StaticBody2D` (overlay collision for non-grid geometry)
- Build pipeline: CLI tool for the recoverability validator (likely a Godot editor plugin or standalone GDScript runner) — TBD during implementation

**Bidirectional consistency** (resolved 2026-05-17):

- `docs/gdd/systems-index.md` updated: Character Controller row + Dependency Map Foundation Layer entry now list Map as a dependency.
- Movement's index row stays as-is (Character Controller + Couch Input) — Movement consumes Map *through* Character Controller, not directly.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `INTERNAL_WIDTH` | 480 | (hard-locked in v1) | Wider playfield; breaks fixed-camera assumptions in other systems | — |
| `INTERNAL_HEIGHT` | 270 | (hard-locked in v1) | Taller playfield; breaks fixed-camera assumptions | — |
| `TILE_SIZE` | 16 | (hard-locked in v1) | Larger tiles, fewer cells per map, coarser geometry | Smaller tiles, more authoring detail, slower performance with more tile lookups |
| `MapResource.playfield_width` (per map) | 480 | 480 | (locked to `INTERNAL_WIDTH` for v1) | (locked) |
| `MapResource.horizontal_wrap` (per map) | `true` | `true` / `false` | (boolean) `false` means screen edges are walls — changes throw geometry significantly per map | (boolean) `true` is the default TowerFall-style wrap |
| `MapResource.vertical_wrap` (per map) | `false` | `true` / `false` | (boolean) `true` enables vertical wrap; requires designer to avoid perpetual-fall traps | (default — safer) |
| `MapResource.recoverability_validated` (per map) | (designer-asserted) | `true` only | Map ships once asserted | Map cannot ship |
| `MapResource.recommended_player_count` (per map) | varies per map | `(2, 4)` typical | (vector2i, designer hint) UI Flow uses for "recommended for X players" badge | — |
| `VALIDATOR_SAMPLE_ANGLES` | 16 | 8 – 32 | Slower validation; catches more edge-case throw trajectories | Faster validation; risk of missing rare unreachable trajectories |
| `VALIDATOR_MAX_SIM_FRAMES` | 600 (10 s @ 60 fps) | 300 – 1200 | More patient validator (allows long-bouncing trajectories to settle) | Faster validation; risk of false-positives on slow-settling projectiles |

**Not knobs**: tile-by-tile collision shapes, spawn point positions, background art —
these are per-map authored data, not designer-tunable parameters.

## Acceptance Criteria

### Functional

- [ ] All v1 maps (4–6) load successfully via `MapLoader.load`
- [ ] Each loaded map renders at 480×270 internal resolution with fixed `Camera2D` at (240, 135)
- [ ] Solid tiles block player and projectile movement on all sides
- [ ] One-way / drop-through tiles allow up-pass for players; allow down+jump drop-through
- [ ] Shurikens pass through one-way tiles (do not stick)
- [ ] Horizontal screen-wrap: player exiting left edge re-enters on right at same Y, same velocity
- [ ] Shuriken exiting left edge re-enters on right with conserved velocity
- [ ] Vertical wrap disabled by default; opt-in maps wrap vertically as designed
- [ ] All 4 spawn points per map are in open space (no wall-embedded spawns)

### Recoverability (the load-bearing rule)

- [ ] Build-time validator runs as part of CI; build fails if any map fails
- [ ] Validator simulates `VALIDATOR_SAMPLE_ANGLES` throws from each spawn point; all settle in reachable spots
- [ ] Validator terminates each simulation within `VALIDATOR_MAX_SIM_FRAMES`
- [ ] Designer assertion (`recoverability_validated == true`) is required to ship; build fails without it
- [ ] Manual playtest: shurikens thrown from each spawn point at extreme angles are all retrievable within 10 s of map traversal

### Map registry

- [ ] `MapRegistry.all_maps()` returns ≥ 1 map (game cannot run with 0)
- [ ] All map IDs are unique across the registry
- [ ] Each `MapResource` has all required fields populated (id, display_name, thumbnail, spawn_points, recoverability_validated, recommended_player_count)

### Display scaling

- [ ] 1080 p display renders at scale=4 with no letterboxing
- [ ] 540 p display renders at scale=2 with no letterboxing
- [ ] 4K display renders at scale=8 with no letterboxing
- [ ] Steam Deck (1280×800) renders at scale=2 with 160 px L/R + 130 px T/B letterbox
- [ ] Mid-game window-resize re-computes scale + letterbox correctly
- [ ] Scaling is pixel-perfect (integer scale only — no fractional)

### Performance

- [ ] Map load (instantiate scene) completes within ≤16.6 ms (1 frame at 60 fps)
- [ ] Map collision queries complete within ≤0.5 ms per frame for typical player/projectile counts
- [ ] Loaded map memory footprint < 50 MB

### Code hygiene

- [ ] `MapResource` serialization is forward-compatible (adding fields doesn't break older saved data — relevant for future v1.x features)
- [ ] All tile types use named constants (no magic numbers for solid/one-way)
- [ ] Spawn points stored as `Vector2` (pixel coords), not `Vector2i` (tile coords) — allows sub-tile precision

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Steam Deck letterboxing: 160 px L/R + 130 px T/B bars are significant. Options for v1.x: fractional scaling (loses pixel-perfect), playfield-widen for 16:10 displays (adds per-map data complexity), or accept the bars as visual identity ("retro CRT" framing). | technical-artist + ux-designer | v1.x | Accept letterboxing for v1; revisit if QA / playtest feedback complains |
| Spawn rotation per round: should slot 1 always spawn at `spawn[0]`, or should spawns rotate per round to prevent positional advantage? | Round Flow GDD author | Before Round Flow GDD approved | **Resolved 2026-05-18**: cyclic-index rotation per Round Flow Formula 1. `spawn_index(slot, round_index, active_slots) = (active_slots.find(slot) + round_index - 1) mod len(active_slots)`. Deterministic, no RNG. Honors Pillar 2 (Fairness Is Sacred). |
| Recoverability validator implementation: Godot editor plugin (live preview in editor) vs. standalone CLI tool (CI integration only) vs. both? | gameplay-programmer + tools-programmer | Before alpha (first 4 maps shipping) | TBD — likely CLI for CI + lightweight editor warning for designers |
| Final v1 map count: concept says 4–6; alpha targets 4, v1 launch adds 1–2. Decision deferred until alpha playtest reveals which maps "carry" the experience. | game-designer + level-designer | Alpha milestone | Defer to alpha |
| Per-map music vs shared playlist: concept doc says 3–5 music tracks. Should each map have a designated track, or pool/random? | audio-director | Alpha audio pass | TBD |
| Background art parallax: zero-parallax-distraction is in Player Fantasy. But subtle static background art per map is fine. Where's the line? | art-director | Pre-alpha art bible | Defer to art bible |
| TowerFall map parity: directly mimic specific TowerFall map layouts (e.g., Twilight, Sunken City) as starting templates, or design from scratch? | level-designer + game-designer | First map prototype | TBD — likely mimic 1–2 for prototype, originals for shipped maps |
| Map authoring tooling beyond Godot's TileMap editor: do level designers need any custom tooling (spawn-point gizmo, recoverability heat map)? | tools-programmer | Before alpha | TBD |
