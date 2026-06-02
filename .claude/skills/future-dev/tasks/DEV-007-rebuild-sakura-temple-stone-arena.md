# DEV-007: Rebuild Sakura Temple as a TowerFall-style stone arena from the new component sheet

**Status:** 🔵 Backlog   **Priority:** P2   **Area:** level / gameplay
**Created:** 2026-05-29

## Idea (raw)
[Image #1 — TowerFall "Sunken City"-style screenshot: a symmetric multi-tier
arena of floating mossy-stone platforms, side towers, narrow corridors, chains,
ladders, a central open chasm, and scattered decorations (banners, chests,
torches).]

pead oleam inspireeritud sellest pildist, sest sellel on kujutatud lahe leveli
layout (platvormid, koridorid jne). Siin on komponendid meie leveli jaoks
ninja_clash/sprites/levels/sakura_temple/components.png. Ehita task leveli
ehitamiseks saranselt nagu towerfallil (arhitektuur ja layout) kasutades neid
komponente, mida andsin

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
Rebuild the **Sakura Temple** map's geometry in `ninja_clash/maps.gd` into a
symmetric, multi-tier, TowerFall-style arena (platforms + corridors + side
towers + a central chasm) using the **new dark-stone component sheet** at
`res://sprites/levels/sakura_temple/components.png`. The reference screenshot
(TowerFall "Sunken City"/"Flight" layout) defines the intended *architecture and
layout*: stacked horizontal platforms forming the main fight lines, narrow
vertical channels/corridors connecting tiers, side wall towers, ladders/chains
bridging tall gaps, and decorations (banners, torches, a chest) dressing the
stone. The goal is a level that *plays* like TowerFall — readable tiers, clear
jump/dodge routes, no dead pockets — not a pixel-copy of the screenshot.

### Context
Levels are pure data in `ninja_clash/maps.gd` — a `MAPS` array of dictionaries,
one per arena. Each map declares `walls`, `platforms`, `ladders`, `deco_sprites`,
`spawn_points`, and theme colors; `main.gd` reads these to build the scene. A
platform/wall entry is `{center, size, sprite, sprite_region, sprite_mode}`:
- `sprite_region` is a `Rect2(x, y, w, h)` cut from the sheet,
- `sprite_mode: "solid"` makes collision == the whole visible region box (solid
  on all sides, nothing falls through) — use this for all gameplay stone,
- `sprite_mode: "fill"` is used for the side walls,
- `deco_sprites` entries are non-colliding scenery placed by `center` + `height`
  + `z` (negative = behind platforms).

The arena is 800 px wide. The **left wall x-range is 0–86 and the right is
714–800**; all gameplay platforms must sit **≥50 px clear** of those ranges so
fighters can wall-slide the full screen-wrap height without snagging.

**Why this task exists:** the file `components.png` was just replaced with a new
**dark dungeon/fortress stone tileset** (modular square blocks, corner/edge
pieces, long beams with dripping/stalactite undersides + one beam with a window
hole, a wooden ladder, hanging chains, vertical spikes, hanging banners/scrolls,
a torch/brazier, a treasure chest, and left/right diagonal slope pieces). The
existing `SK_*` region constants in `maps.gd` (lines ~30–41) were measured
against the **old** sakura sheet (waterfall, pagoda, bamboo, mossy ledges) and
**no longer match** the new art — their coordinates are stale. They must be
re-measured before the level can render correctly.

### Relevant files
- `ninja_clash/maps.gd` — the only file to edit for geometry. Redefine the
  `SK_*` consts (lines ~29–41) against the new sheet and rebuild the entire
  `"Sakura Temple"` map dict (lines ~58–127): `walls`, `platforms`/floating
  entries, `ladders`, `deco_sprites`, `spawn_points`. Use the existing **Neo
  Tokyo** entry (lines ~128–192) as the structural template for a clean 5-tier
  symmetric layout.
- `ninja_clash/sprites/levels/sakura_temple/components.png` — the new sheet to
  measure regions from (1536×~1024 sheet; scan for tight opaque connected
  components).
- `ninja_clash/sprites/levels/sakura_temple/walls.png` — side-wall sheet;
  `SAKURA_WALL_REGION_LEFT/RIGHT` already measured, reuse as-is unless the wall
  art also changed.
- `ninja_clash/main.gd` — read-only reference for how each map field is consumed
  (`sprite_mode`, `sprite_walkable`, `platform_overhang`, `z`, ladders, deco).
- `reference_godot_headless_verify` memory — how to headless-import + screenshot
  for verification.

