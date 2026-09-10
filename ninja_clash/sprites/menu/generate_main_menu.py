"""
MAIN MENU asset generator — FOUR CLANS.

Same pixel-art family as round_indicator / player_wins (weathered stone for
text, drop shadow, chunky pixels). All outputs are transparent PNGs so the
Godot scene can compose them freely.

Outputs (all under sprites/menu/):

    Background (parallax layers, native 480x270, also 4x):
        bg_sky.png             — moon + gradient sky + stars (SOLID, opaque)
        bg_mountains.png       — distant mountain ridge (transparent)
        bg_pagoda.png          — temple silhouette + glowing windows
        bg_foreground.png      — sakura branches + lantern + bamboo

    Title:
        title_four_clans.png   — stone-carved "FOUR CLANS" wordmark
        title_subtitle.png     — bamboo plank with "shinobi arena"
        title_katanas.png      — crossed katanas (placed behind title)

    Buttons (4 × 3 states, ~160x44 native wood plank with rope):
        button_start_{normal,hover,pressed}.png
        button_options_{normal,hover,pressed}.png
        button_credits_{normal,hover,pressed}.png
        button_quit_{normal,hover,pressed}.png

    Previews:
        menu_preview.png       — full mockup composition (sky+layers+title+buttons)
        menu_buttons_preview.png

All sprites are saved at native and 4x (NEAREST upscaled). Compose them in
Godot with TextureRect / Sprite2D nodes — bg_sky as the deepest ParallaxLayer,
the foreground at the front, title centered, buttons stacked below.
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter


# ============================================================
#  CONFIG / PATHS
# ============================================================
FONT_BLACK = '/usr/share/fonts/truetype/lato/Lato-Black.ttf'
FONT_BOLD  = '/usr/share/fonts/truetype/lato/Lato-Bold.ttf'

_BASH = '/sessions/gracious-determined-hamilton/mnt/ninja_clash/sprites/menu'
_HOST = '/Users/a88/IdeaProjects/minu-mang/ninja_clash/sprites/menu'
OUT_DIR = _BASH if os.path.isdir(_BASH) else _HOST
os.makedirs(OUT_DIR, exist_ok=True)


# ============================================================
#  COLOR PALETTES
# ============================================================
TRANSPARENT = (0, 0, 0, 0)

# Sky / night palette
SKY_TOP        = (10, 8, 28)        # near-black indigo
SKY_MID        = (28, 22, 64)       # deep purple
SKY_HORIZON    = (62, 46, 92)       # warm violet near horizon
MOON_CORE      = (250, 244, 218)    # warm bone
MOON_RIM       = (220, 208, 168)
MOON_GLOW      = (210, 192, 230)
STAR_BRIGHT    = (235, 232, 248)
STAR_DIM       = (180, 175, 210)

# Mountains
MTN_FAR        = (44, 38, 78)
MTN_FAR_HI     = (66, 58, 102)
MTN_MID        = (32, 28, 60)
MTN_MID_HI     = (52, 46, 82)
MTN_NEAR       = (20, 16, 38)
MTN_FOG        = (90, 80, 130)

# Pagoda
PAGODA_DARK    = (18, 14, 32)
PAGODA_MID     = (40, 30, 54)
PAGODA_HI      = (66, 48, 70)
PAGODA_ROOF    = (52, 24, 36)
PAGODA_ROOF_HI = (88, 44, 56)
PAGODA_WIN     = (255, 178, 78)
PAGODA_WIN_HOT = (255, 232, 150)
PAGODA_RAIL    = (90, 60, 80)

# Foreground decor
SAKURA_TRUNK   = (54, 34, 30)
SAKURA_BARK_HI = (90, 58, 50)
SAKURA_PETAL   = (255, 180, 210)
SAKURA_PETAL_D = (218, 130, 168)
SAKURA_BUD     = (242, 102, 158)
BAMBOO_DARK    = (40, 68, 38)
BAMBOO_MID     = (80, 130, 58)
BAMBOO_HI      = (130, 178, 90)
BAMBOO_NODE    = (28, 48, 24)
LANTERN_BODY   = (210, 50, 40)
LANTERN_RIM    = (122, 28, 22)
LANTERN_GLOW   = (255, 198, 90)
LANTERN_HOT    = (255, 240, 180)
LANTERN_WOOD   = (60, 38, 22)
ROPE_COL       = (228, 196, 138)
ROPE_DK        = (140, 102, 58)

# Stone (title) — matches player_wins NEUTRAL
STONE_TONES = [(44, 36, 26), (78, 66, 50), (118, 102, 78),
               (152, 136, 104), (192, 174, 138), (228, 212, 178)]
RIM_HI   = (228, 212, 178)
RIM_MID  = (192, 174, 138)
PIT_DK   = (78, 66, 50)
PIT_MID  = (118, 102, 78)
MOSS_DARK    = (44, 78, 30)
MOSS_MID     = (76, 122, 50)
MOSS_BRIGHT  = (130, 178, 76)
MOSS_TIP     = (188, 222, 132)
LICHEN_ORG   = (220, 170, 90)
LICHEN_WHITE = (210, 220, 215)
CRACK_DEEP   = (16, 12, 22)
CRACK_LIFT   = (175, 158, 122)
OUTLINE_COL  = (18, 14, 24)
SHADOW_NEAR  = (22, 16, 30)
SHADOW_FAR   = (44, 32, 54)

# Wooden plank (buttons)
WOOD_DK   = (54, 32, 18)
WOOD_MD   = (98, 60, 30)
WOOD_HI   = (140, 92, 46)
WOOD_GRAIN_HI = (170, 122, 68)
WOOD_GRAIN_DK = (38, 22, 12)
WOOD_EDGE = (26, 16, 8)
TEXT_LIGHT = (244, 232, 196)
TEXT_HOVER = (255, 232, 132)
GLOW_HOVER = (255, 168, 60)

# Clan accent colors (used in title flourish + button hover hues)
CLAN_COLORS = [
    (235,  80, 175),   # SHADOW magenta
    ( 80, 210, 230),   # STORM cyan
    (140, 220, 100),   # FROST green
    (255, 145,  50),   # FIRE orange
]


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ============================================================
#  Noise helpers (used by stone surface)
# ============================================================
def _hash(ix, iy, seed):
    h = math.sin(ix * 127.1 + iy * 311.7 + seed * 71.3) * 43758.5453
    return h - math.floor(h)


def _smoothstep(t):
    return t * t * (3 - 2 * t)


def value_noise(x, y, seed=0):
    x0 = math.floor(x); y0 = math.floor(y)
    x1 = x0 + 1; y1 = y0 + 1
    fx = x - x0; fy = y - y0
    sx = _smoothstep(fx); sy = _smoothstep(fy)
    v00 = _hash(x0, y0, seed); v10 = _hash(x1, y0, seed)
    v01 = _hash(x0, y1, seed); v11 = _hash(x1, y1, seed)
    return (v00 * (1 - sx) + v10 * sx) * (1 - sy) + \
           (v01 * (1 - sx) + v11 * sx) * sy


def fractal_noise(x, y, octaves=3, seed=0, lacunarity=2.0, persistence=0.5):
    total = 0.0; amp = 1.0; freq = 1.0; norm = 0.0
    for _ in range(octaves):
        total += value_noise(x * freq, y * freq, seed) * amp
        norm += amp
        amp *= persistence
        freq *= lacunarity
    return total / norm


def text_mask(text, font_path, font_size, padding=8):
    font = ImageFont.truetype(font_path, font_size)
    bbox = font.getbbox(text)
    w = bbox[2] - bbox[0] + padding * 2
    h = bbox[3] - bbox[1] + padding * 2
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    d.text((padding - bbox[0], padding - bbox[1]),
           text, font=font, fill=255)
    return img.point(lambda v: 255 if v > 110 else 0)


def dilate(mask, px):
    if px <= 0: return mask
    return mask.filter(ImageFilter.MaxFilter(px * 2 + 1))


def save_native_and_4x(img, basename, also_8x=False):
    img.save(f'{OUT_DIR}/{basename}_native.png')
    w, h = img.size
    img.resize((w * 4, h * 4),
               Image.NEAREST).save(f'{OUT_DIR}/{basename}_4x.png')
    if also_8x:
        img.resize((w * 8, h * 8),
                   Image.NEAREST).save(f'{OUT_DIR}/{basename}_8x.png')


# ============================================================
#  BACKGROUND — Layer 1: SKY (solid, opaque)
# ============================================================
BG_W, BG_H = 480, 270


def make_bg_sky(seed=42):
    """Deep night sky with full moon + scattered stars + cloud wisps.
       SOLID background (no transparency)."""
    rnd = random.Random(seed)
    img = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    px = img.load()

    # Vertical gradient: top very dark → horizon warmer purple
    for y in range(BG_H):
        t = y / (BG_H - 1)
        if t < 0.55:
            tt = t / 0.55
            r = int(SKY_TOP[0] + (SKY_MID[0] - SKY_TOP[0]) * tt)
            g = int(SKY_TOP[1] + (SKY_MID[1] - SKY_TOP[1]) * tt)
            b = int(SKY_TOP[2] + (SKY_MID[2] - SKY_TOP[2]) * tt)
        else:
            tt = (t - 0.55) / 0.45
            r = int(SKY_MID[0] + (SKY_HORIZON[0] - SKY_MID[0]) * tt)
            g = int(SKY_MID[1] + (SKY_HORIZON[1] - SKY_MID[1]) * tt)
            b = int(SKY_MID[2] + (SKY_HORIZON[2] - SKY_MID[2]) * tt)
        for x in range(BG_W):
            # Slight horizontal vignette (warmer toward edges)
            edge = abs(x - BG_W / 2) / (BG_W / 2)
            warm = int(edge * 4)
            px[x, y] = (max(0, r - warm), g, b, 255)

    # Star field — denser at top, sparser near horizon
    for _ in range(140):
        x = rnd.randint(0, BG_W - 1)
        y = rnd.randint(0, int(BG_H * 0.7))
        if rnd.random() < (1 - y / BG_H):
            bright = rnd.random()
            if bright > 0.85:
                col = STAR_BRIGHT
                px[x, y] = (col[0], col[1], col[2], 255)
                # tiny twinkle cross
                if 0 < x < BG_W - 1:
                    cr, cg, cb = STAR_DIM
                    px[x - 1, y] = (cr, cg, cb, 220)
                    px[x + 1, y] = (cr, cg, cb, 220)
                if 0 < y < BG_H - 1:
                    cr, cg, cb = STAR_DIM
                    px[x, y - 1] = (cr, cg, cb, 220)
                    px[x, y + 1] = (cr, cg, cb, 220)
            elif bright > 0.55:
                col = STAR_DIM
                px[x, y] = (col[0], col[1], col[2], 255)
            else:
                col = STAR_DIM
                px[x, y] = (col[0], col[1], col[2], 150)

    # FULL MOON — top-right area
    moon_cx, moon_cy = int(BG_W * 0.76), int(BG_H * 0.28)
    moon_r = 22
    # Outer glow halo (additive feel via blur)
    halo = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    hd = ImageDraw.Draw(halo)
    for r, a in [(moon_r + 14, 32), (moon_r + 8, 56), (moon_r + 4, 80)]:
        hd.ellipse([moon_cx - r, moon_cy - r,
                    moon_cx + r, moon_cy + r],
                   fill=(MOON_GLOW[0], MOON_GLOW[1], MOON_GLOW[2], a))
    halo = halo.filter(ImageFilter.GaussianBlur(radius=4))
    img.alpha_composite(halo)

    # Solid moon disk with subtle gradient
    md = ImageDraw.Draw(img)
    md.ellipse([moon_cx - moon_r, moon_cy - moon_r,
                moon_cx + moon_r, moon_cy + moon_r],
               fill=rgba(MOON_CORE))
    md.ellipse([moon_cx - moon_r, moon_cy - moon_r,
                moon_cx + moon_r - 1, moon_cy + moon_r - 1],
               outline=rgba(MOON_RIM))
    # craters
    for _ in range(7):
        cr = rnd.randint(1, 3)
        cx = moon_cx + rnd.randint(-moon_r + 4, moon_r - 4)
        cy = moon_cy + rnd.randint(-moon_r + 4, moon_r - 4)
        if (cx - moon_cx) ** 2 + (cy - moon_cy) ** 2 < (moon_r - 4) ** 2:
            md.ellipse([cx - cr, cy - cr, cx + cr, cy + cr],
                       fill=rgba(MOON_RIM))

    # Cloud wisps (low alpha, soft pinkish-violet)
    for _ in range(5):
        cy = rnd.randint(int(BG_H * 0.15), int(BG_H * 0.5))
        cw = rnd.randint(60, 120)
        cx = rnd.randint(-20, BG_W - 40)
        cloud = Image.new('RGBA', (cw, 18), TRANSPARENT)
        cd = ImageDraw.Draw(cloud)
        for i in range(8):
            ex = i * (cw // 8) + rnd.randint(-4, 4)
            ey = 9 + rnd.randint(-3, 3)
            er = rnd.randint(6, 11)
            cd.ellipse([ex - er, ey - er // 2, ex + er, ey + er // 2],
                       fill=(MTN_FOG[0], MTN_FOG[1], MTN_FOG[2], 80))
        cloud = cloud.filter(ImageFilter.GaussianBlur(radius=2))
        img.alpha_composite(cloud, (cx, cy))

    # A tiny bird silhouette near the moon (flavor)
    bd = ImageDraw.Draw(img)
    bird_x, bird_y = moon_cx - 50, moon_cy + 18
    bd.line([(bird_x, bird_y), (bird_x + 3, bird_y - 2),
             (bird_x + 6, bird_y)], fill=rgba(MTN_NEAR), width=1)
    bd.line([(bird_x + 6, bird_y), (bird_x + 9, bird_y - 2),
             (bird_x + 12, bird_y)], fill=rgba(MTN_NEAR), width=1)

    return img


# ============================================================
#  BACKGROUND — Layer 2: MOUNTAINS (transparent above ridges)
# ============================================================
def make_bg_mountains(seed=7):
    rnd = random.Random(seed)
    img = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    px = img.load()

    def ridge(amplitude, base_y, color, color_hi, octaves, seed_off,
              fog_amount=0.0):
        # Generate the ridge as a noise-driven heightmap
        for x in range(BG_W):
            n = fractal_noise(x / 60, seed_off, octaves=octaves,
                              seed=seed_off)
            h_off = int((n - 0.5) * amplitude)
            y_top = base_y + h_off
            for y in range(y_top, BG_H):
                r, g, b = color
                if y == y_top:
                    r, g, b = color_hi
                if fog_amount > 0:
                    # blend toward fog color near the top
                    blend = max(0.0, 1.0 - (y - y_top) / 30)
                    blend *= fog_amount
                    r = int(r + (MTN_FOG[0] - r) * blend)
                    g = int(g + (MTN_FOG[1] - g) * blend)
                    b = int(b + (MTN_FOG[2] - b) * blend)
                # Light noise overlay
                jx = (fractal_noise(x / 12, y / 12,
                                    octaves=2, seed=seed_off + 9) - 0.5) * 12
                r = max(0, min(255, int(r + jx)))
                g = max(0, min(255, int(g + jx * 0.7)))
                b = max(0, min(255, int(b + jx * 0.4)))
                px[x, y] = (r, g, b, 255)

    # Three ridges from far to near
    ridge(amplitude=40, base_y=int(BG_H * 0.55),
          color=MTN_FAR, color_hi=MTN_FAR_HI,
          octaves=3, seed_off=11, fog_amount=0.55)
    ridge(amplitude=55, base_y=int(BG_H * 0.65),
          color=MTN_MID, color_hi=MTN_MID_HI,
          octaves=3, seed_off=23, fog_amount=0.30)
    ridge(amplitude=35, base_y=int(BG_H * 0.78),
          color=MTN_NEAR, color_hi=MTN_NEAR,
          octaves=2, seed_off=37, fog_amount=0.10)

    # Add fog bands sweeping across mid ridges
    fog = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    fd = ImageDraw.Draw(fog)
    for i in range(4):
        fy = int(BG_H * 0.55) + i * 8 + rnd.randint(-3, 3)
        fd.rectangle([0, fy, BG_W, fy + 2],
                     fill=(MTN_FOG[0], MTN_FOG[1], MTN_FOG[2], 50))
    fog = fog.filter(ImageFilter.GaussianBlur(radius=3))
    img.alpha_composite(fog)

    return img


# ============================================================
#  BACKGROUND — Layer 3: PAGODA (silhouette + glowing windows)
# ============================================================
def make_bg_pagoda(seed=99):
    rnd = random.Random(seed)
    img = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    d = ImageDraw.Draw(img)

    # Center the pagoda roughly under the moon area, slightly left
    cx = BG_W // 2 - 6
    base_y = int(BG_H * 0.82)  # ground level for pagoda

    # 4-tier pagoda — each tier narrower as we go up.
    # Each tier = body (square) + curved roof (wider, with upturned eaves).
    # We render bottom-up to handle layering.
    tiers = [
        # (body_half_w, body_h, roof_extra_w, roof_h)
        (38, 22, 12, 8),  # tier 1 (bottom)
        (32, 18, 11, 7),  # tier 2
        (24, 16, 10, 6),  # tier 3
        (16, 14,  9, 6),  # tier 4 (top)
    ]
    y = base_y
    for i, (bw, bh, rw, rh) in enumerate(tiers):
        # Body
        d.rectangle([cx - bw, y - bh, cx + bw, y],
                    fill=rgba(PAGODA_MID))
        # Floor base line (darker)
        d.line([(cx - bw, y), (cx + bw, y)],
               fill=rgba(PAGODA_DARK), width=1)
        # Wooden support pillars (vertical lines)
        n_pillars = 4 if bw > 26 else 3
        for p in range(n_pillars):
            px_ = cx - bw + (2 * bw) * (p + 1) // (n_pillars + 1)
            d.line([(px_, y - bh + 1), (px_, y - 1)],
                   fill=rgba(PAGODA_DARK), width=1)
        # Glowing windows between pillars
        for p in range(n_pillars + 1):
            wx0 = cx - bw + (2 * bw) * p // (n_pillars + 1) + 2
            wx1 = cx - bw + (2 * bw) * (p + 1) // (n_pillars + 1) - 2
            wy0 = y - bh + 3
            wy1 = y - 3
            if wx1 - wx0 < 2 or wy1 - wy0 < 2:
                continue
            if rnd.random() < 0.7:
                d.rectangle([wx0, wy0, wx1, wy1],
                            fill=rgba(PAGODA_WIN))
                # bright center
                ccx = (wx0 + wx1) // 2; ccy = (wy0 + wy1) // 2
                d.point((ccx, ccy), fill=rgba(PAGODA_WIN_HOT))

        # Roof — wider, curves upward at ends
        ry_top = y - bh - rh
        # Main eave
        d.polygon([
            (cx - bw - rw, y - bh + 1),
            (cx - bw - rw + 4, ry_top),
            (cx + bw + rw - 4, ry_top),
            (cx + bw + rw, y - bh + 1),
        ], fill=rgba(PAGODA_ROOF))
        # Upturned eave tips (the iconic curl)
        d.line([(cx - bw - rw, y - bh + 1),
                (cx - bw - rw - 2, y - bh - 1)],
               fill=rgba(PAGODA_ROOF), width=1)
        d.line([(cx + bw + rw, y - bh + 1),
                (cx + bw + rw + 2, y - bh - 1)],
               fill=rgba(PAGODA_ROOF), width=1)
        # Roof ridge highlight (lighter top)
        d.line([(cx - bw - rw + 4, ry_top),
                (cx + bw + rw - 4, ry_top)],
               fill=rgba(PAGODA_ROOF_HI), width=1)
        # tiny rail beneath roof
        d.line([(cx - bw - 2, y - bh - 1),
                (cx + bw + 2, y - bh - 1)],
               fill=rgba(PAGODA_RAIL), width=1)

        # Next tier sits on top of this roof
        y = ry_top + 1

    # Crowning spire on top tier
    spire_x = cx
    spire_top = y - 10
    d.line([(spire_x, y - 1), (spire_x, spire_top)],
           fill=rgba(PAGODA_RAIL), width=1)
    # 3 stacked rings (sorin)
    for ring_i, ring_y in enumerate([spire_top + 1, spire_top + 4,
                                     spire_top + 7]):
        rw = 3 - ring_i // 2
        d.ellipse([spire_x - rw, ring_y - 1,
                   spire_x + rw, ring_y + 1],
                  fill=rgba(PAGODA_ROOF_HI))
    # Tiny moon-disc finial
    d.ellipse([spire_x - 1, spire_top - 2,
               spire_x + 1, spire_top],
              fill=rgba(MOON_RIM))

    # Subtle warm glow around windows
    glow = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    gd = ImageDraw.Draw(glow)
    gd.rectangle([cx - 50, base_y - 90,
                  cx + 50, base_y - 10],
                 fill=(PAGODA_WIN[0], PAGODA_WIN[1], PAGODA_WIN[2], 18))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=8))
    img.alpha_composite(glow)

    return img


# ============================================================
#  BACKGROUND — Layer 4: FOREGROUND (sakura, lantern, bamboo)
# ============================================================
def draw_sakura_branch(d, x0, y0, length, angle, depth, rnd):
    """Recursive sakura branch with petals at tips."""
    if depth <= 0 or length < 3:
        # Petal cluster
        for _ in range(rnd.randint(3, 6)):
            ox = x0 + rnd.randint(-3, 3)
            oy = y0 + rnd.randint(-3, 3)
            col = SAKURA_PETAL if rnd.random() < 0.6 else SAKURA_PETAL_D
            d.point((ox, oy), fill=rgba(col))
            if rnd.random() < 0.4:
                d.point((ox + 1, oy), fill=rgba(col))
                d.point((ox, oy + 1), fill=rgba(col))
        # A few bright buds
        for _ in range(rnd.randint(0, 2)):
            ox = x0 + rnd.randint(-2, 2)
            oy = y0 + rnd.randint(-2, 2)
            d.point((ox, oy), fill=rgba(SAKURA_BUD))
        return

    x1 = x0 + math.cos(angle) * length
    y1 = y0 + math.sin(angle) * length
    # Draw the branch as a thick line
    steps = int(length)
    for i in range(steps + 1):
        t = i / max(1, steps)
        bx = int(x0 + (x1 - x0) * t)
        by = int(y0 + (y1 - y0) * t)
        d.point((bx, by), fill=rgba(SAKURA_TRUNK))
        if i == 0 and rnd.random() < 0.4:
            d.point((bx + 1, by), fill=rgba(SAKURA_BARK_HI))

    # Children: 1-2 sub branches near tip
    n_children = rnd.choice([1, 2, 2])
    for _ in range(n_children):
        new_angle = angle + rnd.uniform(-0.9, 0.9)
        new_len = length * rnd.uniform(0.55, 0.8)
        draw_sakura_branch(d, x1, y1, new_len, new_angle, depth - 1, rnd)


def make_bg_foreground(seed=2025):
    rnd = random.Random(seed)
    img = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    d = ImageDraw.Draw(img)

    # ---- Top-left: sakura branch sweeping down-right ----
    draw_sakura_branch(d, x0=-6, y0=20, length=22,
                       angle=math.radians(35), depth=3, rnd=rnd)
    # Second smaller branch top-left
    draw_sakura_branch(d, x0=4, y0=-4, length=18,
                       angle=math.radians(55), depth=3,
                       rnd=random.Random(seed + 1))

    # ---- Top-right: sakura branch sweeping down-left ----
    draw_sakura_branch(d, x0=BG_W + 6, y0=12, length=24,
                       angle=math.radians(180 - 30), depth=3,
                       rnd=random.Random(seed + 2))
    draw_sakura_branch(d, x0=BG_W - 4, y0=-2, length=16,
                       angle=math.radians(180 - 55), depth=3,
                       rnd=random.Random(seed + 3))

    # ---- Bottom-left: stone lantern (ishi-doro) ----
    lx = 32
    ly = BG_H - 36
    # base (stone)
    d.rectangle([lx - 7, ly + 22, lx + 7, ly + 28], fill=rgba(PAGODA_DARK))
    d.rectangle([lx - 6, ly + 22, lx + 6, ly + 24], fill=rgba(PAGODA_HI))
    # pillar
    d.rectangle([lx - 2, ly + 8, lx + 2, ly + 22], fill=rgba(PAGODA_DARK))
    d.line([(lx - 2, ly + 8), (lx - 2, ly + 22)], fill=rgba(PAGODA_HI))
    # lantern body (square chamber)
    d.rectangle([lx - 6, ly, lx + 6, ly + 8],
                fill=rgba(LANTERN_BODY))
    d.rectangle([lx - 6, ly, lx + 6, ly], fill=rgba(LANTERN_RIM))
    d.rectangle([lx - 6, ly + 8, lx + 6, ly + 8], fill=rgba(LANTERN_RIM))
    # window cutout — warm glow
    d.rectangle([lx - 3, ly + 2, lx + 3, ly + 6],
                fill=rgba(LANTERN_GLOW))
    d.point((lx, ly + 4), fill=rgba(LANTERN_HOT))
    # roof (curved)
    d.polygon([(lx - 9, ly),
               (lx - 6, ly - 4),
               (lx + 6, ly - 4),
               (lx + 9, ly)],
              fill=rgba(PAGODA_DARK))
    d.line([(lx - 9, ly), (lx - 7, ly - 2)],
           fill=rgba(PAGODA_HI), width=1)
    d.line([(lx + 9, ly), (lx + 7, ly - 2)],
           fill=rgba(PAGODA_HI), width=1)
    # finial
    d.point((lx, ly - 5), fill=rgba(PAGODA_HI))

    # Glow halo around lantern
    halo = Image.new('RGBA', (BG_W, BG_H), TRANSPARENT)
    hd = ImageDraw.Draw(halo)
    hd.ellipse([lx - 22, ly - 10, lx + 22, ly + 22],
               fill=(LANTERN_GLOW[0], LANTERN_GLOW[1],
                     LANTERN_GLOW[2], 40))
    halo = halo.filter(ImageFilter.GaussianBlur(radius=6))
    img.alpha_composite(halo)
    # re-paste lantern body on top (so halo doesn't wash it out)
    pass

    # ---- Bottom-right: bamboo cluster ----
    def bamboo_culm(d_, base_x, base_y, h, w=3, lean=0.0):
        for y in range(h):
            yy = base_y - y
            xx = base_x + int(lean * (y / max(1, h)))
            # solid body
            for dx in range(-w, w + 1):
                col = BAMBOO_MID
                if dx == -w:
                    col = BAMBOO_DARK
                elif dx == w:
                    col = BAMBOO_DARK
                elif dx == -w + 1 or dx == 0:
                    col = BAMBOO_HI if dx == -w + 1 else BAMBOO_MID
                d_.point((xx + dx, yy), fill=rgba(col))
            # nodes every ~8 px
            if y % 9 == 4:
                for dx in range(-w, w + 1):
                    d_.point((xx + dx, yy), fill=rgba(BAMBOO_NODE))
        # a leaf or two at top
        for _ in range(rnd.randint(2, 4)):
            lx0 = base_x + rnd.randint(-w, w)
            ly0 = base_y - h - rnd.randint(0, 6)
            for i in range(rnd.randint(3, 6)):
                d_.point((lx0 + i, ly0 - i // 2),
                         fill=rgba(BAMBOO_MID if i % 2 == 0 else BAMBOO_HI))

    bamboo_culm(d, BG_W - 18, BG_H - 4, 60, w=2, lean=-0.05)
    bamboo_culm(d, BG_W - 28, BG_H - 4, 70, w=2, lean=0.1)
    bamboo_culm(d, BG_W - 10, BG_H - 4, 50, w=2, lean=-0.1)

    return img


# ============================================================
#  STONE TEXT RENDERER (reused from player_wins)
# ============================================================
def render_drop_shadow(mask):
    w, h = mask.size
    far_mask = dilate(mask, 4)
    far_img = Image.new('RGBA', (w, h), TRANSPARENT)
    fp = far_img.load(); fm = far_mask.load()
    for y in range(h):
        for x in range(w):
            if fm[x, y] > 128:
                fp[x, y] = (SHADOW_FAR[0], SHADOW_FAR[1],
                            SHADOW_FAR[2], 80)
    far_img = far_img.filter(ImageFilter.GaussianBlur(radius=3.5))

    near_mask = dilate(mask, 2)
    near_img = Image.new('RGBA', (w, h), TRANSPARENT)
    np_px = near_img.load(); nm = near_mask.load()
    for y in range(h):
        for x in range(w):
            if nm[x, y] > 128:
                np_px[x, y] = (SHADOW_NEAR[0], SHADOW_NEAR[1],
                               SHADOW_NEAR[2], 145)
    near_img = near_img.filter(ImageFilter.GaussianBlur(radius=1.5))
    return far_img, near_img


def render_stone_surface(mask, seed=0, light_dir=(-1, -1)):
    w, h = mask.size
    img = Image.new('RGBA', (w, h), TRANSPARENT)
    px = img.load(); mp = mask.load()

    lx, ly = light_dir
    n = math.sqrt(lx * lx + ly * ly); lx /= n; ly /= n
    proj_min = lx * 0 + ly * 0
    proj_max = lx * w + ly * h
    if proj_max < proj_min:
        proj_min, proj_max = proj_max, proj_min

    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128:
                continue
            n_macro = fractal_noise(x / 22, y / 22, octaves=2, seed=seed)
            n_micro = fractal_noise(x / 5,  y / 5,
                                    octaves=2, seed=seed + 50) - 0.5
            proj = (lx * x + ly * y)
            light_t = 1.0 - (proj - proj_min) / (proj_max - proj_min)
            v = light_t * 0.65 + n_macro * 0.30 + n_micro * 0.18
            v = max(0.0, min(1.0, v))
            color = STONE_TONES[int(v * (len(STONE_TONES) - 1))]
            warm = n_micro * 8
            r = max(0, min(255, color[0] + int(warm)))
            g = max(0, min(255, color[1] + int(warm * 0.5)))
            b = max(0, min(255, color[2] - int(warm * 0.5)))
            px[x, y] = (r, g, b, 255)
    return img


def add_chiseled_rim(surface, mask):
    w, h = mask.size
    sp = surface.load(); mp = mask.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128: continue
            top_empty = (y == 0 or mp[x, y - 1] <= 128)
            left_empty = (x == 0 or mp[x - 1, y] <= 128)
            if top_empty:
                sp[x, y] = rgba(RIM_HI)
                if y + 1 < h and mp[x, y + 1] > 128:
                    sp[x, y + 1] = rgba(RIM_MID)
            elif left_empty:
                sp[x, y] = rgba(RIM_MID)


def add_pits(surface, mask, seed=0, pit_count=10):
    w, h = mask.size
    sp = surface.load(); mp = mask.load()
    rnd = random.Random(seed + 333)
    placed = 0; attempts = 0
    while placed < pit_count and attempts < 200:
        attempts += 1
        x = rnd.randint(2, w - 3); y = rnd.randint(2, h - 3)
        if mp[x, y] > 128 and mp[x, y - 1] > 128:
            sp[x, y] = rgba(PIT_DK)
            if rnd.random() < 0.6 and mp[x + 1, y] > 128:
                sp[x + 1, y] = rgba(PIT_MID)
            placed += 1


def add_cracks(surface, mask, seed=0, count=2):
    w, h = mask.size
    sp = surface.load(); mp = mask.load()
    rnd = random.Random(seed + 555)
    placed = 0; tries = 0
    while placed < count and tries < 50:
        tries += 1
        x0 = rnd.randint(4, w - 5); y0 = rnd.randint(4, h - 5)
        if mp[x0, y0] <= 128: continue
        ang = rnd.uniform(0, math.tau)
        cx, cy = float(x0), float(y0)
        for _ in range(rnd.randint(10, 16)):
            cx += math.cos(ang) * 1.4
            cy += math.sin(ang) * 1.4
            ang += rnd.uniform(-0.4, 0.4)
            ix, iy = int(cx), int(cy)
            if not (0 <= ix < w and 0 <= iy < h): break
            if mp[ix, iy] <= 128: break
            sp[ix, iy] = rgba(CRACK_DEEP)
        placed += 1


def add_moss(surface, mask, seed=0):
    w, h = mask.size
    sp = surface.load(); mp = mask.load()
    rnd = random.Random(seed + 666)
    top_edges = []
    for y in range(h):
        for x in range(w):
            if mp[x, y] > 128 and (y == 0 or mp[x, y - 1] <= 128):
                top_edges.append((x, y))
    rnd.shuffle(top_edges)
    used = []
    for (x, y) in top_edges:
        ok = True
        for (sx, sy) in used:
            if abs(x - sx) < 10 and abs(y - sy) < 6:
                ok = False; break
        if ok: used.append((x, y))
    used = [s for s in used if rnd.random() < 0.7]
    for (cx, cy) in used:
        sz = rnd.randint(3, 6)
        pts = set()
        for _ in range(sz * 3):
            ox = cx + rnd.randint(-sz, sz)
            oy = cy + rnd.randint(0, 2)
            if 0 <= ox < w and 0 <= oy < h and mp[ox, oy] > 128:
                pts.add((ox, oy))
        for (p, q) in pts: sp[p, q] = rgba(MOSS_DARK)
        for (p, q) in pts:
            if rnd.random() < 0.7: sp[p, q] = rgba(MOSS_MID)
            if rnd.random() < 0.4: sp[p, q] = rgba(MOSS_BRIGHT)
        top = [pp for pp in pts if (pp[0], pp[1] - 1) not in pts]
        for (p, q) in top:
            if rnd.random() < 0.55:
                sp[p, q] = rgba(MOSS_TIP)
        if pts and rnd.random() < 0.35:
            (lx, ly) = rnd.choice(list(pts))
            sp[lx, ly] = rgba(LICHEN_ORG if rnd.random() < 0.5
                              else LICHEN_WHITE)


def render_stone_text(text, font_path, font_size, seed):
    raw = text_mask(text, font_path, font_size, padding=12)
    mw, mh = raw.size
    cw, ch = mw + 12, mh + 12
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    sx, sy = 6, 6
    far_s, near_s = render_drop_shadow(raw)
    canvas.alpha_composite(far_s, (sx + 6, sy + 9))
    canvas.alpha_composite(near_s, (sx + 3, sy + 4))

    om = dilate(raw, 1)
    ol_img = Image.new('RGBA', (mw, mh), TRANSPARENT)
    op = ol_img.load(); omp = om.load()
    for y in range(mh):
        for x in range(mw):
            if omp[x, y] > 128:
                op[x, y] = rgba(OUTLINE_COL)
    canvas.alpha_composite(ol_img, (sx, sy))

    surf = render_stone_surface(raw, seed=seed)
    add_chiseled_rim(surf, raw)
    add_pits(surf, raw, seed=seed, pit_count=14)
    add_cracks(surf, raw, seed=seed, count=3)
    add_moss(surf, raw, seed=seed)
    canvas.alpha_composite(surf, (sx, sy))
    return canvas


# ============================================================
#  TITLE: "FOUR CLANS" + subtitle + crossed katanas
# ============================================================
def make_title_main():
    return render_stone_text('FOUR CLANS', FONT_BLACK, 60, seed=7777)


def make_title_subtitle():
    """Bamboo plank with 'shinobi arena' text."""
    text = 'shinobi arena'
    font = ImageFont.truetype(FONT_BOLD, 18)
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pad_x = 16
    pad_y = 6
    plank_w = tw + pad_x * 2
    plank_h = th + pad_y * 2 + 4

    canvas = Image.new('RGBA', (plank_w + 12, plank_h + 12), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    ox, oy = 6, 6

    # Drop shadow plank
    shadow = Image.new('RGBA', canvas.size, TRANSPARENT)
    sd = ImageDraw.Draw(shadow)
    sd.rectangle([ox + 3, oy + 4,
                  ox + plank_w + 3, oy + plank_h + 4],
                 fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=2))
    canvas.alpha_composite(shadow)

    # Bamboo plank body — green tinted wood with horizontal grain
    for y in range(plank_h):
        for x in range(plank_w):
            t = y / plank_h
            base = (
                int(BAMBOO_DARK[0] + (BAMBOO_MID[0] - BAMBOO_DARK[0]) * (1 - abs(t - 0.5) * 2)),
                int(BAMBOO_DARK[1] + (BAMBOO_MID[1] - BAMBOO_DARK[1]) * (1 - abs(t - 0.5) * 2)),
                int(BAMBOO_DARK[2] + (BAMBOO_MID[2] - BAMBOO_DARK[2]) * (1 - abs(t - 0.5) * 2)),
            )
            # add grain noise
            n = (math.sin(x * 0.7 + y * 1.7) * 0.5 + 0.5) * 14 - 7
            r = max(0, min(255, int(base[0] + n)))
            g = max(0, min(255, int(base[1] + n)))
            b = max(0, min(255, int(base[2] + n)))
            d.point((ox + x, oy + y), fill=(r, g, b, 255))

    # Border
    d.rectangle([ox, oy, ox + plank_w - 1, oy + plank_h - 1],
                outline=rgba(BAMBOO_NODE), width=1)
    # Only TWO bamboo node bands — one on the left and one on the right,
    # framing the plank like rope binding (not slicing it into segments).
    for nx in (3, plank_w - 5):
        for dy in range(plank_h):
            r = max(0, BAMBOO_DARK[0] - 6)
            g = max(0, BAMBOO_DARK[1] - 6)
            b = max(0, BAMBOO_DARK[2] - 6)
            d.point((ox + nx, oy + dy),
                    fill=(r, g, b, 180))
        # thin highlight stroke to the right of each band
        for dy in range(plank_h):
            d.point((ox + nx + 1, oy + dy),
                    fill=(BAMBOO_HI[0], BAMBOO_HI[1],
                          BAMBOO_HI[2], 80))

    # Tiny rope wraps at left and right (mimics button style)
    for rx in (ox - 2, ox + plank_w - 3):
        for ry in range(plank_h):
            stripe = ((ry) // 2) % 2
            col = ROPE_COL if stripe == 0 else ROPE_DK
            for off in range(3):
                px_ = rx + off
                d.point((px_, oy + ry), fill=rgba(col))
        d.line([(rx, oy), (rx + 2, oy)], fill=rgba(WOOD_EDGE))
        d.line([(rx, oy + plank_h - 1),
                (rx + 2, oy + plank_h - 1)],
               fill=rgba(WOOD_EDGE))

    # Text with subtle 1px shadow for legibility
    text_x = ox + pad_x
    text_y = oy + pad_y - bbox[1]
    d.text((text_x + 1, text_y + 1), text, font=font, fill=(0, 0, 0, 180))
    d.text((text_x, text_y), text, font=font, fill=rgba(TEXT_LIGHT))
    return canvas


def make_title_katanas():
    """Two crossed katanas — wide ornament that extends behind the FOUR
       CLANS title. Native ~440x90 → 4x = 1760x360 (covers full title)."""
    W, H = 440, 90
    img = Image.new('RGBA', (W, H), TRANSPARENT)
    d = ImageDraw.Draw(img)

    def katana(angle_deg):
        cx, cy = W // 2, H // 2
        a = math.radians(angle_deg)
        blade_len = 220
        handle_len = 38
        guard_size = 5
        # blade
        for t in range(-blade_len // 2, blade_len // 2):
            for off in range(-3, 4):
                bx = cx + int(math.cos(a) * t - math.sin(a) * off)
                by = cy + int(math.sin(a) * t + math.cos(a) * off)
                if not (0 <= bx < W and 0 <= by < H): continue
                # subtle edge-to-spine shading
                if off == -3:
                    col = (38, 36, 48, 230)        # dark spine
                elif off == -2:
                    col = (70, 68, 88, 245)
                elif off == -1:
                    col = (130, 128, 160, 255)
                elif off == 0:
                    col = (175, 175, 205, 255)     # body
                elif off == 1:
                    col = (215, 215, 240, 255)     # bright edge
                elif off == 2:
                    col = (240, 240, 252, 255)     # razor edge highlight
                else:
                    col = (180, 180, 210, 230)
                d.point((bx, by), fill=col)
            # hamon (temper line) wavy near edge — every few px
            if t % 7 == 0:
                wx = cx + int(math.cos(a) * t - math.sin(a) * 1)
                wy = cy + int(math.sin(a) * t + math.cos(a) * 1)
                if 0 <= wx < W and 0 <= wy < H:
                    d.point((wx, wy), fill=(200, 215, 235, 255))

        # tip taper — fade the last few pixels darker
        tip_t = blade_len // 2 - 1
        tx = cx + int(math.cos(a) * tip_t)
        ty = cy + int(math.sin(a) * tip_t)
        d.point((tx, ty), fill=(90, 90, 120, 255))

        # tsuba (guard) — disc at handle/blade junction
        ht = -blade_len // 2 - 1
        gx = cx + int(math.cos(a) * ht)
        gy = cy + int(math.sin(a) * ht)
        for dx in range(-guard_size, guard_size + 1):
            for dy in range(-guard_size, guard_size + 1):
                if dx * dx + dy * dy <= guard_size * guard_size:
                    px_, py_ = gx + dx, gy + dy
                    if 0 <= px_ < W and 0 <= py_ < H:
                        if dx * dx + dy * dy >= (guard_size - 1) ** 2:
                            d.point((px_, py_), fill=(72, 48, 18, 255))
                        else:
                            d.point((px_, py_), fill=(160, 110, 38, 255))
        # tsuba highlight
        d.point((gx - 1, gy - 1), fill=(220, 168, 60, 255))

        # handle (tsuka) — wraps in alternating dark/bright diamonds
        for t in range(-blade_len // 2 - handle_len,
                       -blade_len // 2 - guard_size):
            for off in range(-3, 4):
                hx = cx + int(math.cos(a) * t - math.sin(a) * off)
                hy = cy + int(math.sin(a) * t + math.cos(a) * off)
                if not (0 <= hx < W and 0 <= hy < H): continue
                # base dark wrap
                if abs(off) == 3:
                    col = (16, 12, 18, 255)
                else:
                    col = (32, 22, 28, 255)
                d.point((hx, hy), fill=col)
        # diamond wrap pattern in red/black
        for ti, t in enumerate(range(-blade_len // 2 - handle_len + 2,
                                     -blade_len // 2 - guard_size)):
            phase = ti // 4
            if phase % 2 == 0:
                col = (190, 50, 42, 255)
            else:
                col = (40, 24, 28, 255)
            for off in (-1, 0, 1):
                wx = cx + int(math.cos(a) * t - math.sin(a) * off)
                wy = cy + int(math.sin(a) * t + math.cos(a) * off)
                if 0 <= wx < W and 0 <= wy < H:
                    d.point((wx, wy), fill=col)
        # pommel cap (kashira) — small darker block at very end
        for t in range(-blade_len // 2 - handle_len - 3,
                       -blade_len // 2 - handle_len + 1):
            for off in range(-3, 4):
                hx = cx + int(math.cos(a) * t - math.sin(a) * off)
                hy = cy + int(math.sin(a) * t + math.cos(a) * off)
                if 0 <= hx < W and 0 <= hy < H:
                    d.point((hx, hy), fill=(72, 48, 18, 255))

    # Cross at a shallow angle so they sweep wide behind the title
    katana(-10)
    katana(10)
    return img


# ============================================================
#  BUTTONS — wooden plank with rope wrap, 3 states
# ============================================================
def render_button(label, state='normal', accent_color=None):
    """state: 'normal' | 'hover' | 'pressed'.
       accent_color: optional (r,g,b) for hover glow."""
    font = ImageFont.truetype(FONT_BLACK, 22)
    bbox = font.getbbox(label)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    pad_x = 22
    pad_y = 8
    plank_w = max(160, text_w + pad_x * 2)
    plank_h = text_h + pad_y * 2 + 4
    margin = 14
    cw = plank_w + margin * 2
    ch = plank_h + margin * 2

    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # Vertical offset for pressed
    plank_y_off = 3 if state == 'pressed' else 0

    # Outer glow (hover only)
    if state == 'hover' and accent_color is not None:
        glow = Image.new('RGBA', (cw, ch), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        for grow in [6, 4, 2]:
            gd.rounded_rectangle(
                [margin - grow, margin - grow,
                 margin + plank_w + grow,
                 margin + plank_h + grow],
                radius=6 + grow,
                fill=(accent_color[0], accent_color[1],
                      accent_color[2], 38 if grow == 6 else
                                       55 if grow == 4 else 70))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=3))
        canvas.alpha_composite(glow)

    # Drop shadow (less when pressed since the plank "sits" closer)
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    shadow_off = 2 if state == 'pressed' else 5
    shadow_alpha = 80 if state == 'pressed' else 130
    sd.rounded_rectangle(
        [margin + 2, margin + shadow_off,
         margin + plank_w + 4, margin + plank_h + shadow_off + 1],
        radius=5,
        fill=(0, 0, 0, shadow_alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=2.5))
    canvas.alpha_composite(sh)

    # Plank body
    px0 = margin
    py0 = margin + plank_y_off
    px1 = margin + plank_w
    py1 = margin + plank_h + plank_y_off

    # Color tint based on state
    if state == 'pressed':
        c_dk = WOOD_EDGE
        c_md = (WOOD_DK[0] + 10, WOOD_DK[1] + 6, WOOD_DK[2] + 4)
        c_hi = WOOD_MD
        c_grain = WOOD_GRAIN_DK
    elif state == 'hover':
        c_dk = (WOOD_DK[0] + 10, WOOD_DK[1] + 6, WOOD_DK[2] + 2)
        c_md = (WOOD_MD[0] + 18, WOOD_MD[1] + 10, WOOD_MD[2] + 4)
        c_hi = (WOOD_HI[0] + 24, WOOD_HI[1] + 16, WOOD_HI[2] + 8)
        c_grain = WOOD_GRAIN_HI
    else:
        c_dk = WOOD_DK
        c_md = WOOD_MD
        c_hi = WOOD_HI
        c_grain = WOOD_GRAIN_HI

    # Body fill — vertical gradient
    body = Image.new('RGBA', (plank_w, plank_h), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    for y in range(plank_h):
        t = y / (plank_h - 1)
        if t < 0.5:
            tt = t / 0.5
            r = int(c_hi[0] + (c_md[0] - c_hi[0]) * tt)
            g = int(c_hi[1] + (c_md[1] - c_hi[1]) * tt)
            b = int(c_hi[2] + (c_md[2] - c_hi[2]) * tt)
        else:
            tt = (t - 0.5) / 0.5
            r = int(c_md[0] + (c_dk[0] - c_md[0]) * tt)
            g = int(c_md[1] + (c_dk[1] - c_md[1]) * tt)
            b = int(c_md[2] + (c_dk[2] - c_md[2]) * tt)
        bd.line([(0, y), (plank_w - 1, y)], fill=(r, g, b, 255))

    # Horizontal grain lines (wood texture)
    rnd = random.Random(hash(label) & 0xffff)
    for _ in range(6):
        gy = rnd.randint(2, plank_h - 3)
        gx0 = rnd.randint(0, 12)
        gx1 = plank_w - rnd.randint(0, 12)
        col = c_grain
        bd.line([(gx0, gy), (gx1, gy)],
                fill=(col[0], col[1], col[2], 110))
    # knots
    for _ in range(2):
        kx = rnd.randint(8, plank_w - 9)
        ky = rnd.randint(3, plank_h - 4)
        bd.ellipse([kx - 2, ky - 1, kx + 2, ky + 1],
                   fill=(c_grain[0] - 20 if c_grain[0] > 20 else 0,
                         max(0, c_grain[1] - 15),
                         max(0, c_grain[2] - 10), 255))
        bd.point((kx, ky), fill=(c_dk[0], c_dk[1], c_dk[2], 255))

    # Inner shadow at top/bottom edges (1px lines)
    bd.line([(0, 0), (plank_w - 1, 0)], fill=rgba(c_hi))
    bd.line([(0, plank_h - 1), (plank_w - 1, plank_h - 1)],
            fill=rgba(WOOD_EDGE))

    # Round corners by clearing pixels
    corner_r = 3
    mask = Image.new('L', (plank_w, plank_h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, plank_w - 1, plank_h - 1],
                         radius=corner_r, fill=255)
    body.putalpha(mask)

    # 1-px dark border
    bd2 = ImageDraw.Draw(body)
    bd2.rounded_rectangle([0, 0, plank_w - 1, plank_h - 1],
                          radius=corner_r,
                          outline=rgba(WOOD_EDGE), width=1)

    canvas.alpha_composite(body, (px0, py0))

    # ROPE wraps at left and right ends
    def draw_rope_wrap(x_left):
        """Vertical rope wrap at given x — covers full plank height."""
        rope_w = 8
        rope_img = Image.new('RGBA', (rope_w, plank_h), TRANSPARENT)
        rd = ImageDraw.Draw(rope_img)
        # rope twist pattern — alternating diagonal stripes
        for y in range(plank_h):
            for x in range(rope_w):
                # diagonal stripes
                stripe = ((x + y) // 2) % 2
                if stripe == 0:
                    col = ROPE_COL
                else:
                    col = ROPE_DK
                # subtle vertical edge shading
                if x == 0 or x == rope_w - 1:
                    col = (ROPE_DK[0] - 20 if ROPE_DK[0] > 20 else 0,
                           max(0, ROPE_DK[1] - 14),
                           max(0, ROPE_DK[2] - 8))
                rd.point((x, y), fill=rgba(col))
        # darken top/bottom for shadow on plank
        rd.line([(0, 0), (rope_w - 1, 0)], fill=rgba(WOOD_EDGE))
        rd.line([(0, plank_h - 1), (rope_w - 1, plank_h - 1)],
                fill=rgba(WOOD_EDGE))
        canvas.alpha_composite(rope_img, (x_left, py0))

    draw_rope_wrap(px0 + 3)
    draw_rope_wrap(px1 - 11)

    # Label text — centered, with subtle shadow
    text_color = TEXT_HOVER if state == 'hover' else TEXT_LIGHT
    text_shadow = (0, 0, 0, 180)
    cdraw = ImageDraw.Draw(canvas)
    tx = px0 + (plank_w - text_w) // 2 - bbox[0]
    ty = py0 + (plank_h - text_h) // 2 - bbox[1]
    # shadow
    cdraw.text((tx + 1, ty + 2), label, font=font, fill=text_shadow)
    cdraw.text((tx, ty), label, font=font, fill=rgba(text_color))

    return canvas


# ============================================================
#  MAIN GENERATION
# ============================================================
def generate_all():
    print('=== BACKGROUND LAYERS ===')
    sky = make_bg_sky()
    save_native_and_4x(sky, 'bg_sky')
    print(f'  bg_sky               {sky.size}')

    mtn = make_bg_mountains()
    save_native_and_4x(mtn, 'bg_mountains')
    print(f'  bg_mountains         {mtn.size}')

    pagoda = make_bg_pagoda()
    save_native_and_4x(pagoda, 'bg_pagoda')
    print(f'  bg_pagoda            {pagoda.size}')

    fg = make_bg_foreground()
    save_native_and_4x(fg, 'bg_foreground')
    print(f'  bg_foreground        {fg.size}')

    print('\n=== TITLE ===')
    title = make_title_main()
    save_native_and_4x(title, 'title_four_clans', also_8x=True)
    print(f'  title_four_clans     {title.size}')

    sub = make_title_subtitle()
    save_native_and_4x(sub, 'title_subtitle')
    print(f'  title_subtitle       {sub.size}')

    katanas = make_title_katanas()
    save_native_and_4x(katanas, 'title_katanas')
    print(f'  title_katanas        {katanas.size}')

    print('\n=== BUTTONS ===')
    button_labels = [
        ('start',   'START',   CLAN_COLORS[3]),  # FIRE orange
        ('options', 'OPTIONS', CLAN_COLORS[1]),  # STORM cyan
        ('credits', 'CREDITS', CLAN_COLORS[0]),  # SHADOW magenta
        ('quit',    'QUIT',    CLAN_COLORS[2]),  # FROST green
    ]
    for slug, label, accent in button_labels:
        for state in ['normal', 'hover', 'pressed']:
            btn = render_button(label, state=state,
                                accent_color=accent if state == 'hover'
                                else None)
            save_native_and_4x(btn, f'button_{slug}_{state}')
        print(f'  button_{slug:<8} ({btn.size}) × 3 states')


# ============================================================
#  PREVIEW — full menu mockup + button strip
# ============================================================
def compose_preview():
    """Stack the layers + paste title + buttons at 4x scale."""
    sky = Image.open(f'{OUT_DIR}/bg_sky_4x.png').convert('RGBA')
    mtn = Image.open(f'{OUT_DIR}/bg_mountains_4x.png').convert('RGBA')
    pag = Image.open(f'{OUT_DIR}/bg_pagoda_4x.png').convert('RGBA')
    fg = Image.open(f'{OUT_DIR}/bg_foreground_4x.png').convert('RGBA')

    canvas = sky.copy()
    canvas.alpha_composite(mtn)
    canvas.alpha_composite(pag)
    canvas.alpha_composite(fg)

    W, H = canvas.size
    katanas = Image.open(f'{OUT_DIR}/title_katanas_4x.png').convert('RGBA')
    title = Image.open(f'{OUT_DIR}/title_four_clans_4x.png').convert('RGBA')
    sub = Image.open(f'{OUT_DIR}/title_subtitle_4x.png').convert('RGBA')

    # Downscale title slightly for the preview so layout breathes.
    # (Original assets remain at full size — this is just for the mockup.)
    tscale = 0.72
    title_s = title.resize((int(title.size[0] * tscale),
                            int(title.size[1] * tscale)),
                           Image.NEAREST)
    katanas_s = katanas.resize((int(katanas.size[0] * tscale * 1.05),
                                int(katanas.size[1] * tscale * 1.05)),
                               Image.NEAREST)

    title_top = int(H * 0.04)

    # Katanas centered at title midline (sweep behind it)
    kx = (W - katanas_s.size[0]) // 2
    ky = title_top + title_s.size[1] // 2 - katanas_s.size[1] // 2
    canvas.alpha_composite(katanas_s, (kx, ky))

    tx = (W - title_s.size[0]) // 2
    canvas.alpha_composite(title_s, (tx, title_top))

    sx = (W - sub.size[0]) // 2
    sy = title_top + title_s.size[1] - 6
    canvas.alpha_composite(sub, (sx, sy))

    # Buttons stacked
    buttons = []
    for slug, state in [('start', 'hover'),
                        ('options', 'normal'),
                        ('credits', 'normal'),
                        ('quit', 'normal')]:
        b = Image.open(
            f'{OUT_DIR}/button_{slug}_{state}_4x.png').convert('RGBA')
        buttons.append(b)
    bx = (W - buttons[0].size[0]) // 2
    button_step = buttons[0].size[1] - 80  # visible plank height ~ 180
    total_btn_h = button_step * (len(buttons) - 1) + buttons[0].size[1]
    by = sy + sub.size[1] + 30
    # Make sure buttons fit; if too tall, tighten step further.
    if by + total_btn_h > H - int(H * 0.04):
        button_step = max(140,
                          (H - int(H * 0.08) - by - buttons[0].size[1])
                          // (len(buttons) - 1))
        total_btn_h = button_step * (len(buttons) - 1) + buttons[0].size[1]
    for b in buttons:
        canvas.alpha_composite(b, (bx, by))
        by += button_step

    canvas.save(f'{OUT_DIR}/menu_preview.png')
    print(f'\nWrote menu_preview.png ({canvas.size})')


def compose_button_preview():
    """Strip showing all 4 buttons × 3 states on a dark background."""
    states = ['normal', 'hover', 'pressed']
    slugs = ['start', 'options', 'credits', 'quit']
    sample = Image.open(f'{OUT_DIR}/button_start_normal_4x.png')
    bw, bh = sample.size
    pad = 24
    label_h = 28
    W = bw * len(states) + pad * (len(states) + 1)
    H = (bh - 20) * len(slugs) + pad * (len(slugs) + 1) + label_h

    bg = Image.new('RGBA', (W, H), (16, 14, 28, 255))
    d = ImageDraw.Draw(bg)
    # checkerboard hint
    for y in range(0, H, 16):
        for x in range(0, W, 16):
            if ((x // 16) + (y // 16)) % 2 == 1:
                d.rectangle([x, y, x + 15, y + 15],
                            fill=(22, 18, 36, 255))

    # state headers
    font_hdr = ImageFont.truetype(FONT_BOLD, 16)
    for i, st in enumerate(states):
        x0 = pad + i * (bw + pad)
        d.text((x0 + bw // 2 - 24, 6),
               st.upper(), font=font_hdr, fill=(220, 220, 240, 255))

    y = pad + label_h
    for slug in slugs:
        for i, st in enumerate(states):
            btn = Image.open(
                f'{OUT_DIR}/button_{slug}_{st}_4x.png').convert('RGBA')
            x = pad + i * (bw + pad)
            bg.alpha_composite(btn, (x, y))
        y += bh - 20 + pad
    bg.save(f'{OUT_DIR}/menu_buttons_preview.png')
    print(f'Wrote menu_buttons_preview.png ({bg.size})')


if __name__ == '__main__':
    generate_all()
    compose_preview()
    compose_button_preview()
    print('\nDone. Outputs in:', OUT_DIR)
