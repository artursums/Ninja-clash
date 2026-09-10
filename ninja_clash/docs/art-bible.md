# Four Clans — Art Bible

> **Status**: Draft v0.1 — pending Creative Director final review
> **Last Updated**: 2026-05-18
> **Implements Pillars**: Restraint over Spectacle · Fairness Is Sacred · Game-Feel First

This is the binding visual style guide for "Four Clans." Every art decision — character sprite, tile, VFX, UI element — must derive from this document. The pixel artist (human or AI-tooled) producing production assets works from this spec.

**Originality clause**: This game is mechanically inspired by TowerFall (dodge, throw, retrieve loop) but the visual identity is entirely original. No asset in this game may reproduce or closely paraphrase any specific copyrighted game's art.

---

## 1. Visual Pillars

These five statements are the governing filter for every art decision. When any choice is ambiguous, return here.

**1. Silhouette First.**
Every character, projectile, and prop must read instantly as a pure silhouette against any background. If two sprites look identical when filled with a single flat color, they are the same sprite to a player in a 60 fps reflex moment.

**2. Restraint over Spectacle.**
The game's core pillar applied to art: one punch-effect frame beats a particle cascade. Every VFX is 2–6 frames and then it is gone. No idle animations spin endlessly. No screen-fills. The visual language whispers at the same volume as the design language.

**3. Ukiyo-e Clarity.**
Bold, flat fills. Hard edges. Deliberate negative space. No gradients on characters or tiles. The reference is the woodblock-print aesthetic cited in `game-concept.md`: strong outline, minimal shading, value contrast doing the heavy lifting instead of detail.

**4. Fairness Is Visible.**
Every clan reads with equal clarity on every background. No clan is accidentally camouflaged. No clan's UI icon is harder to parse. Color balance is not a cosmetic courtesy; it is a mechanical fairness obligation.

**5. Cost Discipline.**
The art budget is constrained (one artist, ~3 months). Every spec decision must weigh production cost. Horizontal-flip mirroring, palette-swap recolors, and shared tile geometry are not compromises; they are first-class tools.

---

## 2. Resolution and Pixel Density

| Setting | Value | Rationale |
|---|---|---|
| Native game resolution | **384 × 216** | 16:9, 16 px grid-aligned. Scales cleanly to 1920×1080 at exactly 5× integer. Cleaner than 480×270 (which scales at 4.444×). |
| Tile size | **16 × 16 px** | Industry standard for 2D platformers at this resolution. 24×24 would be unnecessarily coarse for a platform-fighter requiring edge precision. |
| Character hitbox size | **12 × 28 px** | Matches prototype intent (PLAYER_W=20, PLAYER_H=32) but hitbox is narrower than drawn sprite. |
| Character sprite canvas | **16 × 32 px** per frame | Anchor at bottom-center. |
| Shuriken sprite canvas | **8 × 8 px** | At 384×216 native, 8 px reads clearly at 5× (40 px on screen) without competing with character. |
| Sub-pixel movement | **Not permitted** | Camera and all characters snap to integer pixel positions. Godot's `CanvasItem.texture_filter = NEAREST` enforced globally. |
| Camera shake | Integer-offset only (±1–2 px steps) | Preserves pixel crispness during hit-stop and death events. |

**Godot 4.6 setup notes:** `Project Settings > Display > Window > Size = 384×216`, `Stretch Mode = canvas_items`, `Stretch Aspect = keep`. All sprites: `Filter: Nearest`, mipmaps disabled.

---

## 3. Master Color Palette

The palette is **28 colors total**. Every pixel in the game must be drawn from this set.

### Background Deep (far layer, parallax 0.2×)
| Swatch | Hex | Role |
|---|---|---|
| Void | `#0D0D1A` | Absolute dark; sky, infinite depth |
| Deep indigo | `#161628` | Far architecture shadow |
| Midnight blue | `#1E2040` | Far silhouette shapes |

### Background Near (near layer, parallax 0.6×)
| Swatch | Hex | Role |
|---|---|---|
| Slate | `#2A2D4A` | Near rooftop shadow |
| Charcoal | `#363A56` | Near wall fill |
| Stone | `#4A4E6A` | Near wall highlight |
| Fog mist | `#6A6E88` | Near background haze accent |

