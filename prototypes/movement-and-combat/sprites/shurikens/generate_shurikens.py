"""
Color-coded shuriken sprites for the 4 ninjas + flight trail particles.

Per color a single PNG strip with 9 frames at 16x16 native:
  Frames 1-4: spinning shuriken (rotation 0°, 22.5°, 45°, 67.5°)
              Loops as the in-flight animation.
  Frames 5-8: trail particles — fading color-tinted afterimages the
              game spawns at the shuriken's previous positions to draw
              a glowing comet-like trail.
  Frame 9   : impact / stuck-in-wall pose — shuriken at a fixed angle
              with small white impact lines around it.

How to use in-engine:

  Every tick while the shuriken is in flight:
    1. Render frame (1..4) at the current position — cycles fast for
       blurry "spinning blade" feel (1 frame per 1-2 ticks at 60fps).
    2. Push the current position into a short ring buffer (e.g. last
       4 positions). Render frame 5 at history[-1], frame 6 at history[-2],
       frame 7 at history[-3], frame 8 at history[-4]. That gives you a
       4-step glowing comet tail.

  On contact:
    Render frame 9 anchored to the impact point, and spawn the
    universal strike-flash FX (from generate_combat_fx.py) on top.
"""

import os
import math
from PIL import Image, ImageDraw


SPRITE_W = SPRITE_H = 16
FRAMES_PER_COLOR = ['spin0', 'spin22', 'spin45', 'spin67',
                    'trail1', 'trail2', 'trail3', 'trail4',
                    'impact']
STRIP_W = SPRITE_W * len(FRAMES_PER_COLOR)   # 144
STRIP_H = SPRITE_H


# ---------- ninja palette (matches everything else) ---------
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

# ---------- metal palette (universal) -----------------------
METAL_HI    = (245, 248, 255)
METAL       = (200, 208, 222)
METAL_MID   = (150, 158, 180)
METAL_DARK  = (90, 95, 125)
METAL_EDGE  = (30, 32, 48)
WHITE_HOT   = (255, 255, 240)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ============================================================
#  Core shuriken drawing: math-based 4-point star with rotation
# ============================================================
def star_polygon(cx, cy, r_outer, r_inner, n_points, rotation_rad):
    """Vertices of a 2N-vertex star polygon (alternating outer/inner)."""
    verts = []
    for i in range(n_points * 2):
        r = r_outer if i % 2 == 0 else r_inner
        # Start a point at the top by offsetting by -pi/2 (so 0 rotation
        # has one tip pointing straight up).
        angle = i * math.pi / n_points - math.pi / 2 + rotation_rad
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        verts.append((x, y))
    return verts


def draw_shuriken(d, ox, oy, rotation_deg, accent_color,
                  r_outer=7.1, r_inner=1.8):
    """Full-quality shuriken at center of a 16x16 frame.
       accent_color = ninja's main color (used on the center hub)."""
    cx, cy = ox + 7.5, oy + 7.5
    rot = math.radians(rotation_deg)

    # 1. Outline / silhouette
    outline_verts = star_polygon(cx, cy, r_outer, r_inner, 4, rot)
    d.polygon(outline_verts, fill=rgba(METAL_EDGE))

    # 2. Main metal body (slightly smaller than outline)
    body_verts = star_polygon(cx, cy, r_outer - 0.6, r_inner - 0.1, 4, rot)
    d.polygon(body_verts, fill=rgba(METAL))

    # 3. Highlight blade (one side of each point catches more light)
    # We draw a smaller star but offset to one side to simulate light.
    hi_offset = 0.5
    hi_verts = star_polygon(cx - hi_offset, cy - hi_offset,
                            r_outer - 1.4, r_inner - 0.2, 4, rot)
    d.polygon(hi_verts, fill=rgba(METAL_HI))

    # 4. Mid-tone shadow on opposite side (rebuild as small star at offset)
    shadow_verts = star_polygon(cx + 0.8, cy + 0.8,
                                r_outer - 2.0, r_inner - 0.2, 4, rot)
    d.polygon(shadow_verts, fill=rgba(METAL_MID))

    # 5. Color-coded central hub — ninja's color (circle)
    hub_r = 2.2
    d.ellipse([cx - hub_r, cy - hub_r, cx + hub_r, cy + hub_r],
              fill=rgba(accent_color), outline=rgba(METAL_EDGE))

    # 6. Center hole / rivet (dark)
    d.ellipse([cx - 0.9, cy - 0.9, cx + 0.9, cy + 0.9],
              fill=rgba(METAL_EDGE))


