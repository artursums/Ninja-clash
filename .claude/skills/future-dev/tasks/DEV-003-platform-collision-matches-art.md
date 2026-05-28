# DEV-003: Platform/wall collision must match the full visible art (no untouchable edges)

**Status:** 🔵 Backlog   **Priority:** P2   **Area:** level / gameplay
**Created:** 2026-05-28

## Idea (raw)
> nüüd järgmine task, kus töötame platvormite nimel. Nimelt paltvorm on mõnedes
> kohtades läbipaistev mõlemas levelis. On tarvis see läbipaistvus fixida sellsielt, et
> kogu platvormi fail (pilt), mis on kasutuses levelis peab olema igalt poolt
> touchable. Ta pole ideaalselt sümmeetriline, seega on kohti, mis on jäetud
> läbipaistvaks. Seda on vaja parandada. Peab oleam igalt oma äärelt touchable

(Translation for context: "Next task, working on platforms. The platform is transparent
[= not solid / passes through] in some places in BOTH levels. We need to fix that
transparency so the ENTIRE platform file (image) used in the level is touchable from
every side. The art isn't perfectly symmetrical, so there are spots left transparent.
This must be fixed. It must be touchable from each of its edges.")

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
In the production game (`ninja_clash/`), the collision of platforms and side walls does
not match their visible artwork, so parts of a platform/wall that *look* solid are
actually pass-through — a fighter walks/falls through the visible edge of a platform.
Fix it so the collision covers the **full visible (opaque) footprint of each
platform/wall image in both levels (Sakura Temple and Neo Tokyo)** — every edge of the
visible art must be touchable (standable / blocking), with no solid-looking but
pass-through regions.

### Context
Levels are data-defined in `ninja_clash/maps.gd`: each map has a `walls` array whose
entries are BOTH the side walls and the floating platforms (one shape type). Each entry
is `{center, size, sprite, sprite_region?, sprite_mode?, sprite_walkable?}`.

The arena is built in `ninja_clash/main.gd`:
- `_build_arena()` (≈ line 191) iterates `data.walls` and calls `_make_wall(...)`.
- `_make_wall()` (≈ line 801) creates a `StaticBody2D` whose collision is a single
  `RectangleShape2D` of **exactly `size`** (line 805-807). Then it adds a separate
  `Sprite2D` whose scale does NOT match that rect:
  - **`sprite_mode == "fill"`** (the side walls): the sprite region is uniform-scaled so
    its visual *height* = 450 px (full screen) and centered (line 824-829). The collision
    rect is `size` (e.g. `Vector2(86, 550)`). The opaque pixels inside the source region
    are not perfectly aligned to that 86-px rect, so the visible wall surface is
    inset/offset from where the collision actually is.
  - **`sprite_mode == "platform"`** (default, all floating platforms): the sprite is
    scaled so its visual *width* = `size.x * PLATFORM_VISUAL_OVERHANG`, where
    `PLATFORM_VISUAL_OVERHANG = 1.4` (`main.gd:17`). So the platform art is rendered
    **40% wider than its collision rect** (≈20% overhang each side), and the deck row is
    aligned to the rect top via `sprite_walkable` (`main.gd:16`, `PLATFORM_SRC_Y_WALKABLE
    = 395`). The overhanging visible ends look like solid platform but have no collision.

So the root cause is a **collision-vs-art mismatch**: collision is a fixed `size`
rectangle while the sprite overhangs it (platforms) or is uniform-scaled from an
asymmetric opaque region (walls). Combined with transparent/asymmetric margins in the
source art, the visible edges of platforms/walls are not collidable. Platforms are fully
solid rectangles today (plain `RectangleShape2D`, no one-way collision) — this task is
about the *extent/shape* of that solid, not its one-way behavior.

Relevant art (per-level, flat in each folder):
- `ninja_clash/sprites/platform.png` — generic platform art used by Sakura Temple
  (`maps.gd` const `P`).
- `ninja_clash/sprites/levels/neo_tokyo/level-components.png` — Neo Tokyo platforms use
  measured regions `NT_BEAM`, `NT_PAD` (`maps.gd:31-36`) with per-platform
  `sprite_walkable` deck rows.
- `ninja_clash/sprites/levels/<slug>/walls.png` — side-wall sheets; regions
  `SAKURA_WALL_REGION_*` / `NEO_TOKYO_WALL_REGION_*` (`maps.gd:20-27`).

### Relevant files
- `ninja_clash/main.gd` — `_make_wall()` (≈ 801, the fix site: collision shape creation
  + sprite scaling/positioning), `_build_arena()` (≈ 191), and the constants
  `PLATFORM_SRC_Y_WALKABLE` / `PLATFORM_VISUAL_OVERHANG` (≈ 16-17).
- `ninja_clash/maps.gd` — the `walls`/platform definitions, `sprite_region`s,
  `sprite_walkable` deck rows, and the wall region rects for both levels.
- `ninja_clash/sprites/platform.png`, `.../levels/neo_tokyo/level-components.png`,
  `.../levels/<slug>/walls.png` — the source art whose opaque footprint defines what
  "touchable from every edge" means. Inspect actual opaque pixel bounds per region.
- `ninja_clash/player.gd` — the fighter is a `CharacterBody2D`; verify
  walk/land/wall-grab against the corrected collision (no behavior change expected, just
  that the surfaces are now where the art is).

### Requirements
1. Make each platform's and each side wall's collision cover the **full opaque footprint
   of its rendered sprite**, so a fighter can stand on / be blocked by every visible edge
   of the art — no visible-but-pass-through regions, in BOTH Sakura Temple and Neo Tokyo.
2. Reconcile the sprite/collision sizing in `_make_wall()`. Decide and implement one
   coherent approach (recommendation below) so collision and visible opaque art share the
   same bounds; eliminate the silent `PLATFORM_VISUAL_OVERHANG` mismatch (either drop the
   overhang so the art equals the collision, or extend collision to the rendered art —
   whichever keeps the intended platform look).
3. Handle the source-art asymmetry: the opaque content is not centered/symmetric in some
   regions, so a centered rect of `size` is wrong. Collision must follow the actual
   opaque pixels (bounding box at minimum; a polygon if a region's solid area is concave).
4. Preserve gameplay layout intent: platform centers, the deck (top walkable surface)
   heights, spawn clearances, and the "≥50 px off the side walls" spacing in `maps.gd`
   must still hold after the fix. The walkable deck top for Neo Tokyo platforms
   (`sprite_walkable`) must still align to the top of the solid.
5. Keep it data-driven and per-level correct — do not hardcode magic offsets per
   platform; derive from the art/region where possible so adding a level later stays easy.

### Suggested approach (recommended, but use judgment)
- **Derive collision from the sprite's opaque alpha.** Load the source image, take the
  `sprite_region` sub-rect, and compute its opaque bounds. Godot 4.6 supports
  `BitMap.create_from_image_alpha(image)` + `BitMap.opaque_to_polygons(rect, epsilon)` to
  get polygon(s) matching the opaque pixels — convert to local space using the SAME scale
  the `Sprite2D` uses, and build `CollisionPolygon2D`(s) instead of (or in addition to) the
  rect. This makes collision exactly match the visible art "from every edge."
  - If the per-platform shapes are simple, an **opaque bounding-box rectangle** (scaled to
    match the sprite) is simpler and may be sufficient — choose per shape.
  - Cache/precompute per unique (sprite, region) so you are not scanning images for every
    duplicated platform every match (watch the frame budget; do it at build time).
- Alternatively, if the art is the real problem (stray transparent margins that should be
  solid), trimming/repainting the source platform art to a tight opaque footprint and then
  using a matching rect is also acceptable — but prefer the code-derived approach so future
  art "just works."

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`); training data
  predates 4.4–4.6 — cross-check `BitMap`/`Image`/collision APIs there before using them.
- Follow CLAUDE.md: ask before writing files, keep values data-driven (no per-platform
  hardcoded collision offsets — derive them), match existing conventions in `ninja_clash/`.
- Don't change the platforms' solid (two-sided) behavior into one-way, and don't move
  platform centers/heights — only correct the collision *extent* to match the art.
- This is a visual+collision change: VERIFY by running the game and viewing collision
  shapes (Godot "Visible Collision Shapes" debug), comparing the collision outline to the
  rendered art on every platform/wall in both levels. Per coding-standards.md, prove it
  with screenshots; also run the headless import/parse check
  (see `reference_godot_headless_verify`).

### Assumptions
- "Platform is transparent in some places" = the collision does not cover the full visible
  opaque art, so solid-looking edges are pass-through (not a render/alpha problem in the
  art itself, though trimming art is an acceptable alternate fix).
- "Touchable from every edge" = a fighter can land on the top and be blocked at the left,
  right, and bottom faces wherever the art shows solid material, matching the visible
  silhouette.
- Both levels (Sakura Temple, Neo Tokyo) are in scope; the generic `platform.png` (Sakura)
  and the Neo Tokyo `NT_BEAM`/`NT_PAD` regions all need correcting.

### Acceptance criteria
- [ ] With "Visible Collision Shapes" on, every platform's and side wall's collision
      outline matches its visible opaque art (no overhang of art beyond collision, no
      collision beyond art) in BOTH levels.
- [ ] A fighter can stand on and be blocked at the full visible extent of each platform —
      walking onto a platform's visible edge no longer drops through; the previously
      pass-through overhang ends are now solid (or the art no longer shows non-solid ends).
- [ ] Side-wall surfaces (wall-grab / wall-jump contact) line up with the visible wall art
      — no gap where the player floats off the visible surface or clips into invisible
      collision.
- [ ] Platform centers, deck-top heights, spawn clearances, and ≥50 px wall spacing from
      `maps.gd` are unchanged; Neo Tokyo deck tops (`sprite_walkable`) still align.
- [ ] No per-platform hardcoded magic offsets added; collision derives from art/region.
- [ ] Project imports/parses headless clean; build-time image scanning (if used) does not
      regress match-load time / frame budget.

### Out of scope
- Adding new platforms or changing the level layouts/geometry.
- Converting platforms to one-way (drop-through) collision.
- Reworking the art style of platforms/walls beyond trimming transparent margins if that
  route is chosen.
- The pre-match variants menu (DEV-001) and the AI rework (DEV-002).
