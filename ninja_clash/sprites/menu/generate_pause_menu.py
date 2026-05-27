"""
PAUSE-MENU asset generator.

Continues the same pixel-art family as generate_main_menu.py /
generate_select_menus.py: weathered stone for headers, wooden plank +
rope for interactive rows, bamboo for the scroll backdrop.

Concept: a bamboo scroll unfurled in front of a darkened world. The
scroll has a heavy bamboo rod at the top and a partial roll at the
bottom, with parchment in between for the menu content.

Outputs (under sprites/menu/, all transparent PNGs at native + 4x):

    pause_backdrop.png             — fullscreen dark vignette with falling
                                     sakura petals (semi-transparent overlay)
    pause_scroll_panel.png         — central bamboo-rod scroll with parchment
                                     body (holds the menu content)

    pause_header_paused.png        — stone-carved "PAUSED" wordmark
    pause_header_settings.png      — stone-carved "SETTINGS" wordmark

    pause_button_normal.png        — wooden plank row (label rendered at
                                     runtime via Godot Label nodes)
    pause_button_hover.png         — same plank with warm gold glow

    pause_cursor.png               — pulsing arrow indicator (▶ in style)

    pause_volume_track.png         — wooden track for volume bars
    pause_volume_segment_filled.png — single filled cell (warm gold)
    pause_volume_segment_empty.png  — single empty cell (dark hollow)

    preview_pause_menu.png         — mockup of PAUSED page
    preview_pause_settings.png     — mockup of SETTINGS page

All graphics keep the deep night palette + bamboo green + parchment cream
+ stone-grey family so the pause overlay feels like an in-world artifact
rather than a generic UI panel.
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter


# ============================================================
#  CONFIG
# ============================================================
FONT_BLACK = '/usr/share/fonts/truetype/lato/Lato-Black.ttf'
FONT_BOLD  = '/usr/share/fonts/truetype/lato/Lato-Bold.ttf'

_BASH = '/sessions/gracious-determined-hamilton/mnt/ninja_clash/sprites/menu'
_HOST = '/Users/a88/IdeaProjects/minu-mang/ninja_clash/sprites/menu'
OUT_DIR = _BASH if os.path.isdir(_BASH) else _HOST
os.makedirs(OUT_DIR, exist_ok=True)

TRANSPARENT = (0, 0, 0, 0)


# ============================================================
#  PALETTES (shared family)
# ============================================================
STONE_TONES = [(44, 36, 26), (78, 66, 50), (118, 102, 78),
               (152, 136, 104), (192, 174, 138), (228, 212, 178)]
RIM_HI = (228, 212, 178); RIM_MID = (192, 174, 138)
PIT_DK = (78, 66, 50); PIT_MID = (118, 102, 78)
MOSS_DARK = (44, 78, 30); MOSS_MID = (76, 122, 50)
MOSS_BRIGHT = (130, 178, 76); MOSS_TIP = (188, 222, 132)
LICHEN_ORG = (220, 170, 90); LICHEN_WHITE = (210, 220, 215)
CRACK_DEEP = (16, 12, 22); CRACK_LIFT = (175, 158, 122)
OUTLINE_COL = (18, 14, 24)
SHADOW_NEAR = (22, 16, 30); SHADOW_FAR = (44, 32, 54)

# Wood
WOOD_DK = (54, 32, 18); WOOD_MD = (98, 60, 30); WOOD_HI = (140, 92, 46)
WOOD_GRAIN_HI = (170, 122, 68); WOOD_GRAIN_DK = (38, 22, 12)
WOOD_EDGE = (26, 16, 8)
ROPE_COL = (228, 196, 138); ROPE_DK = (140, 102, 58)

# Bamboo (for scroll rods)
BAMBOO_DARK = (40, 68, 38); BAMBOO_MID = (80, 130, 58)
BAMBOO_HI = (130, 178, 90); BAMBOO_NODE = (28, 48, 24)

# Parchment / paper
PARCH_DK = (172, 146, 92)
PARCH_MD = (212, 184, 132)
PARCH_HI = (240, 216, 162)
PARCH_EDGE = (110, 86, 50)
PARCH_STAIN = (160, 124, 70)

# Text
TEXT_LIGHT = (244, 232, 196)
TEXT_HOVER = (255, 232, 132)
TEXT_DARK = (28, 18, 16)

# Selection / glow
SELECT_GLOW = (255, 198, 90)
SELECT_RIM = (255, 232, 150)

# Sakura petals (drifting on backdrop)
SAKURA = (255, 180, 210)
SAKURA_DK = (218, 130, 168)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ============================================================
#  Helpers
# ============================================================
def _hash(ix, iy, seed):
    h = math.sin(ix * 127.1 + iy * 311.7 + seed * 71.3) * 43758.5453
    return h - math.floor(h)


def _smoothstep(t):
    return t * t * (3 - 2 * t)


def value_noise(x, y, seed=0):
    x0 = math.floor(x); y0 = math.floor(y)
    fx = x - x0; fy = y - y0
    sx = _smoothstep(fx); sy = _smoothstep(fy)
    v00 = _hash(x0, y0, seed); v10 = _hash(x0 + 1, y0, seed)
    v01 = _hash(x0, y0 + 1, seed); v11 = _hash(x0 + 1, y0 + 1, seed)
    return (v00 * (1 - sx) + v10 * sx) * (1 - sy) + \
           (v01 * (1 - sx) + v11 * sx) * sy


def fractal_noise(x, y, octaves=3, seed=0, lacunarity=2.0, persistence=0.5):
    total = 0.0; amp = 1.0; freq = 1.0; norm = 0.0
    for _ in range(octaves):
        total += value_noise(x * freq, y * freq, seed) * amp
        norm += amp
        amp *= persistence; freq *= lacunarity
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


def save_native_and_4x(img, basename):
    img.save(f'{OUT_DIR}/{basename}_native.png')
    w, h = img.size
    img.resize((w * 4, h * 4),
               Image.NEAREST).save(f'{OUT_DIR}/{basename}_4x.png')


# ============================================================
#  Stone text renderer (reused / matches other generators)
# ============================================================
def render_drop_shadow(mask):
    w, h = mask.size
    far_mask = dilate(mask, 4)
    far_img = Image.new('RGBA', (w, h), TRANSPARENT)
    fp = far_img.load(); fm = far_mask.load()
    for y in range(h):
        for x in range(w):
            if fm[x, y] > 128:
                fp[x, y] = (*SHADOW_FAR, 80)
    far_img = far_img.filter(ImageFilter.GaussianBlur(radius=3.5))
    near_mask = dilate(mask, 2)
    near_img = Image.new('RGBA', (w, h), TRANSPARENT)
    np_px = near_img.load(); nm = near_mask.load()
    for y in range(h):
        for x in range(w):
            if nm[x, y] > 128:
                np_px[x, y] = (*SHADOW_NEAR, 145)
    near_img = near_img.filter(ImageFilter.GaussianBlur(radius=1.5))
    return far_img, near_img


def render_stone_surface(mask, seed=0, light_dir=(-1, -1)):
    w, h = mask.size
    img = Image.new('RGBA', (w, h), TRANSPARENT)
    px = img.load(); mp = mask.load()
    lx, ly = light_dir; n = math.hypot(lx, ly); lx /= n; ly /= n
    proj_min = 0.0; proj_max = lx * w + ly * h
    if proj_max < proj_min: proj_min, proj_max = proj_max, proj_min
    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128: continue
            n_macro = fractal_noise(x / 22, y / 22, octaves=2, seed=seed)
            n_micro = fractal_noise(x / 5, y / 5,
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


def _stone_extras(surf, mask, seed):
    w, h = mask.size
    sp = surf.load(); mp = mask.load()
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
    rnd = random.Random(seed + 333)
    for _ in range(12):
        x = rnd.randint(2, w - 3); y = rnd.randint(2, h - 3)
        if mp[x, y] > 128 and mp[x, y - 1] > 128:
            sp[x, y] = rgba(PIT_DK)
            if rnd.random() < 0.6 and mp[x + 1, y] > 128:
                sp[x + 1, y] = rgba(PIT_MID)
    rnd = random.Random(seed + 555)
    for _ in range(2):
        x0 = rnd.randint(4, w - 5); y0 = rnd.randint(4, h - 5)
        if mp[x0, y0] <= 128: continue
        ang = rnd.uniform(0, math.tau)
        cx, cy = float(x0), float(y0)
        for _ in range(rnd.randint(10, 14)):
            cx += math.cos(ang) * 1.4
            cy += math.sin(ang) * 1.4
            ang += rnd.uniform(-0.4, 0.4)
            ix, iy = int(cx), int(cy)
            if not (0 <= ix < w and 0 <= iy < h): break
            if mp[ix, iy] <= 128: break
            sp[ix, iy] = rgba(CRACK_DEEP)
    # Moss
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
        sz = rnd.randint(3, 6); pts = set()
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
            if rnd.random() < 0.55: sp[p, q] = rgba(MOSS_TIP)


def render_stone_text(text, font_size=44, seed=0):
    raw = text_mask(text, FONT_BLACK, font_size, padding=12)
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
    _stone_extras(surf, raw, seed)
    canvas.alpha_composite(surf, (sx, sy))
    return canvas


# ============================================================
#  BACKDROP — fullscreen dark vignette with sakura petals
# ============================================================
def render_backdrop():
    """Fullscreen overlay native 480x270 (4x = 1920x1080).
       Dark semi-transparent center + slightly darker corners (vignette)
       + drifting sakura petals scattered across."""
    W, H = 480, 270
    img = Image.new('RGBA', (W, H), TRANSPARENT)
    px = img.load()
    rnd = random.Random(7)
    # Vignette: alpha is higher (darker) near edges, lower (less dark)
    # in the centre — keeps focus on the scroll while still darkening
    # the action behind.
    cx, cy = W / 2, H / 2
    max_d = math.hypot(cx, cy)
    for y in range(H):
        for x in range(W):
            d_ = math.hypot(x - cx, y - cy) / max_d
            # Base darkness 0.62, ramping to 0.88 at corners.
            a = int(160 + d_ * 78)
            # Slight blue-violet tint
            px[x, y] = (8, 6, 18, max(0, min(240, a)))

    # Sakura petals — small pink dabs scattered across the screen
    d = ImageDraw.Draw(img)
    for _ in range(70):
        sx = rnd.randint(2, W - 3)
        sy = rnd.randint(2, H - 3)
        # Tilted teardrop shape ~3-4 px
        col = SAKURA if rnd.random() < 0.7 else SAKURA_DK
        a = rnd.randint(110, 200)
        # Petal core
        d.point((sx, sy), fill=(col[0], col[1], col[2], a))
        d.point((sx + 1, sy), fill=(col[0], col[1], col[2], a))
        d.point((sx, sy + 1), fill=(col[0], col[1], col[2], a))
        if rnd.random() < 0.5:
            d.point((sx + 1, sy + 1),
                    fill=(col[0], col[1], col[2], a))
        # Faint trail behind petal (drift)
        if rnd.random() < 0.5:
            d.point((sx - 1, sy + 1),
                    fill=(col[0], col[1], col[2], max(0, a - 90)))
    return img


# ============================================================
#  SCROLL PANEL — bamboo top + parchment middle + bamboo bottom
# ============================================================
def render_scroll_panel():
    """Central scroll panel. Native 230x230 (4x = 920x920).
       Bamboo rod top + parchment body (with subtle stains and grain)
       + bamboo rod bottom with rolled lip. Transparent corners.
       Wide enough to host the volume sliders on the SETTINGS page."""
    W, H = 230, 230
    margin = 16
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    ox, oy = margin, margin

    rnd = random.Random(2026)

    # Drop shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rectangle([ox + 4, oy + 8, ox + W + 4, oy + H + 8],
                 fill=(0, 0, 0, 140))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=5))
    canvas.alpha_composite(sh)

    # ---- Top bamboo rod ----
    rod_h = 14
    top_rod_y0 = oy
    top_rod_y1 = oy + rod_h
    # Body (gradient: dark at bottom, lighter at top to suggest cylinder)
    for y in range(top_rod_y0, top_rod_y1):
        t = (y - top_rod_y0) / max(1, rod_h - 1)
        # cylindrical shading: mid -> dark on either side, hi in middle
        for x in range(ox - 4, ox + W + 4):
            # Distance from cylinder centerline (vertical)
            cy_ = (top_rod_y0 + top_rod_y1) / 2
            d_ = abs(y - cy_) / (rod_h / 2)
            base = (
                int(BAMBOO_HI[0] * (1 - d_) + BAMBOO_DARK[0] * d_),
                int(BAMBOO_HI[1] * (1 - d_) + BAMBOO_DARK[1] * d_),
                int(BAMBOO_HI[2] * (1 - d_) + BAMBOO_DARK[2] * d_),
            )
            # grain noise
            n = (math.sin(x * 0.4 + y * 1.2) * 0.5 + 0.5) * 10 - 5
            r = max(0, min(255, base[0] + int(n)))
            g = max(0, min(255, base[1] + int(n)))
            b = max(0, min(255, base[2] + int(n * 0.5)))
            d.point((x, y), fill=(r, g, b, 255))
    # End caps (darker, round-ish)
    for ex, sign in [(ox - 4, -1), (ox + W + 3, 1)]:
        for off in range(0, 4):
            d.line([(ex + sign * off, top_rod_y0 + 1 + off // 2),
                    (ex + sign * off, top_rod_y1 - 1 - off // 2)],
                   fill=rgba(BAMBOO_DARK))
    # Node line in middle
    node_x = ox + W // 2
    for ny in range(top_rod_y0, top_rod_y1):
        d.point((node_x, ny), fill=rgba(BAMBOO_NODE))
        d.point((node_x + 1, ny), fill=rgba(BAMBOO_HI))
    # Rope wraps (2 ties holding parchment to rod)
    for rx in (ox + 30, ox + W - 30):
        for ry in range(top_rod_y0 - 1, top_rod_y1 + 4):
            stripe = (ry // 2) % 2
            col = ROPE_COL if stripe == 0 else ROPE_DK
            for tx in range(rx - 3, rx + 4):
                d.point((tx, ry), fill=rgba(col))

    # ---- Parchment body ----
    parch_y0 = top_rod_y1 + 2
    parch_y1 = oy + H - 18   # leaves room for bottom rod
    parch_x0 = ox + 4
    parch_x1 = ox + W - 4
    # Fill with parchment gradient + noise
    for y in range(parch_y0, parch_y1):
        for x in range(parch_x0, parch_x1):
            # gradient from PARCH_HI at top center to PARCH_DK at corners
            cx_ = (parch_x0 + parch_x1) / 2
            cy_ = (parch_y0 + parch_y1) / 2
            dx_ = (x - cx_) / ((parch_x1 - parch_x0) / 2)
            dy_ = (y - cy_) / ((parch_y1 - parch_y0) / 2)
            d_ = min(1.0, math.hypot(dx_ * 0.7, dy_ * 0.7))
            mid = (
                int(PARCH_HI[0] * (1 - d_) + PARCH_MD[0] * d_),
                int(PARCH_HI[1] * (1 - d_) + PARCH_MD[1] * d_),
                int(PARCH_HI[2] * (1 - d_) + PARCH_MD[2] * d_),
            )
            # noise grain
            n_ = fractal_noise(x / 8, y / 8, octaves=2, seed=42)
            n_amp = (n_ - 0.5) * 22
            r = max(0, min(255, mid[0] + int(n_amp)))
            g = max(0, min(255, mid[1] + int(n_amp * 0.7)))
            b = max(0, min(255, mid[2] + int(n_amp * 0.4)))
            d.point((x, y), fill=(r, g, b, 255))

    # Parchment border (dark thin line)
    d.rectangle([parch_x0, parch_y0, parch_x1 - 1, parch_y1 - 1],
                outline=rgba(PARCH_EDGE), width=1)
    # Slight inner shadow on left/top (paper layering effect)
    for i in range(2):
        a = 60 - i * 24
        if a <= 0: break
        d.line([(parch_x0 + i, parch_y0 + i),
                (parch_x1 - 1 - i, parch_y0 + i)],
               fill=(*PARCH_EDGE, a))
        d.line([(parch_x0 + i, parch_y0 + i),
                (parch_x0 + i, parch_y1 - 1 - i)],
               fill=(*PARCH_EDGE, a))

    # (Tea stains and curled-corner marks removed — they read as dark
    # specks against the parchment when the panel is composited at
    # 4x scale in-game. Parchment stays clean.)

    # ---- Bottom bamboo rod (rolled — partial visible) ----
    bot_rod_y0 = oy + H - 16
    bot_rod_y1 = oy + H
    rod_h2 = bot_rod_y1 - bot_rod_y0
    for y in range(bot_rod_y0, bot_rod_y1):
        cy_ = (bot_rod_y0 + bot_rod_y1) / 2
        d_ = abs(y - cy_) / (rod_h2 / 2)
        for x in range(ox - 4, ox + W + 4):
            base = (
                int(BAMBOO_HI[0] * (1 - d_) + BAMBOO_DARK[0] * d_),
                int(BAMBOO_HI[1] * (1 - d_) + BAMBOO_DARK[1] * d_),
                int(BAMBOO_HI[2] * (1 - d_) + BAMBOO_DARK[2] * d_),
            )
            n = (math.sin(x * 0.5 + y * 1.1) * 0.5 + 0.5) * 10 - 5
            r = max(0, min(255, base[0] + int(n)))
            g = max(0, min(255, base[1] + int(n)))
            b = max(0, min(255, base[2] + int(n * 0.5)))
            d.point((x, y), fill=(r, g, b, 255))
    # End caps
    for ex, sign in [(ox - 4, -1), (ox + W + 3, 1)]:
        for off in range(0, 4):
            d.line([(ex + sign * off, bot_rod_y0 + 1 + off // 2),
                    (ex + sign * off, bot_rod_y1 - 1 - off // 2)],
                   fill=rgba(BAMBOO_DARK))
    # Curled paper tucking under the rod (small darker strip just above)
    for y in range(bot_rod_y0 - 3, bot_rod_y0):
        for x in range(parch_x0, parch_x1):
            d.point((x, y), fill=(*PARCH_EDGE, 180))

    return canvas


# ============================================================
#  HEADERS — "PAUSED" and "SETTINGS"
# ============================================================
def make_pause_headers():
    paused = render_stone_text('PAUSED', font_size=42, seed=4242)
    save_native_and_4x(paused, 'pause_header_paused')
    print(f'  pause_header_paused  {paused.size}')
    settings = render_stone_text('SETTINGS', font_size=42, seed=8484)
    save_native_and_4x(settings, 'pause_header_settings')
    print(f'  pause_header_settings  {settings.size}')


# ============================================================
#  BUTTON — wooden plank (label rendered separately in Godot)
# ============================================================
def render_pause_button(state='normal'):
    """Wooden plank row, ~190x28 native. Two states: normal, hover.
       Wide enough to host MASTER/MUSIC/SFX label + 10-segment volume bar.
       Label is left to the engine (transparent inside the plank)."""
    W, H = 190, 28
    margin = 12
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # Glow when hovered
    if state == 'hover':
        glow = Image.new('RGBA', (cw, ch), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        for grow, alpha in [(8, 35), (5, 60), (2, 95)]:
            gd.rounded_rectangle(
                [margin - grow, margin - grow,
                 margin + W + grow, margin + H + grow],
                radius=5 + grow,
                fill=(*SELECT_GLOW, alpha))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=3))
        canvas.alpha_composite(glow)

    # Shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([margin + 2, margin + 3,
                          margin + W + 3, margin + H + 3],
                         radius=4, fill=(0, 0, 0, 130))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=2))
    canvas.alpha_composite(sh)

    # Plank body (vertical gradient)
    body = Image.new('RGBA', (W, H), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    if state == 'hover':
        c_hi = (WOOD_HI[0] + 24, WOOD_HI[1] + 16, WOOD_HI[2] + 8)
        c_md = (WOOD_MD[0] + 18, WOOD_MD[1] + 10, WOOD_MD[2] + 4)
        c_dk = (WOOD_DK[0] + 10, WOOD_DK[1] + 6, WOOD_DK[2] + 2)
    else:
        c_hi, c_md, c_dk = WOOD_HI, WOOD_MD, WOOD_DK
    for y in range(H):
        t = y / (H - 1)
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
        bd.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))

    # Subtle grain lines
    rnd = random.Random(hash(state) & 0xffff)
    for _ in range(5):
        gy = rnd.randint(2, H - 3)
        gx0 = rnd.randint(0, 8); gx1 = W - rnd.randint(0, 8)
        bd.line([(gx0, gy), (gx1, gy)],
                fill=(*WOOD_GRAIN_HI, 100))
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=3,
                         outline=rgba(WOOD_EDGE), width=1)
    # Mask round corners
    mask = Image.new('L', (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, W - 1, H - 1], radius=3, fill=255)
    body.putalpha(mask)

    # Tiny rope wraps at each end (consistent with main menu buttons)
    for x_end in (3, W - 8):
        for ry in range(H):
            stripe = (ry // 2) % 2
            col = ROPE_COL if stripe == 0 else ROPE_DK
            for off in range(4):
                ImageDraw.Draw(body).point((x_end + off, ry),
                                           fill=rgba(col))
        ImageDraw.Draw(body).line([(x_end, 0), (x_end + 3, 0)],
                                  fill=rgba(WOOD_EDGE))
        ImageDraw.Draw(body).line([(x_end, H - 1), (x_end + 3, H - 1)],
                                  fill=rgba(WOOD_EDGE))

    canvas.alpha_composite(body, (margin, margin))
    return canvas


# ============================================================
#  CURSOR — pulsing selection arrow ▶
# ============================================================
def render_cursor():
    """Glowing yellow arrow (▶) ~ 14x16 native, ready to be placed
       to the left of a selected row."""
    W, H = 16, 18
    img = Image.new('RGBA', (W, H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    cx, cy = 6, H // 2
    pts = [(cx + 6, cy), (cx - 4, cy - 7), (cx - 4, cy + 7)]
    # Glow halo
    glow = Image.new('RGBA', (W, H), TRANSPARENT)
    gd = ImageDraw.Draw(glow)
    gd.polygon(pts, fill=(*SELECT_GLOW, 140))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=3))
    img.alpha_composite(glow)
    # Solid arrow
    d.polygon(pts, fill=rgba(SELECT_RIM), outline=(*WOOD_EDGE, 220))
    # Inner highlight
    d.polygon([(cx + 3, cy), (cx - 2, cy - 4), (cx - 2, cy + 4)],
              fill=(255, 255, 220, 255))
    return img


# ============================================================
#  VOLUME SLIDER — track + filled / empty segments
# ============================================================
def render_volume_track():
    """Wooden recessed track for 10 segments. Native 124x14 (4x = 496x56).
       The Godot code can layer N filled segments + (10-N) empty segments
       on top of this track."""
    W, H = 124, 14
    margin = 8
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    ox, oy = margin, margin
    # Outer wood frame
    d.rounded_rectangle([ox, oy, ox + W - 1, oy + H - 1],
                        radius=3, fill=rgba(WOOD_MD),
                        outline=rgba(WOOD_EDGE), width=1)
    # Inner recess (darker)
    d.rounded_rectangle([ox + 2, oy + 2, ox + W - 3, oy + H - 3],
                        radius=2, fill=(28, 20, 32, 255),
                        outline=(0, 0, 0, 200), width=1)
    # Light scratches/grain on frame edges
    for gy in [oy, oy + H - 1]:
        for sx in range(ox + 3, ox + W - 3, 8):
            d.line([(sx, gy), (sx + 4, gy)],
                   fill=(*WOOD_GRAIN_HI, 110))
    return canvas


def render_volume_segment(filled=True):
    """Single segment of the volume bar. Native 10x10 (4x = 40x40).
       The track has space for 10 of these side by side."""
    W, H = 10, 10
    margin = 3
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    if filled:
        # Warm gold filled cell with glow
        glow = Image.new('RGBA', (cw, ch), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        gd.rounded_rectangle([margin - 2, margin - 2,
                              margin + W + 1, margin + H + 1],
                             radius=3, fill=(*SELECT_GLOW, 120))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=2))
        canvas.alpha_composite(glow)
        # Solid filled body
        d.rounded_rectangle([margin, margin,
                             margin + W - 1, margin + H - 1],
                            radius=2, fill=rgba(SELECT_GLOW),
                            outline=rgba(WOOD_EDGE))
        d.line([(margin + 1, margin + 1),
                (margin + W - 2, margin + 1)],
               fill=rgba(SELECT_RIM))
        d.point((margin + 1, margin + 2), fill=rgba(SELECT_RIM))
    else:
        # Empty cell: dark hollow with subtle rim
        d.rounded_rectangle([margin, margin,
                             margin + W - 1, margin + H - 1],
                            radius=2, fill=(32, 22, 30, 255),
                            outline=rgba(WOOD_EDGE))
        # tiny inner shadow
        d.line([(margin + 1, margin + 1),
                (margin + W - 2, margin + 1)],
               fill=(16, 12, 18, 255))
    return canvas


# ============================================================
#  Generate all
# ============================================================
def generate_all():
    print('=== BACKDROP ===')
    bd = render_backdrop()
    save_native_and_4x(bd, 'pause_backdrop')
    print(f'  pause_backdrop  {bd.size}')

    print('\n=== SCROLL PANEL ===')
    scroll = render_scroll_panel()
    save_native_and_4x(scroll, 'pause_scroll_panel')
    print(f'  pause_scroll_panel  {scroll.size}')

    print('\n=== HEADERS ===')
    make_pause_headers()

    print('\n=== BUTTONS ===')
    normal = render_pause_button('normal')
    save_native_and_4x(normal, 'pause_button_normal')
    print(f'  pause_button_normal  {normal.size}')
    hover = render_pause_button('hover')
    save_native_and_4x(hover, 'pause_button_hover')
    print(f'  pause_button_hover  {hover.size}')

    print('\n=== CURSOR ===')
    cursor = render_cursor()
    save_native_and_4x(cursor, 'pause_cursor')
    print(f'  pause_cursor  {cursor.size}')

    print('\n=== VOLUME ===')
    track = render_volume_track()
    save_native_and_4x(track, 'pause_volume_track')
    print(f'  pause_volume_track  {track.size}')
    filled = render_volume_segment(filled=True)
    save_native_and_4x(filled, 'pause_volume_segment_filled')
    print(f'  pause_volume_segment_filled  {filled.size}')
    empty = render_volume_segment(filled=False)
    save_native_and_4x(empty, 'pause_volume_segment_empty')
    print(f'  pause_volume_segment_empty  {empty.size}')


# ============================================================
#  PREVIEWS — composite each page
# ============================================================
def _compose_page(page_title, rows, selected_idx,
                  volume_rows=None, hint='↑/↓ select   X confirm   Esc back'):
    """Compose a single preview page: pause backdrop (over a mock game
       scene) + scroll panel + header + 4 rows + cursor + (optional
       volume bars for SETTINGS) + hint plate."""
    W, H = 1920, 1080
    out = Image.new('RGBA', (W, H), (0, 0, 0, 255))

    # Simulate "frozen game world" behind the pause overlay.
    # We grab the level-1 background and dim it; if unavailable, use
    # a procedural night gradient.
    try:
        bg_path = f'{OUT_DIR}/bg_sky_4x.png'
        bg = Image.open(bg_path).convert('RGBA').resize((W, H))
        # Dim by overlaying 50% black
        dim = Image.new('RGBA', (W, H), (0, 0, 0, 100))
        bg.alpha_composite(dim)
        out.alpha_composite(bg)
    except FileNotFoundError:
        for y in range(H):
            t = y / (H - 1)
            c = (int(10 + 30 * t), int(8 + 20 * t),
                 int(28 + 40 * t), 255)
            ImageDraw.Draw(out).line([(0, y), (W - 1, y)], fill=c)

    # Pause backdrop (semi-transparent vignette + sakura)
    backdrop = Image.open(
        f'{OUT_DIR}/pause_backdrop_4x.png').convert('RGBA')
    out.alpha_composite(backdrop)

    # Scroll panel centered
    scroll = Image.open(
        f'{OUT_DIR}/pause_scroll_panel_4x.png').convert('RGBA')
    sx = (W - scroll.size[0]) // 2
    sy = (H - scroll.size[1]) // 2 - 40
    out.alpha_composite(scroll, (sx, sy))

    # Header on parchment (top of scroll body)
    header = Image.open(
        f'{OUT_DIR}/{page_title}_4x.png').convert('RGBA')
    hx = sx + (scroll.size[0] - header.size[0]) // 2
    hy = sy + 60
    out.alpha_composite(header, (hx, hy))

    # Row buttons stacked
    btn_normal = Image.open(
        f'{OUT_DIR}/pause_button_normal_4x.png').convert('RGBA')
    btn_hover = Image.open(
        f'{OUT_DIR}/pause_button_hover_4x.png').convert('RGBA')
    cursor = Image.open(f'{OUT_DIR}/pause_cursor_4x.png').convert('RGBA')

    row_w, row_h = btn_normal.size
    row_step = row_h - 60   # tightened so 4 rows fit
    row_block_h = row_step * (len(rows) - 1) + row_h
    rx = sx + (scroll.size[0] - row_w) // 2
    ry = hy + header.size[1] + 30

    font_label = ImageFont.truetype(FONT_BLACK, 28)

    for i, label in enumerate(rows):
        button = btn_hover if i == selected_idx else btn_normal
        out.alpha_composite(button, (rx, ry))

        has_volume = volume_rows and i in volume_rows
        color = TEXT_HOVER if i == selected_idx else TEXT_LIGHT
        bb = font_label.getbbox(label)
        tw = bb[2] - bb[0]; th = bb[3] - bb[1]

        if has_volume:
            # Label left-aligned, volume bar right-aligned
            tx = rx + 80 - bb[0]
        else:
            # Label centered
            tx = rx + (row_w - tw) // 2 - bb[0]
        ty = ry + (row_h - th) // 2 - bb[1]
        ImageDraw.Draw(out).text((tx + 1, ty + 1), label,
                                 font=font_label,
                                 fill=(0, 0, 0, 200))
        ImageDraw.Draw(out).text((tx, ty), label, font=font_label,
                                 fill=rgba(color))

        # Selection arrow cursor when selected
        if i == selected_idx:
            cx_ = rx - cursor.size[0] - 20
            cy_ = ry + (row_h - cursor.size[1]) // 2
            out.alpha_composite(cursor, (cx_, cy_))

        # Volume bar on this row if specified
        if has_volume:
            value = volume_rows[i]   # 0..1
            track = Image.open(
                f'{OUT_DIR}/pause_volume_track_4x.png').convert('RGBA')
            # Position track to the right portion of the button
            tx_ = rx + row_w - track.size[0] - 40
            ty_ = ry + (row_h - track.size[1]) // 2
            out.alpha_composite(track, (tx_, ty_))
            filled_img = Image.open(
                f'{OUT_DIR}/pause_volume_segment_filled_4x.png'
            ).convert('RGBA')
            empty_img = Image.open(
                f'{OUT_DIR}/pause_volume_segment_empty_4x.png'
            ).convert('RGBA')
            n_filled = int(round(value * 10))
            inner_off = 32   # track padding @ 4x
            slot_w = (track.size[0] - inner_off * 2) // 10
            for s in range(10):
                seg = filled_img if s < n_filled else empty_img
                seg_x = tx_ + inner_off + s * slot_w + \
                    (slot_w - seg.size[0]) // 2
                seg_y = ty_ + (track.size[1] - seg.size[1]) // 2
                out.alpha_composite(seg, (seg_x, seg_y))
            # Percentage text after the bar
            pct = f'{int(round(value * 100))}%'
            font_pct = ImageFont.truetype(FONT_BOLD, 22)
            pb = font_pct.getbbox(pct)
            pct_x = tx_ + track.size[0] + 12 - pb[0]
            pct_y = ty_ + (track.size[1] - (pb[3] - pb[1])) // 2 - pb[1]
            ImageDraw.Draw(out).text((pct_x + 1, pct_y + 1), pct,
                                     font=font_pct, fill=(0, 0, 0, 200))
            ImageDraw.Draw(out).text((pct_x, pct_y), pct,
                                     font=font_pct, fill=rgba(color))

        ry += row_step

    # Hint plate at bottom of scroll
    hint_plate = Image.open(
        f'{OUT_DIR}/ui_hint_plate_4x.png').convert('RGBA')
    out.alpha_composite(hint_plate,
                        ((W - hint_plate.size[0]) // 2,
                         sy + scroll.size[1] + 30))

    return out


def preview_paused():
    out = _compose_page(
        'pause_header_paused',
        ['RESUME', 'RESTART MATCH', 'SETTINGS', 'QUIT TO MENU'],
        selected_idx=0)
    out.save(f'{OUT_DIR}/preview_pause_menu.png')
    print(f'\nWrote preview_pause_menu.png ({out.size})')


def preview_settings():
    out = _compose_page(
        'pause_header_settings',
        ['MASTER', 'MUSIC', 'SFX', 'BACK'],
        selected_idx=1,
        volume_rows={0: 0.8, 1: 0.6, 2: 0.4})
    out.save(f'{OUT_DIR}/preview_pause_settings.png')
    print(f'Wrote preview_pause_settings.png ({out.size})')


if __name__ == '__main__':
    generate_all()
    preview_paused()
    preview_settings()
    print(f'\nDone. Outputs in: {OUT_DIR}')