### Requirements
1. **Re-measure regions** from the new `components.png` via a connected-component
   / opaque-bounds scan. Define a gameplay set (`SK_BLOCK` small square,
   `SK_BLOCK_BIG`, `SK_BEAM` long platform, `SK_LEDGE`/`SK_PAD` medium platforms,
   `SK_SLOPE_L`/`SK_SLOPE_R` diagonal ramps if used, `SK_LADDER`) and a
   decoration set (`SK_CHAIN`, `SK_SPIKES`, `SK_BANNER_*`, `SK_TORCH`,
   `SK_CHEST`). Document each region's aspect ratio in a trailing comment as the
   existing consts do, so placed `size` stays proportional and the art never
   stretches.
2. **Lay out a symmetric multi-tier arena** echoing the reference: a top apex
   platform, mirrored upper ledges/ears, a central main-battle catwalk, mirrored
   mid/outer platforms forming the corridors, mirrored spawn ledges, and a
   bottom landing over a central chasm. Mirror across x=400.
3. **Connect tiers** so every platform is reachable by a normal jump *or* a
   ladder/chain — no isolated perches, no gaps that force a screen-wrap. Place
   ladders (and/or decorative chains aligned to climbable channels) to bridge any
   gap taller than a single jump (~the existing ~225 px spawn→mid gap pattern).
4. All gameplay stone uses `sprite_mode: "solid"`; keep every gameplay platform
   **≥50 px** off the wall x-ranges (0–86, 714–800).
5. Place `deco_sprites` (banners, torches, chest, extra chains) behind the
   platforms (`z` negative) to dress the arena without affecting collision.
6. Set `spawn_points` so the two fighters drop onto the mirrored spawn ledges,
   roughly 8–30 px above the deck (match the existing convention).
7. **Re-theme the metadata to fit the dark stone**: update `sky_top`/`sky_bot`/
   `wall_color`/`wall_edge_color`/`bg_color` toward a stone-dungeon palette. See
   "Assumptions" re: name/ambience.

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`).
- Follow CLAUDE.md: ask before writing files, keep all geometry data-driven in
  `maps.gd` (no hardcoded placement in `main.gd`), match existing conventions in
  `ninja_clash/`.
- Preserve the screen-wrap-safe side walls (collision extends past the viewport;
  full screen height).
- WYSIWYG collision: the visible solid art must equal the hitbox — no
  visible-but-non-solid overhang (the bug the Neo Tokyo `platform_overhang: 1.0`
  comment warns about). Ties to DEV-003 (collision must match visible art).
- Do **not** touch the Neo Tokyo map or shared player/tuning files.

### Assumptions
- **Scope = rebuild Sakura Temple in place** (per user decision), not a new MAPS
  entry. The `"name"`, `"subtitle"`, and `"ambience": "sakura"` fields will no
  longer match the dark-stone art. Default: keep the `sakura` ambience hook and
  map index stable (so menus/round flow don't shift), but update `name`/
  `subtitle` to a stone-fortress theme (e.g. "Sunken Keep" / "drowned stone
  fortress") and adjust the color palette. If the dedicated `sakura_ambience.gd`
  effects (lantern glow, sakura drift) look wrong over stone, note it as a
  follow-up rather than rewriting ambience in this task.
- Exact region pixel coords are unknown until measured — treat the const names
  above as a guide, not a fixed list; add/rename to fit what the sheet actually
  contains.

### Acceptance criteria
- [ ] `SK_*` region constants re-measured against the new `components.png`; each
      has an aspect-ratio comment and placed sizes stay proportional (no stretch).
- [ ] Sakura Temple renders a symmetric, multi-tier TowerFall-style arena
      (apex → upper → central catwalk → mid/corridor → spawn → bottom landing)
      mirrored across x=400.
- [ ] Every platform reachable by jump or ladder/chain; no isolated perches.
- [ ] All gameplay platforms ≥50 px off both wall x-ranges; side walls unchanged
      and screen-wrap-safe.
- [ ] Headless import + parse check is clean (no errors/warnings from `maps.gd`).
- [ ] A gameplay screenshot shows coherent layout, correctly-cut (non-stretched)
      stone pieces, decorations behind platforms, and spawns landing on the
      spawn ledges.
- [ ] Collision matches the visible art on every platform (spot-check edges).

### Out of scope
- New ambience/atmosphere scripting (reuse or lightly retint the existing one).
- Adding spikes as *damaging* hazards — if `SK_SPIKES` is placed, it is
  decoration only unless a hazard system already exists; gameplay hazard logic is
  a separate task.
- Editing Neo Tokyo, player movement/tuning, or the map-select menu.
- Producing new art — work only with the provided `components.png` regions.