### Midground / Environment (tiles, ground layer)
| Swatch | Hex | Role |
|---|---|---|
| Dark clay | `#2E2224` | Tile shadow / underside |
| Warm stone | `#4A3A38` | Tile fill |
| Stone highlight | `#6A5452` | Tile top-edge highlight |
| Light stone | `#8A7470` | Tile brightest surface |
| Moss accent | `#3A5240` | Decorative; map variation |
| Lantern amber | `#B87830` | Prop illumination color |
| Lantern glow | `#E8A848` | Prop bright point |

### Character Base (shared across all clans)
| Swatch | Hex | Role |
|---|---|---|
| Shadow cloth | `#141418` | Dark suit underlayer |
| Suit body | `#222230` | Main costume fill |
| Suit edge | `#383850` | Costume highlight edge |
| Skin tone | `#C08860` | Face / eye-slit detail |
| Skin shadow | `#8A5840` | Eye-slit shadow |

### UI Colors
| Swatch | Hex | Role |
|---|---|---|
| UI white | `#F0EEE8` | Primary text, score numbers |
| UI mid | `#A8A498` | Secondary text, labels |
| UI dark | `#1A1A24` | Panel backgrounds |
| UI gold | `#D4A830` | Match-win highlight |
| UI danger | `#C03030` | Low-stash warning indicator |

### Clan Accents
8 additional colors — 2 per clan (see Section 4).

**Total palette: 28 colors.**

---

## 4. Clan Color Schemes

The four clans are mechanically identical; color is their entire identity surface.

### Contrast methodology
All clan primary colors are tested against the darkest environment tile (`#2E2224`) and the near-background base (`#2A2D4A`). Target: luminance contrast ratio ≥ 4.5:1 against the darkest tile surface a character commonly appears against.

| Clan | Primary Hex | Primary Name | Secondary Hex | Secondary Name | Contrast vs dark tile | Emblem Motif |
|---|---|---|---|---|---|---|
| **Shadow** | `#7B44C8` | Deep violet | `#B888F8` | Pale amethyst | ~5.2:1 | Closed crescent — convex-forward curved blade, drawn-knife-mid-arc shape |
| **Storm** | `#2E88E8` | Sky blue | `#88CCFF` | Ice highlight | ~4.8:1 | Jagged horizontal split — single zigzag line crossing a circle |
| **Frost** | `#48C8C8` | Cold teal | `#A8F0F0` | Near-white cyan | ~6.1:1 | Six-point crystalline node — six equal lines radiating from center |
| **Fire** | `#E05030` | Burnt crimson | `#F0A040` | Ember orange | ~5.5:1 | Upward-pointing delta — solid triangle with notch cut from base |

