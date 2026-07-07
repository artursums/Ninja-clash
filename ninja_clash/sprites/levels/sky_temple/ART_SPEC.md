# Sky Temple — Art Spec & Higgsfield Prompts

Open, TowerFall-style arena. Native game resolution stays **800×450** (single screen —
same character-to-space ratio as TowerFall, ~7%). "Bigger" here means a more **open,
full-frame layout**, not a larger viewport. This spec only affects the Sky Temple level.

The level layout already lives in `maps.gd` (entry `"name": "Sky Temple"`) and is playable
right now with color-fill placeholders. These two images drop in on top of that — sizes
already match the collision boxes (WYSIWYG, `platform_overhang = 1.0`).

Place the generated files exactly here:
- `res://sprites/levels/sky_temple/background.png`
- `res://sprites/levels/sky_temple/components.png`

⚠️ Do NOT copy TowerFall's actual assets. Generate **original** art in the same genre
(open moss-stone sky-temple). This is for a shippable game.

---

## 1) background.png — exactly 800 × 450 px

Full-frame atmospheric backdrop. Atmosphere ONLY — no floating ledges that look walkable
(every walkable surface comes from `components.png`, so players never try to land on the
background).

**Higgsfield `generate_image` prompt:**

> Pixel-art background for a single-screen 2D archer-arena fighting game, canvas exactly
> 800x450, 16:9, retro 16-bit style. Ancient moss-covered stone sky-temple, teal-and-green
> palette with a bright open blue sky. Composition: a LARGE OPEN sky filling the upper
> two-thirds with soft pixel clouds and distant misty blue mountains; a solid mossy-stone
> ground silhouette along the very bottom; beneath the ground a dark near-black "under-floor"
> void band framing the bottom of the arena. Top-left and top-right CORNERS have chunky stone
> ceiling blocks with small warm torch glows — the center-top stays fully open sky (no full
> ceiling). Symmetric, left-right mirrored. Hanging chains and vines drape from the top
> corners. Left and right edges read as open tunnel gaps for screen-wrap. Muted lighting,
> subtle firefly/dust motes. Atmosphere only — NO floating platforms or ledges.

---

## 2) components.png — transparent atlas, ~1024 × 640 px

Transparent PNG. Each piece drawn at the exact pixel size below (collision == art). After
generation, measure the real rects and paste them into the `maps.gd` region consts (proposed
layout in the table's "atlas rect" column — adjust if the generator spaces pieces differently).

| Piece                 | size (W×H) px | used by                        | proposed atlas rect            |
|-----------------------|---------------|--------------------------------|--------------------------------|
| Floor strip           | 800 × 40      | floor                          | `Rect2(0, 0, 800, 40)`         |
| Side tower (×1, mirror)| 86 × 450     | left + right towers (`fill`)   | `Rect2(820, 0, 86, 450)`       |
| Ceiling cap (corner)  | 210 × 44      | both top-corner caps           | `Rect2(0, 48, 210, 44)`        |
| Wide platform (apex)  | 170 × 26      | central apex                   | `Rect2(220, 48, 170, 26)`      |
| Medium ledge          | 130 × 26      | side ledges L/R                | `Rect2(400, 48, 130, 26)`      |
| Spawn pad             | 150 × 26      | spawn pads L/R                 | `Rect2(540, 48, 150, 26)`      |

Each platform/ledge/pad: a clearly lit FLAT walkable top surface with a darker underside,
crisp opaque pixel edges (no soft glow bleeding past the edge — it must equal the hitbox).

**Higgsfield `generate_image` prompt:**

> Pixel-art sprite sheet, fully transparent background, 16-bit style, mossy green-and-teal
> ancient stone sky-temple theme, consistent top-down lighting on every piece, crisp opaque
> pixel edges. Draw these separate modular arena pieces, spaced apart on the transparent sheet,
> each at its exact pixel size: (1) a long horizontal FLOOR strip 800x40 with a mossy grass-lit
> top edge; (2) one vertical SIDE-TOWER 86x450 of carved mossy stone; (3) a chunky corner
> CEILING-CAP block 210x44; (4) a wide floating PLATFORM 170x26 with a flat lit walkable top and
> darker underside; (5) a medium floating LEDGE 130x26 same style; (6) a spawn PAD 150x26 same
> style. No glow bleeding past edges, no background fill — transparency only.

---

## 3) (optional) ambience audio — Higgsfield `generate_audio`

> Slow ambient loop for a mossy stone temple high above the clouds: soft wind, distant echoing
> water drips, faint high-altitude air tone. Calm, atmospheric, seamless loop, no music.

Then wire it: add an `ambience` controller script (mirror `verdant_cistern_ambience.gd`) and
set the level's `"ambience"` field.

---

## Wiring checklist (the later "connect images to the level" step)

1. Save `background.png` + `components.png` into this folder.
2. In `maps.gd`, Sky Temple entry: uncomment the `"background"` line.
3. Add region consts (e.g. `ST_FLOOR`, `ST_TOWER`, `ST_CAP`, `ST_APEX`, `ST_LEDGE`, `ST_PAD`)
   pointing at `components.png` with the measured rects.
4. Add `"sprite"`/`"sprite_region"` (and `"sprite_walkable"` = deck-top pixel row) to each wall
   entry. Side towers use `"sprite_mode": "fill"`.
5. Re-run headless import + parse-check, then launch and eyeball the arena.