# ============================================================
#  Trail particle — fading + color-tinted + smaller per stage
# ============================================================
def draw_trail_particle(d, ox, oy, rotation_deg, accent_color, hi_color,
                        stage):
    """stage 1 = closest to shuriken (biggest, brightest),
       stage 4 = oldest position (smallest, faintest).

       The trail particle should clearly read as a shuriken silhouette
       with a subtle color glow around it — NOT a colored ball."""
    cx, cy = ox + 7.5, oy + 7.5
    rot = math.radians(rotation_deg)

    # Scale with stage — newer trail = bigger
    scale = {1: 0.95, 2: 0.78, 3: 0.6, 4: 0.42}[stage]
    alpha_main = {1: 235, 2: 185, 3: 130, 4: 75}[stage]
    # Halo opacity — much subtler now so silhouette stays readable
    alpha_glow_outer = {1: 55, 2: 40, 3: 28, 4: 18}[stage]
    alpha_glow_inner = {1: 90, 2: 65, 3: 45, 4: 25}[stage]
    r_outer = 6.5 * scale
    r_inner = 1.5 * scale

    # Two-stop soft halo behind the silhouette — outer ring very faint,
    # inner ring slightly stronger. Sized so the star points still poke
    # through clearly.
    halo_r_outer = r_outer + 0.8
    halo_r_inner = r_outer * 0.5
    d.ellipse([cx - halo_r_outer, cy - halo_r_outer,
               cx + halo_r_outer, cy + halo_r_outer],
              fill=(accent_color[0], accent_color[1], accent_color[2],
                    alpha_glow_outer))
    d.ellipse([cx - halo_r_inner, cy - halo_r_inner,
               cx + halo_r_inner, cy + halo_r_inner],
              fill=(accent_color[0], accent_color[1], accent_color[2],
                    alpha_glow_inner))

    # Strong-edged shuriken silhouette — saturated ninja color with
    # only a touch of white blend so it doesn't wash out
    verts = star_polygon(cx, cy, r_outer, r_inner, 4, rot)
    blend = {1: 0.25, 2: 0.18, 3: 0.12, 4: 0.08}[stage]
    body_r = int(accent_color[0] * (1 - blend) + 255 * blend)
    body_g = int(accent_color[1] * (1 - blend) + 255 * blend)
    body_b = int(accent_color[2] * (1 - blend) + 255 * blend)
    d.polygon(verts, fill=(body_r, body_g, body_b, alpha_main))

    # Sharp white-hot core for the newest 1-2 frames — sells the speed
    if stage <= 2 and scale >= 0.6:
        core_r = max(0.7, r_outer * 0.28)
        d.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r],
                  fill=(WHITE_HOT[0], WHITE_HOT[1], WHITE_HOT[2],
                        alpha_main))


# ============================================================
#  Impact pose — shuriken stuck in surface with impact lines
# ============================================================
def draw_impact(d, ox, oy, accent_color, hi_color):
    """A static shuriken at a slight angle with small white impact streaks
    around it — looks like it just stuck into something."""
    # Main shuriken, slight tilt
    draw_shuriken(d, ox, oy, rotation_deg=15, accent_color=accent_color,
                  r_outer=7.0, r_inner=1.8)

    # Impact streaks — short lines radiating outward
    cx, cy = ox + 7.5, oy + 7.5
    streaks = [
        (cx - 7, cy - 2,  cx - 5, cy - 2),
        (cx + 7, cy - 1,  cx + 5, cy - 1),
        (cx,     cy - 7,  cx,     cy - 5),
        (cx,     cy + 7,  cx,     cy + 5),
        (cx - 5, cy + 5,  cx - 4, cy + 4),
        (cx + 5, cy + 5,  cx + 4, cy + 4),
    ]
    for x1, y1, x2, y2 in streaks:
        d.line([(x1, y1), (x2, y2)], fill=rgba(WHITE_HOT, 220), width=1)

    # Small bright sparks at the tips
    for sx, sy in [(cx - 8, cy), (cx + 8, cy), (cx, cy - 8), (cx, cy + 8)]:
        if 0 <= sx - ox < SPRITE_W and 0 <= sy - oy < SPRITE_H:
            d.point((sx, sy), fill=rgba(hi_color, 230))


