"""
SELECT-SCREEN asset generator — clan select, mode select, map select.

Continues the same pixel-art family as generate_main_menu.py:
weathered stone for text, wooden plank + rope for interactive elements,
clan-colored highlights, drop shadows, chunky pixels.

Outputs (all under sprites/menu/, all transparent PNGs at native + 4x):

    Headers (stone text, same family as FOUR CLANS):
        header_choose_your_clan.png
        header_select_mode.png
        header_choose_arena.png

    Clan select (4 vertical banner-scrolls, kanji-style sigil + name):
        clan_shadow.png   clan_storm.png
        clan_frost.png    clan_fire.png

    Mode select (4 mode tiles with ninja silhouettes):
        mode_p1_vs_p2.png        — two ninjas facing
        mode_p1_vs_ai.png        — ninja vs goggled bot
        mode_ai_vs_ai.png        — two bots
        mode_p1_vs_3.png         — ninja vs three bots (FFA)
        mode_<slug>_selected.png — selected/glow variant for each

    AI difficulty stamps (calligraphy-style rank seals):
        diff_genin.png       diff_chunin.png       diff_jonin.png

    Map select:
        map_frame_normal.png      — wooden frame around map preview
        map_frame_selected.png    — glowing selected variant
        map_sakura_temple.png     — pre-rendered preview thumbnail of map
        map_nameplate_sakura.png  — large wooden name plate

    Shared UI:
        ui_select_frame.png       — glowing golden frame (general selector)
        ui_locked_in_stamp.png    — rotated red "LOCKED IN" wax seal
        ui_arrow_left_normal.png  / _active.png
        ui_arrow_right_normal.png / _active.png
        ui_chip_p1.png ... ui_chip_p4.png  — small player marker chips
        ui_hint_plate.png         — parchment plate for footer hint text

    Previews:
        preview_clan_select.png
        preview_mode_select.png
        preview_map_select.png
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
#  PALETTES (matches generate_main_menu.py)
# ============================================================
# Stone (headers)
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

# Bamboo
BAMBOO_DARK = (40, 68, 38); BAMBOO_MID = (80, 130, 58)
BAMBOO_HI = (130, 178, 90); BAMBOO_NODE = (28, 48, 24)

# Text
TEXT_LIGHT = (244, 232, 196); TEXT_HOVER = (255, 232, 132)
TEXT_DARK = (28, 18, 16)

# Wax seal (LOCKED IN)
SEAL_DK = (90, 16, 14); SEAL_MD = (160, 28, 28); SEAL_HI = (210, 48, 38)
SEAL_INK = (245, 230, 210)

# Selection glow base
SELECT_GLOW = (255, 198, 90)
SELECT_RIM = (255, 232, 150)

# Clans — each clan gets primary, accent (lighter), sigil color
CLANS = {
    'shadow': {
        'primary': (130, 30, 100),   # deep magenta
        'accent':  (235, 80, 175),   # bright magenta
        'sigil':   (240, 200, 240),
        'name':    'SHADOW',
        'epithet': 'silent kage',
    },
    'storm': {
        'primary': (22, 86, 130),    # deep blue
        'accent':  (80, 210, 230),   # cyan
        'sigil':   (220, 240, 255),
        'name':    'STORM',
        'epithet': 'thunder gale',
    },
    'frost': {
        'primary': (40, 92, 50),     # deep green
        'accent':  (140, 220, 100),  # bright green
        'sigil':   (240, 255, 230),
        'name':    'FROST',
        'epithet': 'silver hail',
    },
    'fire': {
        'primary': (160, 56, 18),    # deep orange/red
        'accent':  (255, 145, 50),   # orange
        'sigil':   (255, 240, 200),
        'name':    'FIRE',
        'epithet': 'crimson ember',
    },
}
CLAN_ORDER = ['shadow', 'storm', 'frost', 'fire']

# Map dark sky for previews
PREVIEW_BG = (16, 12, 30, 255)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ============================================================
#  Helpers (noise / text / saves)
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
#  Stone text renderer (mirrors main_menu — kept inline so this
#  script can be run standalone).
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
    # rim
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
    # pits + crack
    rnd = random.Random(seed + 333)
    for _ in range(14):
        x = rnd.randint(2, w - 3); y = rnd.randint(2, h - 3)
        if mp[x, y] > 128 and mp[x, y - 1] > 128:
            sp[x, y] = rgba(PIT_DK)
            if rnd.random() < 0.6 and mp[x + 1, y] > 128:
                sp[x + 1, y] = rgba(PIT_MID)
    rnd = random.Random(seed + 555)
    for _ in range(3):
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
    # moss
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
        if pts and rnd.random() < 0.35:
            (lx, ly) = rnd.choice(list(pts))
            sp[lx, ly] = rgba(LICHEN_ORG if rnd.random() < 0.5
                              else LICHEN_WHITE)


def render_stone_text(text, font_size=48, seed=0):
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
#  HEADERS
# ============================================================
def make_headers():
    for slug, text in [
        ('header_choose_your_clan', 'CHOOSE YOUR CLAN'),
        ('header_select_mode',      'SELECT MODE'),
        ('header_choose_arena',     'CHOOSE ARENA'),
    ]:
        img = render_stone_text(text, font_size=48, seed=hash(text) & 0xffff)
        save_native_and_4x(img, slug)
        print(f'  {slug}  {img.size}')


# ============================================================
#  CLAN BANNER — vertical scroll, kanji-style sigil, name plate
# ============================================================
def _draw_sigil(d, clan_id, cx, cy, color):
    """Pixel-art sigil for each clan, drawn in `color` (with shading variants)
       centered at cx, cy. ~28x28 px sigils."""
    col = rgba(color)
    # Build a darker shade for inner depth and a lighter for highlights
    dark = (max(0, color[0] - 40), max(0, color[1] - 40),
            max(0, color[2] - 40), 255)
    bright = (min(255, color[0] + 20), min(255, color[1] + 20),
              min(255, color[2] + 20), 255)

    if clan_id == 'shadow':
        # Crescent moon (filled) + 2 small shuriken/star shapes flanking it
        r = 11
        # Filled crescent: disc minus offset disc
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    sx = dx - 4; sy = dy - 1
                    if sx * sx + sy * sy > (r - 1) * (r - 1):
                        d.point((cx + dx, cy + dy), fill=col)
        # inner shading line on inside curve
        for dy in range(-r + 2, r - 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    sx = dx - 4; sy = dy - 1
                    if sx * sx + sy * sy > (r - 1) * (r - 1):
                        # find leftmost crescent pixel for this y
                        if dx == -r + 1 or dx == -r + 2:
                            d.point((cx + dx, cy + dy), fill=dark)
                        break
        # Tiny 4-point shuriken stars (one above-right, one below-right)
        for sx_o, sy_o in [(8, -8), (8, 10)]:
            shc_x = cx + sx_o; shc_y = cy + sy_o
            # cross arms
            for off in range(-3, 4):
                d.point((shc_x + off, shc_y), fill=col)
                d.point((shc_x, shc_y + off), fill=col)
            # diagonals (smaller)
            for off in (-1, 1):
                d.point((shc_x + off, shc_y + off), fill=col)
                d.point((shc_x + off, shc_y - off), fill=col)
            # center hole
            d.point((shc_x, shc_y), fill=dark)

    elif clan_id == 'storm':
        # Bold Z-shaped lightning bolt — thick scanline-filled
        # Define the bolt as a closed polygon outline (pixel-accurate)
        bolt = [
            (-3, -13), (4, -3), (-1, -3),
            (4, 13), (-4, 3), (1, 3), (-4, -13), (-3, -13),
        ]
        # Fill polygon using ImageDraw
        d.polygon([(cx + px, cy + py) for px, py in bolt], fill=col)
        # Inner highlight — narrower second polygon offset slightly
        bolt_inner = [
            (-1, -10), (2, -3), (-1, -3),
            (2, 10), (-2, 3), (0, 3), (-2, -10), (-1, -10),
        ]
        d.polygon([(cx + px, cy + py) for px, py in bolt_inner],
                  fill=bright)
        # Bolt outline edges in darker tone (1-px rim on lower side)
        d.line([(cx - 3, cy - 13), (cx + 4, cy - 3)], fill=dark)
        d.line([(cx + 4, cy + 13), (cx - 4, cy + 3)], fill=dark)

    elif clan_id == 'frost':
        # 6-point snowflake with branching arms
        for ang_deg in range(0, 360, 60):
            a = math.radians(ang_deg)
            for r in range(0, 13):
                px_ = cx + int(math.cos(a) * r)
                py_ = cy + int(math.sin(a) * r)
                d.point((px_, py_), fill=col)
            # Side branches at r=6 and r=10
            for branch_r, branch_len in [(6, 3), (10, 2)]:
                bx = cx + math.cos(a) * branch_r
                by = cy + math.sin(a) * branch_r
                for side in (-1, 1):
                    sa = a + math.pi / 3 * side
                    for sr in range(1, branch_len + 1):
                        px_ = int(bx + math.cos(sa) * sr)
                        py_ = int(by + math.sin(sa) * sr)
                        d.point((px_, py_), fill=col)
            # Arrowhead tip at r=12
            for off in (-2, -1, 1, 2):
                tx = cx + int(math.cos(a) * 11 + math.cos(a + math.pi / 2) * off)
                ty = cy + int(math.sin(a) * 11 + math.sin(a + math.pi / 2) * off)
                d.point((tx, ty), fill=col)
        # Bright center hexagon
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if abs(dx) + abs(dy) <= 2:
                    d.point((cx + dx, cy + dy), fill=bright)
        d.point((cx, cy), fill=col)

    elif clan_id == 'fire':
        # Classic teardrop flame with 2-tone layered coloring.
        # Outer flame: bright/lighter cream/yellow color (the `color` passed in)
        # Inner core: deeper red/orange for depth
        deep_red = (200, 50, 18, 255)
        bright_yellow = (255, 240, 160, 255)

        # Outer flame shape — drawn as solid via scanline
        # tear-drop: narrow at top, bulges in middle, flame curl at base
        def outer_w(y):
            # y in [-14, 12]
            if y <= -12:
                return 1
            if y < -6:
                return int(2 + (y + 12) * 0.6)
            if y < 0:
                return int(5 + (y + 6) * 0.3)
            if y < 6:
                return int(7 - (y) * 0.3)
            if y < 10:
                return int(5 - (y - 6) * 0.7)
            return 1

        for fy in range(-14, 13):
            w = outer_w(fy)
            # Slight asymmetric wobble (flames flicker)
            wobble = int(math.sin(fy * 0.7) * 1.2)
            for fx in range(-w + wobble, w + wobble + 1):
                d.point((cx + fx, cy + fy), fill=col)

        # Inner core — deeper red flame inside
        def core_w(y):
            if y <= -7:
                return 0
            if y < -4:
                return int(1 + (y + 7) * 0.5)
            if y < 2:
                return int(2 + (y + 4) * 0.3)
            if y < 6:
                return int(3 - y * 0.2)
            if y < 9:
                return int(2 - (y - 6) * 0.5)
            return 0

        for fy in range(-7, 10):
            w = core_w(fy)
            if w <= 0: continue
            wobble = int(math.sin(fy * 0.7) * 0.8)
            for fx in range(-w + wobble, w + wobble + 1):
                d.point((cx + fx, cy + fy), fill=deep_red)

        # White-hot core — tiny bright spark in lower-middle
        for dy in range(2, 6):
            for dx in range(-1, 2):
                if abs(dx) + abs(dy - 4) <= 2:
                    d.point((cx + dx, cy + dy), fill=bright_yellow)


def render_clan_banner(clan_id, selected=False, with_name=True, with_sigil=True):
    """Vertical scroll/banner — 80x130 native (4x = 320x520).
       Hanging rod top, fabric body in clan color, sigil, name plate.
       with_name=False omits the baked name plate; with_sigil=False omits the clan emblem —
       the clan-select screen shows a character centered on a clean banner with the name as a
       label below it instead."""
    pal = CLANS[clan_id]
    W, H = 80, 130
    margin = 10
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    ox, oy = margin, margin

    # Outer glow when selected (drawn first, behind everything)
    if selected:
        glow = Image.new('RGBA', (cw, ch), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        for grow in (8, 5, 2):
            gd.rounded_rectangle(
                [ox - grow, oy - grow,
                 ox + W + grow, oy + H + grow],
                radius=4 + grow,
                fill=(*pal['accent'], 35 if grow == 8 else
                                       60 if grow == 5 else 90))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=3))
        canvas.alpha_composite(glow)

    # Drop shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rectangle([ox + 3, oy + 6, ox + W + 3, oy + H + 6],
                 fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=3))
    canvas.alpha_composite(sh)

    # ---- Top hanging rod (dark wood with rope ties) ----
    rod_y = oy + 4
    rod_h = 6
    d.rectangle([ox - 2, rod_y, ox + W + 1, rod_y + rod_h - 1],
                fill=rgba(WOOD_DK))
    d.line([(ox - 2, rod_y), (ox + W + 1, rod_y)],
           fill=rgba(WOOD_HI))
    d.line([(ox - 2, rod_y + rod_h - 1), (ox + W + 1, rod_y + rod_h - 1)],
           fill=rgba(WOOD_EDGE))
    # rod end caps
    d.rectangle([ox - 4, rod_y - 1, ox - 2, rod_y + rod_h],
                fill=rgba(WOOD_HI))
    d.rectangle([ox + W + 1, rod_y - 1, ox + W + 3, rod_y + rod_h],
                fill=rgba(WOOD_HI))

    # Rope ties hanging from rod to body top
    body_top = rod_y + rod_h + 4
    for rx in (ox + 10, ox + W - 12):
        # tie wraps around rod
        d.rectangle([rx - 2, rod_y - 1, rx + 2, rod_y + rod_h],
                    fill=rgba(ROPE_DK))
        for ty in range(rod_y - 1, rod_y + rod_h):
            stripe = (ty // 2) % 2
            col = ROPE_COL if stripe == 0 else ROPE_DK
            for tx in range(rx - 2, rx + 3):
                d.point((tx, ty), fill=rgba(col))
        # hanging rope down to body
        for ry in range(rod_y + rod_h, body_top):
            d.point((rx, ry), fill=rgba(ROPE_DK))
            d.point((rx + 1, ry), fill=rgba(ROPE_COL))

    # ---- Body: cloth in clan primary, with woven texture noise ----
    body_h = H - (body_top - oy) - 4
    body_x0 = ox + 2
    body_x1 = ox + W - 2
    body_y0 = body_top
    body_y1 = body_top + body_h

    # Body fill with subtle two-tone weave
    for y in range(body_y0, body_y1):
        for x in range(body_x0, body_x1):
            # primary color with darker accent in horizontal stripes
            stripe = (y % 4)
            if stripe == 0:
                col = pal['primary']
                col = (max(0, col[0] - 14), max(0, col[1] - 14),
                       max(0, col[2] - 14))
            elif stripe == 2:
                col = pal['primary']
            else:
                col = pal['primary']
                col = (max(0, col[0] - 6), max(0, col[1] - 6),
                       max(0, col[2] - 6))
            # subtle vertical noise
            n = (math.sin(x * 0.6 + y * 0.21) * 0.5 + 0.5) * 8 - 4
            r = max(0, min(255, int(col[0] + n)))
            g = max(0, min(255, int(col[1] + n * 0.7)))
            b = max(0, min(255, int(col[2] + n * 0.5)))
            d.point((x, y), fill=(r, g, b, 255))

    # Border (dark frame around body)
    d.rectangle([body_x0, body_y0, body_x1 - 1, body_y1 - 1],
                outline=rgba(WOOD_EDGE), width=1)
    # Top edge highlight
    d.line([(body_x0 + 1, body_y0 + 1),
            (body_x1 - 2, body_y0 + 1)],
           fill=(*pal['accent'], 120))

    # Bottom triangular fringe (banner-tail cut)
    fringe_y = body_y1 - 5
    for x in range(body_x0, body_x1):
        # zigzag tail — every 6 px a notch
        offset = (x - body_x0) % 6
        depth = abs(offset - 3)
        notch_y = fringe_y + depth
        # erase pixels below notch
        for ny in range(notch_y, body_y1):
            d.point((x, ny), fill=TRANSPARENT)

    # ---- Sigil in upper-middle (skipped when with_sigil=False) ----
    if with_sigil:
        sigil_cy = body_y0 + 26
        sigil_cx = (body_x0 + body_x1) // 2
        _draw_sigil(d, clan_id, sigil_cx, sigil_cy, pal['sigil'])

    # ---- Name plate at lower section of body (skipped when with_name=False) ----
    if with_name:
        name = pal['name']
        font = ImageFont.truetype(FONT_BLACK, 12)
        name_bb = font.getbbox(name)
        name_w = name_bb[2] - name_bb[0]
        name_h = name_bb[3] - name_bb[1]
        plate_x0 = (body_x0 + body_x1) // 2 - name_w // 2 - 4
        plate_x1 = (body_x0 + body_x1) // 2 + name_w // 2 + 4
        plate_y0 = body_y0 + 56
        plate_y1 = plate_y0 + name_h + 4
        # plate background
        d.rectangle([plate_x0, plate_y0, plate_x1, plate_y1],
                    fill=rgba(WOOD_DK))
        d.rectangle([plate_x0, plate_y0, plate_x1, plate_y1],
                    outline=rgba(WOOD_EDGE), width=1)
        # plate text
        d.text((plate_x0 + 4 - name_bb[0],
                plate_y0 + 2 - name_bb[1]),
               name, font=font, fill=rgba(TEXT_LIGHT))

    return canvas


# ============================================================
#  MODE TILE — wooden plaque with ninja silhouettes + label
# ============================================================
def _draw_ninja_silhouette(d, cx, cy, facing=1, color=(20, 18, 30),
                           accent=(245, 230, 210), is_bot=False):
    """Tiny ninja silhouette ~10 px tall. facing: 1=right, -1=left."""
    body_col = rgba(color)
    accent_col = rgba(accent)
    # head (round-ish 5x5)
    d.rectangle([cx - 2, cy - 5, cx + 2, cy - 2], fill=body_col)
    d.rectangle([cx - 3, cy - 4, cx + 3, cy - 3], fill=body_col)
    # eye band (accent stripe across face)
    d.line([(cx - 3, cy - 4), (cx + 3, cy - 4)], fill=accent_col)
    if is_bot:
        # red glowing single eye
        d.point((cx + facing, cy - 4), fill=(255, 80, 60, 255))
        d.point((cx + facing * 2, cy - 4), fill=(255, 80, 60, 255))
        # antenna
        d.point((cx, cy - 6), fill=accent_col)
        d.point((cx, cy - 7), fill=rgba((255, 60, 60)))
    else:
        # cloth tie streamer (back)
        d.point((cx - 4 * facing, cy - 5), fill=accent_col)
        d.point((cx - 5 * facing, cy - 4), fill=accent_col)
    # body torso
    d.rectangle([cx - 2, cy - 1, cx + 2, cy + 2], fill=body_col)
    d.rectangle([cx - 3, cy + 1, cx + 3, cy + 3], fill=body_col)
    # belt accent
    d.line([(cx - 2, cy + 1), (cx + 2, cy + 1)], fill=accent_col)
    # legs
    d.line([(cx - 1, cy + 3), (cx - 2, cy + 6)], fill=body_col)
    d.line([(cx + 1, cy + 3), (cx + 2, cy + 6)], fill=body_col)
    # arms (one extended forward = ready)
    d.line([(cx + facing * 2, cy), (cx + facing * 4, cy + 1)],
           fill=body_col)
    d.line([(cx - facing, cy), (cx - facing * 2, cy + 2)],
           fill=body_col)


def render_mode_tile(slug, label, sub, ninjas, selected=False,
                     accent_color=(255, 180, 80)):
    """ninjas: list of (relative_x, facing, is_bot) tuples."""
    W, H = 120, 88
    margin = 12
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # Glow when selected
    if selected:
        glow = Image.new('RGBA', (cw, ch), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        for grow in (8, 5, 2):
            gd.rounded_rectangle(
                [margin - grow, margin - grow,
                 margin + W + grow, margin + H + grow],
                radius=6 + grow,
                fill=(*accent_color,
                      40 if grow == 8 else 70 if grow == 5 else 100))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=3))
        canvas.alpha_composite(glow)

    # Drop shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([margin + 2, margin + 5,
                          margin + W + 4, margin + H + 5],
                         radius=6, fill=(0, 0, 0, 130))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=2.5))
    canvas.alpha_composite(sh)

    # Plank body (vertical gradient like buttons)
    body = Image.new('RGBA', (W, H), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    for y in range(H):
        t = y / (H - 1)
        if t < 0.5:
            tt = t / 0.5
            r = int(WOOD_HI[0] + (WOOD_MD[0] - WOOD_HI[0]) * tt)
            g = int(WOOD_HI[1] + (WOOD_MD[1] - WOOD_HI[1]) * tt)
            b = int(WOOD_HI[2] + (WOOD_MD[2] - WOOD_HI[2]) * tt)
        else:
            tt = (t - 0.5) / 0.5
            r = int(WOOD_MD[0] + (WOOD_DK[0] - WOOD_MD[0]) * tt)
            g = int(WOOD_MD[1] + (WOOD_DK[1] - WOOD_MD[1]) * tt)
            b = int(WOOD_MD[2] + (WOOD_DK[2] - WOOD_MD[2]) * tt)
        bd.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))
    # Grain lines
    rnd = random.Random(hash(slug) & 0xffff)
    for _ in range(8):
        gy = rnd.randint(2, H - 3)
        gx0 = rnd.randint(0, 8); gx1 = W - rnd.randint(0, 8)
        bd.line([(gx0, gy), (gx1, gy)],
                fill=(*WOOD_GRAIN_HI, 110))
    # Inner shading at edges
    bd.line([(0, 0), (W - 1, 0)], fill=rgba(WOOD_HI))
    bd.line([(0, H - 1), (W - 1, H - 1)], fill=rgba(WOOD_EDGE))
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=4,
                         outline=rgba(WOOD_EDGE), width=1)
    # Round corners by alpha mask
    mask = Image.new('L', (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, W - 1, H - 1], radius=4, fill=255)
    body.putalpha(mask)

    # Inset stage area (sunken panel where silhouettes appear)
    stage_x0, stage_y0 = 8, 8
    stage_x1, stage_y1 = W - 8, 46
    # Dark inset
    inset = Image.new('RGBA',
                      (stage_x1 - stage_x0, stage_y1 - stage_y0),
                      (16, 12, 28, 255))
    insd = ImageDraw.Draw(inset)
    # gradient ground
    iw, ih = inset.size
    for y in range(ih):
        t = y / max(1, ih - 1)
        r = int(16 + (52 - 16) * t)
        g = int(12 + (38 - 12) * t)
        b = int(28 + (62 - 28) * t)
        insd.line([(0, y), (iw - 1, y)], fill=(r, g, b, 255))
    # tiny ground tile floor
    insd.line([(0, ih - 2), (iw - 1, ih - 2)], fill=(72, 50, 38, 255))
    insd.line([(0, ih - 1), (iw - 1, ih - 1)], fill=(40, 26, 18, 255))
    # paste into body
    body.alpha_composite(inset, (stage_x0, stage_y0))
    # frame around stage
    bd.rectangle([stage_x0 - 1, stage_y0 - 1,
                  stage_x1, stage_y1],
                 outline=rgba(WOOD_EDGE), width=1)

    # Draw ninjas inside stage
    stage_cx = (stage_x0 + stage_x1) // 2
    stage_floor = stage_y1 - 5
    for rel_x, facing, is_bot in ninjas:
        # bot uses a metallic tint; ninja uses dark + accent
        if is_bot:
            color = (40, 38, 60)
            accent = (210, 220, 230)
        else:
            color = (12, 12, 22)
            accent = (245, 230, 210)
        _draw_ninja_silhouette(bd,
                               stage_cx + rel_x, stage_floor,
                               facing=facing, color=color,
                               accent=accent, is_bot=is_bot)

    # Label text below stage
    font = ImageFont.truetype(FONT_BLACK, 14)
    sub_font = ImageFont.truetype(FONT_BOLD, 9)
    bb = font.getbbox(label)
    tw = bb[2] - bb[0]
    tx = (W - tw) // 2 - bb[0]
    ty = stage_y1 + 6 - bb[1]
    bd.text((tx + 1, ty + 1), label, font=font, fill=(0, 0, 0, 200))
    bd.text((tx, ty), label, font=font,
            fill=rgba(TEXT_HOVER if selected else TEXT_LIGHT))
    # subtitle below
    sbb = sub_font.getbbox(sub)
    swdt = sbb[2] - sbb[0]
    sx_ = (W - swdt) // 2 - sbb[0]
    sy_ = stage_y1 + 22 - sbb[1]
    bd.text((sx_, sy_), sub, font=sub_font,
            fill=(*TEXT_LIGHT, 200))

    canvas.alpha_composite(body, (margin, margin))
    return canvas


# ============================================================
#  AI DIFFICULTY STAMPS (GENIN / CHUNIN / JONIN)
# ============================================================
def render_difficulty_stamp(rank_label, rank_subtitle, dots, accent):
    """Calligraphy-style rank seal: dark wooden tablet with rank text +
       N filled dots (1=Genin, 2=Chunin, 3=Jonin)."""
    W, H = 96, 30
    margin = 10
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # Shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([margin + 2, margin + 3,
                          margin + W + 3, margin + H + 3],
                         radius=3, fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=2))
    canvas.alpha_composite(sh)

    # Tablet body
    body = Image.new('RGBA', (W, H), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    for y in range(H):
        t = y / (H - 1)
        r = int(38 + (22 - 38) * t)
        g = int(26 + (16 - 26) * t)
        b = int(50 + (32 - 50) * t)
        bd.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))
    # accent border (clan-style accent color)
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=3,
                         outline=rgba(accent), width=1)
    bd.rounded_rectangle([1, 1, W - 2, H - 2], radius=2,
                         outline=(0, 0, 0, 200), width=1)
    # round corner mask
    mask = Image.new('L', (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, W - 1, H - 1], radius=3, fill=255)
    body.putalpha(mask)

    # Text — rank label on left, subtitle on right
    font = ImageFont.truetype(FONT_BLACK, 14)
    sub_font = ImageFont.truetype(FONT_BOLD, 8)
    bb = font.getbbox(rank_label)
    bd.text((8 - bb[0], 4 - bb[1]), rank_label, font=font,
            fill=rgba(accent))
    sbb = sub_font.getbbox(rank_subtitle)
    bd.text((8 - sbb[0], 18 - sbb[1]), rank_subtitle, font=sub_font,
            fill=(*TEXT_LIGHT, 200))

    # Dots on right side — N filled, 3-N hollow
    dot_y = H // 2
    dot_x_start = W - 24
    for i in range(3):
        cx = dot_x_start + i * 7
        if i < dots:
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    if dx * dx + dy * dy <= 4:
                        bd.point((cx + dx, dot_y + dy),
                                 fill=rgba(accent))
        else:
            for ang in range(0, 360, 30):
                a = math.radians(ang)
                px_ = cx + int(math.cos(a) * 2.5)
                py_ = dot_y + int(math.sin(a) * 2.5)
                bd.point((px_, py_), fill=(*accent, 140))

    canvas.alpha_composite(body, (margin, margin))
    return canvas


# ============================================================
#  MAP FRAME + MAP NAMEPLATE + MAP PREVIEW THUMBNAIL
# ============================================================
def render_map_frame(selected=False):
    """Wooden frame around an inner area for the map preview.
       Outer 200x150 native, with a 12-px wood border."""
    W, H = 200, 150
    border = 10
    margin = 14
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # Glow when selected
    if selected:
        glow = Image.new('RGBA', (cw, ch), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        for grow in (10, 6, 3):
            gd.rounded_rectangle(
                [margin - grow, margin - grow,
                 margin + W + grow, margin + H + grow],
                radius=8 + grow,
                fill=(*SELECT_GLOW,
                      35 if grow == 10 else 60 if grow == 6 else 95))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=4))
        canvas.alpha_composite(glow)

    # Drop shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([margin + 2, margin + 5,
                          margin + W + 3, margin + H + 5],
                         radius=8, fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=2.5))
    canvas.alpha_composite(sh)

    # Outer wood frame
    body = Image.new('RGBA', (W, H), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    # Frame: vertical gradient
    for y in range(H):
        t = y / (H - 1)
        if t < 0.5:
            tt = t / 0.5
            r = int(WOOD_HI[0] + (WOOD_MD[0] - WOOD_HI[0]) * tt)
            g = int(WOOD_HI[1] + (WOOD_MD[1] - WOOD_HI[1]) * tt)
            b = int(WOOD_HI[2] + (WOOD_MD[2] - WOOD_HI[2]) * tt)
        else:
            tt = (t - 0.5) / 0.5
            r = int(WOOD_MD[0] + (WOOD_DK[0] - WOOD_MD[0]) * tt)
            g = int(WOOD_MD[1] + (WOOD_DK[1] - WOOD_MD[1]) * tt)
            b = int(WOOD_MD[2] + (WOOD_DK[2] - WOOD_MD[2]) * tt)
        bd.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))
    # Grain
    rnd = random.Random(11)
    for _ in range(14):
        gy = rnd.randint(2, H - 3)
        gx0 = rnd.randint(0, 18); gx1 = W - rnd.randint(0, 18)
        bd.line([(gx0, gy), (gx1, gy)],
                fill=(*WOOD_GRAIN_HI, 100))
    # Edges
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=6,
                         outline=rgba(WOOD_EDGE), width=1)
    # Cut out inner panel (will be filled by map preview)
    inner_pad = 8
    bd.rectangle([inner_pad, inner_pad,
                  W - inner_pad - 1, H - inner_pad - 1],
                 fill=(8, 6, 16, 255))
    bd.rectangle([inner_pad, inner_pad,
                  W - inner_pad - 1, H - inner_pad - 1],
                 outline=rgba(WOOD_EDGE), width=1)
    # Decorative corner pins (iron nails)
    for cx, cy in [(inner_pad + 4, inner_pad + 4),
                   (W - inner_pad - 5, inner_pad + 4),
                   (inner_pad + 4, H - inner_pad - 5),
                   (W - inner_pad - 5, H - inner_pad - 5)]:
        bd.ellipse([cx - 2, cy - 2, cx + 2, cy + 2],
                   fill=rgba(WOOD_EDGE))
        bd.point((cx - 1, cy - 1), fill=(170, 165, 175, 255))

    # Mask round corners
    mask = Image.new('L', (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, W - 1, H - 1], radius=6, fill=255)
    body.putalpha(mask)
    canvas.alpha_composite(body, (margin, margin))
    return canvas


def render_map_preview_sakura():
    """Pixel-art preview thumbnail of Sakura Temple — matches the
       in-game arena: side walls, floating platforms, dark moonlit
       sky, hint of pagoda silhouette and 2 spawn markers."""
    W, H = 184, 134
    img = Image.new('RGBA', (W, H), (10, 8, 26, 255))
    d = ImageDraw.Draw(img)
    # sky gradient
    for y in range(H):
        t = y / (H - 1)
        r = int(10 + (58 - 10) * t)
        g = int(8 + (52 - 8) * t)
        b = int(26 + (88 - 26) * t)
        d.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))
    # tiny moon
    d.ellipse([W - 30, 8, W - 18, 20], fill=(250, 244, 218, 255))
    # tiny pagoda silhouette
    px = W // 2
    py = H - 50
    for tier_i, (bw, bh) in enumerate([(18, 6), (15, 5), (12, 4)]):
        ty = py - tier_i * 9
        d.rectangle([px - bw, ty - bh, px + bw, ty],
                    fill=(28, 22, 42, 255))
        d.polygon([(px - bw - 2, ty - bh + 1),
                   (px - bw + 1, ty - bh - 2),
                   (px + bw - 1, ty - bh - 2),
                   (px + bw + 2, ty - bh + 1)],
                  fill=(52, 28, 40, 255))
        # window
        d.point((px, ty - bh // 2), fill=(255, 178, 78, 255))
    # ---- side walls ----
    wall_col = (58, 50, 68, 255)
    wall_edge = (104, 92, 122, 255)
    d.rectangle([0, 0, 14, H], fill=wall_col)
    d.line([(14, 0), (14, H)], fill=wall_edge)
    d.rectangle([W - 14, 0, W - 1, H], fill=wall_col)
    d.line([(W - 15, 0), (W - 15, H)], fill=wall_edge)
    # ---- floating platforms ----
    platforms = [
        (92, 22, 32),    # top center
        (50, 42, 38),    # upper left
        (134, 42, 38),   # upper right
        (92, 58, 30),    # mid center
        (46, 68, 26),    # mid left
        (138, 68, 26),   # mid right
        (54, 86, 42),    # lower left
        (130, 86, 42),   # lower right
        (92, 99, 36),    # bottom center
    ]
    for (cx, cy, pw) in platforms:
        d.rectangle([cx - pw // 2, cy, cx + pw // 2, cy + 3],
                    fill=(168, 158, 184, 255))
        d.rectangle([cx - pw // 2, cy + 3, cx + pw // 2, cy + 4],
                    fill=(96, 88, 116, 255))
    # spawn markers (yellow dots on lower platforms)
    for sx, sy in [(54, 82), (130, 82)]:
        d.point((sx, sy), fill=(255, 220, 80, 255))
        d.point((sx + 1, sy), fill=(255, 240, 140, 255))

    return img


def render_map_nameplate(name, subtitle):
    """Large wooden plaque with map name + subtitle."""
    font_name = ImageFont.truetype(FONT_BLACK, 18)
    font_sub = ImageFont.truetype(FONT_BOLD, 10)
    nbb = font_name.getbbox(name)
    sbb = font_sub.getbbox(subtitle)
    name_w = nbb[2] - nbb[0]; name_h = nbb[3] - nbb[1]
    sub_w = sbb[2] - sbb[0]; sub_h = sbb[3] - sbb[1]
    W = max(name_w, sub_w) + 32
    H = name_h + sub_h + 18
    margin = 10
    cw = W + margin * 2; ch = H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # Shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([margin + 2, margin + 4,
                          margin + W + 3, margin + H + 4],
                         radius=4, fill=(0, 0, 0, 130))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=2))
    canvas.alpha_composite(sh)

    body = Image.new('RGBA', (W, H), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    for y in range(H):
        t = y / (H - 1)
        if t < 0.5:
            tt = t / 0.5
            r = int(WOOD_HI[0] + (WOOD_MD[0] - WOOD_HI[0]) * tt)
            g = int(WOOD_HI[1] + (WOOD_MD[1] - WOOD_HI[1]) * tt)
            b = int(WOOD_HI[2] + (WOOD_MD[2] - WOOD_HI[2]) * tt)
        else:
            tt = (t - 0.5) / 0.5
            r = int(WOOD_MD[0] + (WOOD_DK[0] - WOOD_MD[0]) * tt)
            g = int(WOOD_MD[1] + (WOOD_DK[1] - WOOD_MD[1]) * tt)
            b = int(WOOD_MD[2] + (WOOD_DK[2] - WOOD_MD[2]) * tt)
        bd.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=4,
                         outline=rgba(WOOD_EDGE), width=1)
    # mask corners
    mask = Image.new('L', (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, W - 1, H - 1], radius=4, fill=255)
    body.putalpha(mask)

    # Name (large)
    nx = (W - name_w) // 2 - nbb[0]
    ny = 4 - nbb[1]
    bd.text((nx + 1, ny + 1), name, font=font_name, fill=(0, 0, 0, 180))
    bd.text((nx, ny), name, font=font_name, fill=rgba(TEXT_HOVER))
    # Subtitle (small italic feel)
    sx_ = (W - sub_w) // 2 - sbb[0]
    sy_ = 6 + name_h - sbb[1]
    bd.text((sx_, sy_), subtitle, font=font_sub,
            fill=(*TEXT_LIGHT, 220))

    canvas.alpha_composite(body, (margin, margin))
    return canvas


# ============================================================
#  SHARED UI: selection frame, LOCKED IN stamp, arrows, P# chips,
#  hint plate
# ============================================================
def render_select_frame():
    """Pure overlay: golden glowing rectangle frame with corners
       designed to scale via NinePatchRect (we keep the corners crisp).
       Native 24x24 — use Godot NinePatchRect with patch_margin=8."""
    W, H = 24, 24
    img = Image.new('RGBA', (W, H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    # outer glow halo
    for grow, alpha in [(3, 40), (2, 80), (1, 140)]:
        d.rectangle([grow, grow, W - 1 - grow, H - 1 - grow],
                    outline=(*SELECT_GLOW, alpha))
    # crisp rim
    d.rectangle([0, 0, W - 1, H - 1],
                outline=rgba(SELECT_RIM), width=1)
    # inner soft glow line
    d.rectangle([2, 2, W - 3, H - 3], outline=(*SELECT_GLOW, 180))
    return img


def render_locked_in_stamp():
    """Round red wax-seal stamp with 'LOCKED IN' text, rotated 12°."""
    W, H = 90, 90
    base = Image.new('RGBA', (W, H), TRANSPARENT)
    d = ImageDraw.Draw(base)
    cx, cy = W // 2, H // 2
    r = 36
    # outer wax ring
    for rr in range(r, r - 4, -1):
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                  outline=rgba(SEAL_DK), width=1)
    # filled red interior
    d.ellipse([cx - r + 4, cy - r + 4,
               cx + r - 4, cy + r - 4],
              fill=rgba(SEAL_MD))
    # highlight (upper-left)
    for rr in range(r - 6, r - 12, -1):
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr],
              start=200, end=300, fill=rgba(SEAL_HI), width=2)
    # inner ring
    d.ellipse([cx - r + 8, cy - r + 8,
               cx + r - 8, cy + r - 8],
              outline=rgba(SEAL_DK), width=1)
    # Text "LOCKED IN" — split into two lines so it fits in a circle
    font1 = ImageFont.truetype(FONT_BLACK, 12)
    font2 = ImageFont.truetype(FONT_BLACK, 14)
    line1 = 'LOCKED'
    line2 = 'IN'
    bb1 = font1.getbbox(line1)
    bb2 = font2.getbbox(line2)
    w1 = bb1[2] - bb1[0]; w2 = bb2[2] - bb2[0]
    d.text((cx - w1 // 2 - bb1[0], cy - 12 - bb1[1]),
           line1, font=font1, fill=rgba(SEAL_INK))
    d.text((cx - w2 // 2 - bb2[0], cy + 1 - bb2[1]),
           line2, font=font2, fill=rgba(SEAL_INK))
    # tiny stars on each side
    for ox, oy in [(-26, 0), (26, 0)]:
        for dx in (-1, 0, 1):
            d.point((cx + ox + dx, cy + oy), fill=rgba(SEAL_INK))
        for dy in (-1, 0, 1):
            d.point((cx + ox, cy + oy + dy), fill=rgba(SEAL_INK))

    # Rotate -12° for that "slammed down" look (PIL rotate)
    rotated = base.rotate(-12, resample=Image.BICUBIC,
                          fillcolor=TRANSPARENT)
    return rotated


def render_arrow(direction, active=False):
    """direction: 'left' | 'right' | 'up' | 'down'. Native 18x16."""
    W, H = 20, 18
    img = Image.new('RGBA', (W, H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    col = SELECT_RIM if active else (200, 196, 220)
    edge = (24, 18, 32)
    cx, cy = W // 2, H // 2
    pts = {
        'left':  [(cx - 6, cy), (cx + 4, cy - 6), (cx + 4, cy + 6)],
        'right': [(cx + 6, cy), (cx - 4, cy - 6), (cx - 4, cy + 6)],
        'up':    [(cx, cy - 6), (cx - 6, cy + 4), (cx + 6, cy + 4)],
        'down':  [(cx, cy + 6), (cx - 6, cy - 4), (cx + 6, cy - 4)],
    }[direction]
    # outline
    d.polygon(pts, fill=rgba(col), outline=rgba(edge))
    if active:
        # outer glow
        glow = Image.new('RGBA', (W, H), TRANSPARENT)
        gd = ImageDraw.Draw(glow)
        gd.polygon(pts, fill=(*SELECT_GLOW, 120))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=2.5))
        out = Image.new('RGBA', (W, H), TRANSPARENT)
        out.alpha_composite(glow)
        out.alpha_composite(img)
        return out
    return img


def render_player_chip(slot, clan_id):
    """Small triangular chip pointing UP, labeled 'P{slot}' in clan color."""
    pal = CLANS[clan_id]
    W, H = 28, 22
    img = Image.new('RGBA', (W, H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    # Triangle pointer at top
    d.polygon([(W // 2, 0), (W // 2 - 4, 5), (W // 2 + 4, 5)],
              fill=rgba(pal['accent']),
              outline=(*WOOD_EDGE, 255))
    # Chip body
    d.rounded_rectangle([2, 5, W - 3, H - 1], radius=2,
                        fill=rgba(pal['primary']),
                        outline=rgba(WOOD_EDGE))
    # Inner highlight
    d.line([(3, 6), (W - 4, 6)], fill=rgba(pal['accent']))
    # Label
    font = ImageFont.truetype(FONT_BLACK, 10)
    label = f'P{slot}'
    bb = font.getbbox(label)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    tx = (W - tw) // 2 - bb[0]
    ty = 6 + (H - 6 - th) // 2 - bb[1]
    d.text((tx, ty), label, font=font, fill=rgba(TEXT_LIGHT))
    return img


def render_hint_plate(text):
    """Parchment-style horizontal plate for footer hint text."""
    font = ImageFont.truetype(FONT_BOLD, 10)
    bb = font.getbbox(text)
    tw = bb[2] - bb[0]; th = bb[3] - bb[1]
    pad_x, pad_y = 14, 5
    W = tw + pad_x * 2
    H = th + pad_y * 2 + 2
    margin = 8
    cw, ch = W + margin * 2, H + margin * 2
    canvas = Image.new('RGBA', (cw, ch), TRANSPARENT)

    # shadow
    sh = Image.new('RGBA', (cw, ch), TRANSPARENT)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([margin + 1, margin + 2,
                          margin + W + 1, margin + H + 2],
                         radius=2, fill=(0, 0, 0, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(radius=1.5))
    canvas.alpha_composite(sh)

    # parchment body — warm cream with subtle noise
    body = Image.new('RGBA', (W, H), TRANSPARENT)
    bd = ImageDraw.Draw(body)
    for y in range(H):
        for x in range(W):
            n = (math.sin(x * 0.4 + y * 0.7) * 0.5 + 0.5) * 10 - 5
            r = max(0, min(255, int(216 + n)))
            g = max(0, min(255, int(196 + n * 0.7)))
            b = max(0, min(255, int(148 + n * 0.5)))
            bd.point((x, y), fill=(r, g, b, 255))
    bd.rounded_rectangle([0, 0, W - 1, H - 1], radius=2,
                         outline=rgba(WOOD_EDGE), width=1)
    # Text
    bd.text((pad_x - bb[0], pad_y - bb[1]),
            text, font=font, fill=rgba(TEXT_DARK))
    canvas.alpha_composite(body, (margin, margin))
    return canvas


# ============================================================
#  MAIN
# ============================================================
def generate_all():
    print('=== HEADERS ===')
    make_headers()

    print('\n=== CLAN BANNERS ===')
    for c in CLAN_ORDER:
        normal = render_clan_banner(c, selected=False)
        save_native_and_4x(normal, f'clan_{c}')
        sel = render_clan_banner(c, selected=True)
        save_native_and_4x(sel, f'clan_{c}_selected')
        print(f'  clan_{c} + _selected   ({normal.size})')

    print('\n=== MODE TILES ===')
    # ninja layout per mode: (rel_x, facing, is_bot)
    modes = [
        ('mode_p1_vs_p2', 'P1 vs P2', 'two players, one couch',
         [(-12, 1, False), (12, -1, False)],
         (255, 145, 50)),
        ('mode_p1_vs_ai', 'P1 vs AI', 'beat the bot',
         [(-12, 1, False), (12, -1, True)],
         (80, 210, 230)),
        ('mode_ai_vs_ai', 'AI vs AI', 'watch a demo',
         [(-12, 1, True), (12, -1, True)],
         (235, 80, 175)),
        ('mode_p1_vs_3',  'P1 vs 3',  'free-for-all',
         [(-20, 1, False), (-2, -1, True), (10, -1, True),
          (22, -1, True)],
         (140, 220, 100)),
    ]
    for slug, label, sub, ninjas, accent in modes:
        normal = render_mode_tile(slug, label, sub, ninjas,
                                  selected=False, accent_color=accent)
        save_native_and_4x(normal, slug)
        sel = render_mode_tile(slug, label, sub, ninjas,
                               selected=True, accent_color=accent)
        save_native_and_4x(sel, f'{slug}_selected')
        print(f'  {slug} + _selected   ({normal.size})')

    print('\n=== AI DIFFICULTY STAMPS ===')
    for slug, lbl, sub, dots, accent in [
        ('diff_genin',  'GENIN',  'novice',  1, (140, 220, 100)),
        ('diff_chunin', 'CHUNIN', 'adept',   2, (255, 198, 90)),
        ('diff_jonin',  'JONIN',  'master',  3, (255, 100, 80)),
    ]:
        img = render_difficulty_stamp(lbl, sub, dots, accent)
        save_native_and_4x(img, slug)
        print(f'  {slug}   ({img.size})')

    print('\n=== MAP SELECT ===')
    frame = render_map_frame(selected=False)
    save_native_and_4x(frame, 'map_frame_normal')
    print(f'  map_frame_normal   ({frame.size})')
    frame_sel = render_map_frame(selected=True)
    save_native_and_4x(frame_sel, 'map_frame_selected')
    print(f'  map_frame_selected ({frame_sel.size})')
    sakura = render_map_preview_sakura()
    save_native_and_4x(sakura, 'map_sakura_temple')
    print(f'  map_sakura_temple  ({sakura.size})')
    plate = render_map_nameplate('SAKURA TEMPLE', 'moonlit shinobi sanctum')
    save_native_and_4x(plate, 'map_nameplate_sakura')
    print(f'  map_nameplate_sakura ({plate.size})')

    print('\n=== SHARED UI ===')
    sf = render_select_frame()
    save_native_and_4x(sf, 'ui_select_frame')
    print(f'  ui_select_frame   ({sf.size})')

    ls = render_locked_in_stamp()
    save_native_and_4x(ls, 'ui_locked_in_stamp')
    print(f'  ui_locked_in_stamp ({ls.size})')

    for direction in ('left', 'right', 'up', 'down'):
        normal = render_arrow(direction, active=False)
        save_native_and_4x(normal, f'ui_arrow_{direction}_normal')
        active = render_arrow(direction, active=True)
        save_native_and_4x(active, f'ui_arrow_{direction}_active')
    print('  ui_arrow_(left/right/up/down)_(normal/active) × 8')

    # P1/P2/P3/P4 marker chips, each in their default clan color
    default_clan_for_slot = {1: 'fire', 2: 'storm', 3: 'frost', 4: 'shadow'}
    for slot in (1, 2, 3, 4):
        chip = render_player_chip(slot, default_clan_for_slot[slot])
        save_native_and_4x(chip, f'ui_chip_p{slot}')
    print('  ui_chip_p1..p4   (4 chips)')

    hp = render_hint_plate(
        'move: stick/D-pad or A/D   confirm: × / Space   back: O / Esc')
    save_native_and_4x(hp, 'ui_hint_plate')
    print(f'  ui_hint_plate    ({hp.size})')


# ============================================================
#  PREVIEW compositions (3, one per screen)
# ============================================================
def _checker_bg(w, h, c1=(20, 16, 32, 255), c2=(28, 22, 42, 255),
                tile=18):
    img = Image.new('RGBA', (w, h), c1)
    d = ImageDraw.Draw(img)
    for y in range(0, h, tile):
        for x in range(0, w, tile):
            if ((x // tile) + (y // tile)) % 2 == 1:
                d.rectangle([x, y, x + tile - 1, y + tile - 1],
                            fill=c2)
    return img


def preview_clan_select():
    """Mockup: header + 4 clan banners + P1 chip on 'fire', P2 chip on 'storm',
       LOCKED stamp over the fire banner."""
    W, H = 2400, 1200
    bg = _checker_bg(W, H)
    header = Image.open(f'{OUT_DIR}/header_choose_your_clan_4x.png').convert('RGBA')
    bg.alpha_composite(header,
                       ((W - header.size[0]) // 2, 60))

    banners = [Image.open(f'{OUT_DIR}/clan_{c}_4x.png').convert('RGBA')
               for c in CLAN_ORDER]
    selected_p1 = Image.open(
        f'{OUT_DIR}/clan_fire_selected_4x.png').convert('RGBA')
    selected_p2 = Image.open(
        f'{OUT_DIR}/clan_storm_selected_4x.png').convert('RGBA')
    bw = banners[0].size[0]
    gap = 40
    total = bw * 4 + gap * 3
    x = (W - total) // 2
    y = 380
    banner_positions = {}
    for i, c in enumerate(CLAN_ORDER):
        banner_positions[c] = x
        if c == 'fire':
            bg.alpha_composite(selected_p1, (x, y))
        elif c == 'storm':
            bg.alpha_composite(selected_p2, (x, y))
        else:
            bg.alpha_composite(banners[i], (x, y))
        x += bw + gap

    # Locked-in stamp on FIRE banner (over the sigil area)
    stamp = Image.open(f'{OUT_DIR}/ui_locked_in_stamp_4x.png').convert('RGBA')
    fire_x = banner_positions['fire']
    bg.alpha_composite(stamp,
                       (fire_x + bw // 2 - stamp.size[0] // 2,
                        y + 200))

    # P1 chip above fire, P2 chip above storm
    p1 = Image.open(f'{OUT_DIR}/ui_chip_p1_4x.png').convert('RGBA')
    p2 = Image.open(f'{OUT_DIR}/ui_chip_p2_4x.png').convert('RGBA')
    storm_x = banner_positions['storm']
    bg.alpha_composite(p1,
                       (fire_x + bw // 2 - p1.size[0] // 2,
                        y - p1.size[1] - 14))
    bg.alpha_composite(p2,
                       (storm_x + bw // 2 - p2.size[0] // 2,
                        y - p2.size[1] - 14))

    # Hint plate at bottom
    hint = Image.open(f'{OUT_DIR}/ui_hint_plate_4x.png').convert('RGBA')
    bg.alpha_composite(hint,
                       ((W - hint.size[0]) // 2,
                        H - hint.size[1] - 40))

    bg.save(f'{OUT_DIR}/preview_clan_select.png')
    print(f'\nWrote preview_clan_select.png ({W}x{H})')


def preview_mode_select():
    """Mockup: header + 4 mode tiles + difficulty stamp row."""
    W, H = 2400, 1200
    bg = _checker_bg(W, H)
    header = Image.open(f'{OUT_DIR}/header_select_mode_4x.png').convert('RGBA')
    bg.alpha_composite(header, ((W - header.size[0]) // 2, 60))

    tiles_slugs = ['mode_p1_vs_p2', 'mode_p1_vs_ai',
                   'mode_ai_vs_ai', 'mode_p1_vs_3']
    tiles = []
    for i, slug in enumerate(tiles_slugs):
        suffix = '_selected' if slug == 'mode_p1_vs_ai' else ''
        tiles.append(Image.open(
            f'{OUT_DIR}/{slug}{suffix}_4x.png').convert('RGBA'))
    tw = tiles[0].size[0]; gap = 40
    total = tw * 4 + gap * 3
    x = (W - total) // 2; y = 280
    for t in tiles:
        bg.alpha_composite(t, (x, y))
        x += tw + gap

    # Label above difficulty row
    diff_label = render_stone_text('AI DIFFICULTY', font_size=28, seed=42)
    bg.alpha_composite(diff_label,
                       ((W - diff_label.size[0]) // 2,
                        y + tiles[0].size[1] + 40))

    # Difficulty row (only relevant when an AI mode is selected)
    diff_imgs = [Image.open(f'{OUT_DIR}/diff_genin_4x.png').convert('RGBA'),
                 Image.open(f'{OUT_DIR}/diff_chunin_4x.png').convert('RGBA'),
                 Image.open(f'{OUT_DIR}/diff_jonin_4x.png').convert('RGBA')]
    dw = diff_imgs[0].size[0]; dgap = 32
    dtotal = dw * 3 + dgap * 2
    dx = (W - dtotal) // 2
    dy = y + tiles[0].size[1] + 50 + diff_label.size[1] + 30
    for i, d_img in enumerate(diff_imgs):
        if i == 1:
            # composite a glow rectangle (highlight CHUNIN)
            glow = Image.new('RGBA', (d_img.size[0] + 40, d_img.size[1] + 40),
                             TRANSPARENT)
            gd = ImageDraw.Draw(glow)
            for grow in (12, 8, 4):
                gd.rounded_rectangle(
                    [20 - grow, 20 - grow,
                     20 + d_img.size[0] + grow,
                     20 + d_img.size[1] + grow],
                    radius=10 + grow,
                    fill=(*SELECT_GLOW,
                          35 if grow == 12 else 60 if grow == 8 else 95))
            glow = glow.filter(ImageFilter.GaussianBlur(radius=4))
            bg.alpha_composite(glow, (dx - 20, dy - 20))
        bg.alpha_composite(d_img, (dx, dy))
        dx += dw + dgap

    hint = Image.open(f'{OUT_DIR}/ui_hint_plate_4x.png').convert('RGBA')
    bg.alpha_composite(hint,
                       ((W - hint.size[0]) // 2, H - hint.size[1] - 40))
    bg.save(f'{OUT_DIR}/preview_mode_select.png')
    print(f'Wrote preview_mode_select.png ({W}x{H})')


def preview_map_select():
    """Mockup: header + map frame containing Sakura Temple preview + nameplate
       below + nav arrows on each side."""
    W, H = 2400, 1200
    bg = _checker_bg(W, H)
    header = Image.open(f'{OUT_DIR}/header_choose_arena_4x.png').convert('RGBA')
    bg.alpha_composite(header, ((W - header.size[0]) // 2, 60))

    # Scale the frame slightly so the nameplate fits cleanly below.
    frame = Image.open(
        f'{OUT_DIR}/map_frame_selected_4x.png').convert('RGBA')
    fscale = 0.85
    frame_s = frame.resize(
        (int(frame.size[0] * fscale), int(frame.size[1] * fscale)),
        Image.NEAREST)
    fx = (W - frame_s.size[0]) // 2
    fy = 280
    bg.alpha_composite(frame_s, (fx, fy))

    # Map preview thumbnail fits inside the inner panel of the frame
    sakura = Image.open(f'{OUT_DIR}/map_sakura_temple_4x.png').convert('RGBA')
    sakura_s = sakura.resize(
        (int(sakura.size[0] * fscale), int(sakura.size[1] * fscale)),
        Image.NEAREST)
    inner_off = int(22 * 4 * fscale)
    bg.alpha_composite(sakura_s, (fx + inner_off, fy + inner_off))

    # Nameplate below frame
    plate = Image.open(
        f'{OUT_DIR}/map_nameplate_sakura_4x.png').convert('RGBA')
    bg.alpha_composite(plate,
                       ((W - plate.size[0]) // 2,
                        fy + frame_s.size[1] + 30))

    # Nav arrows left/right
    left = Image.open(f'{OUT_DIR}/ui_arrow_left_active_4x.png').convert('RGBA')
    right = Image.open(f'{OUT_DIR}/ui_arrow_right_active_4x.png').convert('RGBA')
    arr_y = fy + frame_s.size[1] // 2 - left.size[1] // 2
    bg.alpha_composite(left, (fx - left.size[0] - 60, arr_y))
    bg.alpha_composite(right,
                       (fx + frame_s.size[0] + 60, arr_y))

    hint = Image.open(f'{OUT_DIR}/ui_hint_plate_4x.png').convert('RGBA')
    bg.alpha_composite(hint,
                       ((W - hint.size[0]) // 2, H - hint.size[1] - 40))
    bg.save(f'{OUT_DIR}/preview_map_select.png')
    print(f'Wrote preview_map_select.png ({W}x{H})')


if __name__ == '__main__':
    generate_all()
    preview_clan_select()
    preview_mode_select()
    preview_map_select()
    print(f'\nDone. Outputs in: {OUT_DIR}')