**Colorblind note (Open Question #1):** Storm blue and Frost teal may merge under deuteranopia. Value differential (Frost secondary is near-white, Storm is mid-value) provides partial mitigation. Final validation required from accessibility specialist.

---

## 5. Character Sprite Specification

### Silhouette Rules
- Hood forms a triangular peak at top of sprite at all times. Even in crouch, the hood compresses but does not disappear.
- A single scarf tail extends from the left-shoulder area as a directional marker. When sprite is horizontally flipped, scarf tail position implicitly reads as facing direction — no hand-authored left/right sets needed.
- Body is narrower at waist than at shoulder, creating a readable T-shape at 5× on a shared screen.
- Clan primary appears on: upper torso sash band, boot toe accent, scarf tail.
- Clan secondary appears on: eye-slit strip, knuckle guards, emblem placement on upper chest.

### Mirroring Strategy
**Horizontal flip only.** No hand-authored left-facing frames. This halves animation production cost.

### Animation Set

| State | Frames | FPS | Notes |
|---|---|---|---|
| `idle` | 3 | 6 | Subtle chest breathing — pixel shifts on hood and lower scarf. No foot movement. |
| `run` | 6 | 12 | Arms back, forward lean on frames 2–4. Reads as purposeful, not frantic. |
| `jump_rise` | 2 | 12 | Frame 1: tuck (arms in, knees up). Frame 2: extension. |
| `jump_apex` | 1 | — | Single hold. Slight spread-arm "float." |
| `jump_fall` | 2 | 12 | Frame 1: descent tuck. Frame 2: brace (arms forward, knees bent). |
| `crouch` | 1 | — | Static. Hood compresses to 60% height. Scarf tucked. |
| `dodge` | 3 | 24 | Frame 1: lean-in. Frame 2: full horizontal blur (motion streak 2–3 px wide). Frame 3: exit lean. Frame 2 is critical — it communicates i-frame state. |
| `slide` | 2 | 12 | Frame 1: initial drop (crouch entry). Frame 2: full low slide (feet-first horizontal). |
| `wall_grab` | 2 | 8 | Frame 1: press flat against wall. Frame 2: fingers splay. Alternates slowly. |
| `throw` | 3 | 24 | Frame 1: wind-up (arm back, shuriken visible). Frame 2: release (arm extended, shuriken leaves hand). Frame 3: recovery. |
| `iframe_flash` | — | — | **Not new frames.** Color-cycled palette overlay: alternate between normal modulate and clan secondary color at 12 Hz. Implemented in code (replace prototype's yellow flash with clan-secondary). |
| `hurt` | 2 | 12 | Frame 1: impact recoil (arms thrown back, hood snaps). Frame 2: collapse begin. |
| `death` | 4 | 10 | Frames 1–2: fall arc. Frame 3: ground contact. Frame 4: fade (alpha drop, 50% opacity hold). |

### Frame Budget Per Clan

| Animation group | Frames |
|---|---|
| idle (3) + run (6) + jump set (5) + crouch (1) | 15 |
| dodge (3) + slide (2) + wall_grab (2) | 7 |
| throw (3) + hurt (2) + death (4) | 9 |
| **Total per clan** | **31 frames** |

Because all four clans share base geometry and differ only by color, **the base animation set is 31 frames drawn once, then palette-swapped four times.** Total unique frames drawn: 31.

**Palette swap implementation:** Custom Godot shader on the `CanvasItem` that remaps clan base colors to target clan colors. Delegate shader authoring to the technical-artist. Source palette uses Shadow clan primary as the canonical "base."

---

## 6. Shuriken and Projectile Sprites

### Resting / Embedded Sprite
**6 × 6 px.** 4-point star form with two blades slightly overlapping a surface. Wall-stuck variant has one blade clipped (occluded behind wall tile). Two sprites: `shuriken_floor.png` and `shuriken_wall.png`. Palette-swapped per clan.

### Flying Sprite
**8 × 8 px.** 4-point form drawn elongated along horizontal axis (8×6 art on 8×8 canvas) to suggest spin. **Rotation strategy: sprite rotation in code** (Godot's `rotation` property on the `Area2D`). Do not hand-draw rotated frames. At 8 px, sub-rotation artifacts read as spinning, not as defects.

### Throw Arc Trail
**None in v1.** "Restraint over Spectacle" applies. The throw-origin flash provides sufficient thrown-event feedback. Revisit only if playtesting identifies a readability problem.

### Catch Flash
3-frame sprite, **12 × 12 px**, at character hand position on successful i-frame catch:
1. Small star burst (6 rays, 2 px length)
2. Larger burst (8 rays, 4 px length)
3. Fading remnant (4 short rays, 50% opacity)

Uses catching player's **clan secondary color** — the only moment secondary appears as VFX, reinforcing identity at a mechanically critical moment.

---

## 7. Environment / Tile Specification

### Tile Set Architecture
**16 × 16 px tiles, 47-tile auto-tile format** (Godot 4.6 `TileSet` with terrain sets). Provides corners, edges, fill, thin-platform top-edge, and all transitions automatically. The 9-slice approach is insufficient for a platformer where tiles can appear in any configuration.

A single tile set is shared across all maps. Maps vary by **palette skin** and **decorative prop layer**.

### Platform vs. Wall Visual Distinction
- **Platforms (passable from below):** Top-edge tile has a highlighted stone cap (2 px highlight strip in `#8A7470`). Underside is dark clay (`#2E2224`) with no edge highlight. Visually lighter on top, darker below — reinforces affordance.
- **Walls (solid, impassable):** Same fill tile as platforms. Distinguished by highlight edge on left or right face (whichever faces open space). Players associate the highlight edge with climbable/hangable surface — also communicates wall-grab affordance.

### Background Parallax Layers

Two layers, non-interactive:

| Layer | Parallax | Content | Color range |
|---|---|---|---|
| Far (BG-0) | 0.15× | Distant rooftop silhouettes, fog bands | `#0D0D1A` to `#1E2040` |
| Near (BG-1) | 0.5× | Close architecture: curved roof edges, hanging lantern outlines, paper-screen window shapes | `#2A2D4A` to `#4A4E6A` |

Both pre-rendered as 768×216 strips (2× screen width for horizontal panning headroom).

### Decorative Props
All on a non-collision decoration layer. Original motifs only.

| Prop | Size | Description |
|---|---|---|
| `prop_lantern_hang` | 8×16 | Cylindrical paper lantern, flat cap, single horizontal band. Illuminated variant glows amber. |
| `prop_banner_sway` | 8×24 | Rectangular fabric strip, plain, with map accent color and single horizontal stripe. 2-frame gentle sway. |
| `prop_roof_tile` | 16×8 | Curved tile row, single concave sweep. Used to cap building tops. |
| `prop_rope_knot` | 8×8 | Static rope coil. No physics. |
| `prop_wall_ring` | 6×6 | Iron ring embedded in wall. Decorative; signals "structure, not natural rock." |

### Map Theme Guidance
All v1 maps use the shared tile set. Visual identity per map comes from:
1. Tile palette skin (3 skins planned: Blue-night / Red-dusk / Gold-fog)
2. Background silhouette shape per map
3. Banner color (ties to map accent)
4. Prop density and arrangement

One tile set shipped, three palette skins, varied prop placement — fits production budget.

---

## 8. VFX Specification

All VFX are sprite-based, drawn at native resolution. No shader-based particle systems in v1. Each effect is a single spritesheet strip, played once, destroyed.

| Effect | Canvas | Frames | FPS | Color source | Notes |
|---|---|---|---|---|---|
| `vfx_dodge_dust` | 16×8 | 4 | 20 | Tile palette (stone tones) | Small ground puff, wide and low. Floor only — never mid-air. |
| `vfx_wall_dust` | 8×16 | 3 | 18 | Tile palette | Vertical scrape at wall contact during wall-grab. |
| `vfx_shuriken_hit_wall` | 12×12 | 4 | 24 | Clan secondary of thrower | 4 short lines radiating from contact, shrinking. Frame 4 blank. |
| `vfx_shuriken_hit_player` | 16×16 | 5 | 24 | Clan secondary of thrower + UI danger (`#C03030`) | Initial white core → clan color burst → danger-red residual. Red frame signals lethality. |
| `vfx_death_poof` | 24×24 | 5 | 14 | Clan primary of victim | Rising cloud silhouette, soft smoke (not cartoon explosion). Victim clan primary fades to black by frame 5. Slow and gentle — death is quiet. |
| `vfx_round_start_flash` | 384×216 | 3 | 18 | UI white fading | Brief white frame-flash (60% → 25% → 0%). Camera-blink, not screen-fill. |
| `vfx_catch_flash` | 12×12 | 3 | 24 | Clan secondary of catcher | Specified in Section 6. |

---

## 9. UI Visual Style

### HUD Layout (4-player)
Each player's HUD anchored to one corner:
- **P1 (Fire)** = bottom-left
- **P2 (Storm)** = bottom-right
- **P3 (Shadow)** = top-left
- **P4 (Frost)** = top-right

### Elements per player
- **Clan badge**: 16×16 tile showing clan emblem on dark panel (`#1A1A24`).
- **Stash counter**: 3 shuriken icons (8×8) arranged horizontally below badge. Filled = clan primary color. Empty = silhouette outline only in dim mid-grey. **No numbers** — the prototype's numeric counter is replaced with icons for faster perceptual reading.
- **Round score**: Single numeral (0–10) in pixel font, UI white, below stash counter. No framing box.

### Low-stash warning
When stash = 0, empty icon row pulses between dim-grey and UI danger (`#C03030`) at 4 Hz. No sound involvement at art layer.

### Round Banner / Kill Feed
- **Round-end banner**: 384×24 centered text strip. "[CLAN NAME] WINS ROUND" in pixel font, clan primary color on `#1A1A24`. Holds 1.5 s then fades. Slides in from top (8 px down).
- **Kill feed**: Single line below banner zone for 1 s: "[CLAN ICON] eliminated [CLAN ICON]" with 8×8 badges flanking pixel-font label. Replaces prototype's print-to-console kill log.

### Match-End Screen
Full-screen overlay (`#1A1A24` at 85% opacity). Winner clan badge at 3× size (48×48). Score tally in 4-row table. "PLAY AGAIN" prompt in UI gold. Single `vfx_round_start_flash` on appearance.

### Clan Select / Menu Style (forward design)
Menus do not exist in v1 MVP but direction is set now to prevent future divergence:
- Background `#0D0D1A`
- Four clan tiles in 2×2 grid at center, each 64×64 (4× badge size)
- Selected: 2 px outer-glow border in clan primary color (border sprite, not shader)
- Unselected: desaturated greyscale (via modulate)
- Navigation cues: pixel font, UI white

### Font
**m6x11 by Daniel Linssen (CC0 license).** Freely available on itch.io. 6 px base height, 11 px line height — readable at 5× (30 px on 1080p) without antialiasing. Single font across all UI enforces visual coherence.

---

## 10. Asset Delivery Specification

### File Format
- **Sprites**: PNG with transparency. Source files in Aseprite (`.aseprite`) preferred — preserves layers, palette, animation tags.
- **Tiles**: PNG spritesheet, Godot-compatible tile atlas. Aseprite source alongside.
- **VFX**: PNG strips (horizontal, all frames in one row).

### Sprite Sheet Layout
Each animation is a horizontal strip. The "all" atlas is preferred Godot delivery: one file, one `SpriteFrames` resource with animation tags.

### Naming Convention
`[category]_[name]_[variant]_[size].[ext]`

| Example | Meaning |
|---|---|
| `char_ninja_shadow_16x32.png` | Character, ninja, Shadow clan |
| `char_ninja_fire_16x32.png` | Character, ninja, Fire clan |
| `env_tile_blue-night_16x16.png` | Environment tile atlas, blue-night palette |
| `ui_badge_storm_16x16.png` | UI clan badge, Storm |
| `ui_icon_shuriken_filled_8x8.png` | UI stash icon, filled |
| `vfx_death_poof_shadow_24x24.png` | VFX death poof, Shadow clan color |
| `prop_lantern_hang_8x16.png` | Prop, hanging lantern |

### Folder Structure

```
assets/
  sprites/
    characters/
      char_ninja_shadow_16x32.aseprite
      char_ninja_shadow_16x32.png
      char_ninja_storm_16x32.png
      char_ninja_frost_16x32.png
      char_ninja_fire_16x32.png
    projectiles/
      proj_shuriken_shadow_8x8.png
      proj_shuriken_floor_8x8.png
      proj_shuriken_wall_8x8.png
    vfx/
      vfx_dodge_dust_16x8.png
      vfx_wall_dust_8x16.png
      vfx_hit_wall_12x12.png
      vfx_hit_player_16x16.png
      vfx_death_poof_24x24.png   (one per clan)
      vfx_round_flash_384x216.png
  tiles/
    env_tile_blue-night_16x16.png
    env_tile_red-dusk_16x16.png
    env_tile_gold-fog_16x16.png
    env_tile_source.aseprite
  ui/
    ui_badge_shadow_16x16.png
    ui_badge_storm_16x16.png
    ui_badge_frost_16x16.png
    ui_badge_fire_16x16.png
    ui_icon_shuriken_filled_8x8.png
    ui_icon_shuriken_empty_8x8.png
    ui_font_m6x11.ttf
  props/
    prop_lantern_hang_8x16.png
    prop_banner_sway_8x24.png
    prop_roof_tile_16x8.png
    prop_rope_knot_8x8.png
    prop_wall_ring_6x6.png
```

### Godot 4.6 Import Settings
All sprite/tile PNGs:
- `Texture Filter: Nearest`
- `Mipmaps: Disabled`
- `Process: Detect 3D: Off`
- `Compress: Lossless (PNG)`

Tile set atlas: import as `TileSet` resource. Terrain sets configured manually after first import.

---

## 11. Production Estimate

Assuming one mid-skill pixel artist (Aseprite-fluent, comfortable with tile work and small animation sets):

| Task | Est. Days |
|---|---|
| Master palette + style guide lock-in iterations | 1 |
| Base character sprite + all 31 frames (1 clan) | 5–7 |
| Palette-swap 3 remaining clans + shader integration test | 1–2 |
| Shuriken sprites (fly, floor, wall) + catch flash | 1 |
| All 7 VFX strips | 2–3 |
| Tile set: 47-tile auto-tile geometry (source) | 3–4 |
| 3 tile palette skins | 1–2 |
| Background parallax strips × 2 layers | 1–2 |
| Decorative props × 5 | 1 |
| UI: badges × 4, stash icons, round banner, score | 2 |
| Map decoration layout for 4 maps (artist places props) | 2–3 |
| Revision cycles + integration fixes | 3 |
| **Total** | **23–31 art-days** |

**~5–6 calendar weeks** for a dedicated pixel artist. Realistic for Vertical Slice target; achievable for v1 Launch if art production starts at Alpha entry.

**AI pixel-art tool estimate** (Aseprite + generation workflow): does not shrink significantly. Budget 60–70% of human estimate for manual palette/consistency cleanup.

**Scope lever:** If timeline is too long, the largest savings come from cutting `slide`, `wall_grab`, and `hurt` animations (using `crouch`, `jump_apex`, and `idle` as functional stand-ins). Saves ~4–5 art-days. Not recommended for v1 Launch.

---

## Open Questions (require Creative Director resolution before lock)

1. **Colorblind palette safety.** Storm blue (`#2E88E8`) and Frost teal (`#48C8C8`) are distinguishable under trichromatic vision but may merge under deuteranopia. Adjust one clan hue, or defer to accessibility specialist and treat as v1.x patch?

2. **Palette swap method: shader or spritesheet?** Spec recommends shader (one base sprite, four runtime recolors). Alternative is four separate sheets. Shader halves storage and artist time; spritesheet is simpler to implement/debug. Must be confirmed with technical-artist **before** character sprite is drawn — source palette decisions depend on it.

3. **Death animation tone.** Spec calls for "gentle rising poof" aligning with "Restraint over Spectacle." Alternative read of couch PvP favors a more expressive death (brief ragdoll, exaggerated collapse). Which serves couch-fellowship aesthetic better?

4. **Map count vs. tile skin count.** 3 palette skins for 4 maps means two maps share a palette skin, differentiated by layout/props. Sufficient variety, or add a 4th skin (+1–2 art-days)?

5. **Native resolution: 384×216 vs. 480×270.** Spec recommends 384×216 (5× to 1080p). 480×270 scales at 4× to 1080p — also clean, gives 30 vs 24 tiles horizontal real estate. Affects map design feel. Lock with level-designer + technical-director before any tile work.

---

## Dependencies

- **Pillars** (`docs/gdd/game-pillars.md`): Visual pillars align with Restraint over Spectacle, Fairness Is Sacred, Game-Feel First.
- **Game Concept** (`docs/gdd/game-concept.md`): Clan names, mechanical identity, scope tier.
- **Launch Map Specs** (`docs/levels/launch-maps.md`): Map count, theme assignments, tile palette skin requirements feed back into this document.
- **Combat GDD** (`docs/gdd/combat.md`): VFX trigger events (catch, hit, death) sourced from combat signals.
- **Movement / Player** (`docs/gdd/movement.md` if exists, `prototypes/movement-and-combat/player.gd`): Animation state list derived from player state machine.

## Downstream consumers

- **Technical-artist**: Implements palette-swap shader, parallax layer setup, Godot import settings.
- **Pixel artist (human or AI-tooled)**: Produces all sprite/tile/VFX assets per spec.
- **UI programmer**: Implements HUD layout, stash icons, score display, kill feed.
- **Level designer**: Tile palette skins consumed per map; prop placement uses prop atlas.