# ============================================================
#  Render one color's full 9-frame strip
# ============================================================
def render_strip(palette):
    img = Image.new('RGBA', (STRIP_W, STRIP_H), TRANSPARENT)
    d = ImageDraw.Draw(img)

    accent = palette['main']
    hi = palette['hi']

    # Spin frames — rotations 0, 22.5, 45, 67.5
    spin_rotations = [0, 22.5, 45, 67.5]
    for i, rot in enumerate(spin_rotations):
        draw_shuriken(d, i * SPRITE_W, 0, rot, accent_color=accent)

    # Trail frames — stage 1 (newest/closest) to stage 4 (oldest/farthest)
    # Each trail particle uses a different rotation so the trail looks
    # like the shuriken was spinning at each past position.
    trail_rotations = [33, 50, 12, 70]   # arbitrary but varied
    for i, (rot, stage) in enumerate(zip(trail_rotations, [1, 2, 3, 4])):
        ox = (4 + i) * SPRITE_W
        draw_trail_particle(d, ox, 0, rot, accent, hi, stage=stage)

    # Impact frame
    draw_impact(d, 8 * SPRITE_W, 0, accent, hi)

    return img


# ============================================================
#  Build an in-flight composite demo — shows the shuriken with its
#  trail laid out as it would look streaking through the air.
# ============================================================
def render_inflight_demo(palette, length=120, height=40):
    """Sample composite: shuriken flying left-to-right with full trail."""
    img = Image.new('RGBA', (length, height), TRANSPARENT)
    accent = palette['main']
    hi = palette['hi']

    # The shuriken's path: a slight downward arc
    # Position the head at x=100, y=20
    head_x, head_y = 100, 20

    # Trail particles at previous positions (going back left)
    # Stage 1 closest to the head, stage 4 farthest
    trail_positions = [
        (head_x - 14, head_y + 1, 1, 33),
        (head_x - 28, head_y + 3, 2, 50),
        (head_x - 42, head_y + 5, 3, 12),
        (head_x - 56, head_y + 7, 4, 70),
    ]
    d = ImageDraw.Draw(img)
    for tx, ty, stage, rot in trail_positions:
        # offset so center lands at (tx, ty)
        draw_trail_particle(d, tx - 7, ty - 7, rot, accent, hi, stage=stage)

    # The head shuriken on top
    draw_shuriken(d, head_x - 7, head_y - 7, rotation_deg=22.5,
                  accent_color=accent)
    return img


# ============================================================
#  Save everything
# ============================================================
ROOT = '/sessions/nice-zen-rubin/mnt/outputs'
OUT_DIR = f'{ROOT}/ninjas/shurikens'
os.makedirs(OUT_DIR, exist_ok=True)

for name, palette in PALETTES.items():
    strip = render_strip(palette)
    strip.save(f'{OUT_DIR}/shuriken_{name}_9frame_native_144x16.png')
    strip.resize((STRIP_W * 4, STRIP_H * 4), Image.NEAREST).save(
        f'{OUT_DIR}/shuriken_{name}_9frame_4x_576x64.png'
    )
    strip.resize((STRIP_W * 8, STRIP_H * 8), Image.NEAREST).save(
        f'{OUT_DIR}/shuriken_{name}_9frame_8x_1152x128.png'
    )
    print(f'Wrote shuriken_{name}')

# Combined preview — all 4 colors stacked
preview_h = (STRIP_H * 8 + 8) * 4
combined = Image.new('RGBA', (STRIP_W * 8, preview_h), (24, 18, 36, 255))
y_off = 0
for name in ['cyan', 'magenta', 'orange', 'green']:
    s = Image.open(f'{OUT_DIR}/shuriken_{name}_9frame_8x_1152x128.png')
    combined.paste(s, (0, y_off), s)
    y_off += STRIP_H * 8 + 8
combined.save(f'{OUT_DIR}/shurikens_preview_all.png')
print('Wrote shurikens_preview_all.png')

# In-flight demo composite — shows how it looks in motion
demo_w = 120 * 6
demo_per_h = 40 * 6
demo_img = Image.new('RGBA', (demo_w + 20, (demo_per_h + 12) * 4 + 12),
                     (18, 14, 30, 255))
y_off = 6
for name in ['cyan', 'magenta', 'orange', 'green']:
    flight = render_inflight_demo(PALETTES[name])
    flight_big = flight.resize((flight.size[0] * 6, flight.size[1] * 6),
                               Image.NEAREST)
    demo_img.paste(flight_big, (10, y_off), flight_big)
    y_off += demo_per_h + 12
demo_img.save(f'{OUT_DIR}/shurikens_inflight_demo.png')
print('Wrote shurikens_inflight_demo.png')
