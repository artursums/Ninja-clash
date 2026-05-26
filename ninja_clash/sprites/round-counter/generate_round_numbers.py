"""
ROUND indicator system — full digit set + word + composition helper.

This script does three things:

  1. Generates 10 individual digit sprites (0-9) in the same premium
     stone style as the countdown numbers — transparent background,
     drop shadow, weathered stone material, moss, cracks, chiseled rim.

     Each digit is rendered in a TIGHT bounding box (so "1" sprite is
     narrower than "0"). This lets the composer lay them out cleanly
     for any number.

  2. Generates a "ROUND" wordmark in the same style.

  3. Provides a `compose_round_number(n, scale)` helper that builds
     a "ROUND <N>" composite image for ANY integer N — works for
     single digits, double digits, 100, 999, anything. Pre-renders
     several example compositions so you can see how it scales.

Outputs to ui/round_indicator/.

Usage inside your game's Python build pipeline:

    from generate_round_numbers import compose_round_number
    img = compose_round_number(42, scale=4)
    img.save('round_42_4x.png')

Or just call this script and it'll generate every digit + ROUND +
example compositions in one go.
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter


# ============================================================
#  CONFIG
# ============================================================
FONT_PATH = '/usr/share/fonts/truetype/lato/Lato-Black.ttf'
FONT_SIZE = 64

# Sprite frame padding around tight letterform (room for drop shadow + rim)
FRAME_PADDING = 12

# Spacing when composing
GAP_BETWEEN_WORD_AND_NUMBER = 18    # native pixels
GAP_BETWEEN_DIGITS          = 4

ROOT = '/sessions/nice-zen-rubin/mnt/outputs'
OUT_DIR = f'{ROOT}/ui/round_indicator'
os.makedirs(OUT_DIR, exist_ok=True)


# ============================================================
#  PALETTE (matches countdown_premium for visual consistency)
# ============================================================
STONE_HI      = (228, 212, 178)
STONE_LIGHT   = (192, 174, 138)
STONE_BASE    = (152, 136, 104)
STONE_MID     = (118, 102, 78)
STONE_DARK    = (78, 66, 50)
STONE_VDARK   = (44, 36, 26)

MOSS_DEEP     = (22, 44, 18)
MOSS_DARK     = (44, 78, 30)
MOSS_MID      = (76, 122, 50)
MOSS_BRIGHT   = (130, 178, 76)
MOSS_TIP      = (188, 222, 132)
MOSS_DRY      = (165, 152, 78)

LICHEN_ORG    = (220, 170, 90)
LICHEN_WHITE  = (210, 220, 215)

CRACK_DEEP    = (16, 12, 22)
CRACK_LIFT    = (175, 158, 122)

OUTLINE       = (18, 14, 24)
SHADOW_NEAR   = (22, 16, 30)
SHADOW_FAR    = (44, 32, 54)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ============================================================
#  Noise + helpers
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
    v00 = _hash(x0, y0, seed)
    v10 = _hash(x1, y0, seed)
    v01 = _hash(x0, y1, seed)
    v11 = _hash(x1, y1, seed)
    return (v00 * (1 - sx) + v10 * sx) * (1 - sy) + \
           (v01 * (1 - sx) + v11 * sx) * sy


def fractal_noise(x, y, octaves=3, seed=0, lacunarity=2.0, persistence=0.5):
    total = 0.0; amp = 1.0; freq = 1.0; norm = 0.0
    for o in range(octaves):
        total += value_noise(x * freq, y * freq, seed + o * 17) * amp
        norm += amp
        amp *= persistence
        freq *= lacunarity
    return total / norm


def text_mask(text, font_size, padding=8):
    font = ImageFont.truetype(FONT_PATH, font_size)
    bbox = font.getbbox(text)
    w = bbox[2] - bbox[0] + padding * 2
    h = bbox[3] - bbox[1] + padding * 2
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    d.text((padding - bbox[0], padding - bbox[1]), text, font=font, fill=255)
    return img.point(lambda v: 255 if v > 110 else 0)


def dilate(mask, px):
    if px <= 0: return mask
    return mask.filter(ImageFilter.MaxFilter(px * 2 + 1))


# ============================================================
#  Stone surface renderer (same as countdown_premium)
# ============================================================
def render_drop_shadow(mask):
    w, h = mask.size
    far_mask = dilate(mask, 4)
    far_img = Image.new('RGBA', (w, h), TRANSPARENT)
    fp = far_img.load(); fm = far_mask.load()
    for y in range(h):
        for x in range(w):
            if fm[x, y] > 128:
                fp[x, y] = (SHADOW_FAR[0], SHADOW_FAR[1], SHADOW_FAR[2], 80)
    far_img = far_img.filter(ImageFilter.GaussianBlur(radius=3.5))

    near_mask = dilate(mask, 2)
    near_img = Image.new('RGBA', (w, h), TRANSPARENT)
    np_px = near_img.load(); nm = near_mask.load()
    for y in range(h):
        for x in range(w):
            if nm[x, y] > 128:
                np_px[x, y] = (SHADOW_NEAR[0], SHADOW_NEAR[1], SHADOW_NEAR[2], 145)
    near_img = near_img.filter(ImageFilter.GaussianBlur(radius=1.5))
    return far_img, near_img


def render_stone_surface(mask, seed=0, light_dir=(-1, -1)):
    w, h = mask.size
    img = Image.new('RGBA', (w, h), TRANSPARENT)
    px = img.load(); mp = mask.load()

    lx, ly = light_dir
    n = math.sqrt(lx * lx + ly * ly)
    lx /= n; ly /= n
    proj_min = lx * 0 + ly * 0
    proj_max = lx * w + ly * h
    if proj_max < proj_min:
        proj_min, proj_max = proj_max, proj_min

    tones = [STONE_VDARK, STONE_DARK, STONE_MID, STONE_BASE,
             STONE_LIGHT, STONE_HI]

    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128:
                continue
            n_macro = fractal_noise(x / 22, y / 22, octaves=2, seed=seed)
            n_micro = fractal_noise(x / 5, y / 5, octaves=2, seed=seed + 50) - 0.5
            proj = (lx * x + ly * y)
            light_t = 1.0 - (proj - proj_min) / (proj_max - proj_min)
            value = light_t * 0.65 + n_macro * 0.30 + n_micro * 0.18
            value = max(0.0, min(1.0, value))
            idx = int(value * (len(tones) - 1))
            color = tones[max(0, min(len(tones) - 1, idx))]
            warm = n_micro * 8
            r = max(0, min(255, color[0] + int(warm)))
            g = max(0, min(255, color[1] + int(warm * 0.5)))
            b = max(0, min(255, color[2] - int(warm * 0.5)))
            px[x, y] = (r, g, b, 255)
    return img


def add_chiseled_rim(surface_img, mask):
    w, h = mask.size
    sp = surface_img.load(); mp = mask.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128:
                continue
            top_empty = (y == 0 or mp[x, y - 1] <= 128)
            left_empty = (x == 0 or mp[x - 1, y] <= 128)
            if top_empty:
                sp[x, y] = rgba(STONE_HI)
                if y + 1 < h and mp[x, y + 1] > 128:
                    sp[x, y + 1] = rgba(STONE_LIGHT)
            elif left_empty:
                sp[x, y] = rgba(STONE_LIGHT)


def add_pits_and_chips(surface_img, mask, seed=0, pit_count=10):
    w, h = mask.size
    sp = surface_img.load(); mp = mask.load()
    rnd = random.Random(seed + 333)
    placed = 0
    attempts = 0
    while placed < pit_count and attempts < 200:
        attempts += 1
        x = rnd.randint(2, w - 3); y = rnd.randint(2, h - 3)
        if mp[x, y] > 128 and (y > 0 and mp[x, y - 1] > 128):
            sp[x, y] = rgba(STONE_DARK)
            if rnd.random() < 0.6 and mp[x + 1, y] > 128:
                sp[x + 1, y] = rgba(STONE_MID)
            if rnd.random() < 0.4 and mp[x, y + 1] > 128:
                sp[x, y + 1] = rgba(STONE_MID)
            placed += 1

    edge_pixels = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if mp[x, y] <= 128:
                continue
            t = mp[x, y - 1] <= 128
            r = mp[x + 1, y] <= 128
            b = mp[x, y + 1] <= 128
            l = mp[x - 1, y] <= 128
            if (t and r) or (t and l) or (b and r) or (b and l):
                edge_pixels.append((x, y))
    chip_count = max(3, len(edge_pixels) // 12)
    if edge_pixels:
        sampled = rnd.sample(edge_pixels, min(chip_count, len(edge_pixels)))
        for cx, cy in sampled:
            sp[cx, cy] = rgba(STONE_DARK)
            if rnd.random() < 0.5 and cx + 1 < w:
                sp[cx + 1, cy] = rgba(STONE_MID)


def find_stress_points(mask, max_points=3, seed=0):
    w, h = mask.size
    mp = mask.load()
    candidates = []
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            if mp[x, y] <= 128:
                continue
            empty = 0
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if mp[x + dx, y + dy] <= 128:
                        empty += 1
            if 11 <= empty <= 16:
                candidates.append((x, y))
    rnd = random.Random(seed + 444)
    rnd.shuffle(candidates)
    selected = []
    for x, y in candidates:
        too_close = False
        for sx, sy in selected:
            if math.hypot(x - sx, y - sy) < 12:
                too_close = True; break
        if not too_close:
            selected.append((x, y))
        if len(selected) >= max_points:
            break
    return selected


def add_cracks(surface_img, mask, seed=0, count=2):
    w, h = mask.size
    sp = surface_img.load(); mp = mask.load()
    rnd = random.Random(seed + 555)
    origins = find_stress_points(mask, max_points=count, seed=seed)

    def walk(x0, y0, ang, length, depth=0):
        cx, cy = float(x0), float(y0)
        for step in range(length):
            cx += math.cos(ang) * 1.4
            cy += math.sin(ang) * 1.4
            ang += rnd.uniform(-0.4, 0.4)
            ix, iy = int(cx), int(cy)
            if not (0 <= ix < w and 0 <= iy < h): break
            if mp[ix, iy] <= 128: break
            sp[ix, iy] = rgba(CRACK_DEEP)
            ldx = 1 if math.cos(ang) > 0 else -1
            ldy = 1 if math.sin(ang) > 0 else -1
            if 0 <= ix + ldx < w and 0 <= iy + ldy < h and mp[ix + ldx, iy + ldy] > 128:
                sp[ix + ldx, iy + ldy] = rgba(CRACK_LIFT)
            if depth < 1 and step > 4 and rnd.random() < 0.12:
                walk(ix, iy, ang + rnd.uniform(0.7, 1.3) * rnd.choice([-1, 1]),
                     length // 2, depth + 1)

    for ox, oy in origins:
        best = (0, 0); best_score = -1
        for ad in range(0, 360, 30):
            a = math.radians(ad)
            dx, dy = math.cos(a), math.sin(a)
            score = 0
            for r in range(1, 6):
                px_ = int(ox + dx * r); py_ = int(oy + dy * r)
                if 0 <= px_ < w and 0 <= py_ < h and mp[px_, py_] > 128:
                    score += 1
            if score > best_score:
                best_score = score; best = (dx, dy)
        walk(ox, oy, math.atan2(best[1], best[0]), length=rnd.randint(10, 16))


def add_moss(surface_img, mask, seed=0):
    w, h = mask.size
    sp = surface_img.load(); mp = mask.load()
    rnd = random.Random(seed + 666)

    top_edges = []
    for y in range(h):
        for x in range(w):
            if mp[x, y] > 128 and (y == 0 or mp[x, y - 1] <= 128):
                top_edges.append((x, y))
    if not top_edges:
        return
    rnd.shuffle(top_edges)
    seeds_used = []
    for (x, y) in top_edges:
        ok = True
        for (sx_, sy_) in seeds_used:
            if abs(x - sx_) < 10 and abs(y - sy_) < 6:
                ok = False; break
        if ok:
            seeds_used.append((x, y))
    seeds_used = [s for s in seeds_used if rnd.random() < 0.7]

    for (cx, cy) in seeds_used:
        sz = rnd.randint(3, 6)
        pts = set()
        for _ in range(sz * 3):
            ox = cx + rnd.randint(-sz, sz)
            oy = cy + rnd.randint(0, 2)
            if 0 <= ox < w and 0 <= oy < h and mp[ox, oy] > 128:
                pts.add((ox, oy))
        for (p, q) in pts:
            sp[p, q] = rgba(MOSS_DARK)
        for (p, q) in pts:
            if rnd.random() < 0.7:
                sp[p, q] = rgba(MOSS_MID)
            if rnd.random() < 0.4:
                sp[p, q] = rgba(MOSS_BRIGHT)
        top_of = [pp for pp in pts if (pp[0], pp[1] - 1) not in pts]
        for (p, q) in top_of:
            if rnd.random() < 0.55:
                sp[p, q] = rgba(MOSS_TIP)
        for (p, q) in pts:
            if rnd.random() < 0.18:
                dlen = rnd.randint(1, 3)
                for dd in range(1, dlen + 1):
                    ny = q + dd
                    if ny < h and mp[p, ny] > 128:
                        sp[p, ny] = rgba(MOSS_MID if dd == 1 else MOSS_DARK)
        if rnd.random() < 0.4 and pts:
            (lx, ly) = rnd.choice(list(pts))
            sp[lx, ly] = rgba(LICHEN_ORG if rnd.random() < 0.5 else LICHEN_WHITE)
        if rnd.random() < 0.2 and pts:
            (yx, yy) = rnd.choice(list(pts))
            sp[yx, yy] = rgba(MOSS_DRY)


# ============================================================
#  Render one character TIGHT (canvas = mask size + small margin)
# ============================================================
def render_tight(text, font_size, seed):
    """Render a single character/word in a tight bounding box.
       Returns RGBA Image, transparent background."""
    raw_mask = text_mask(text, font_size, padding=FRAME_PADDING)
    mw, mh = raw_mask.size

    # Canvas = mask size + small additional margin for drop shadow
    canvas_w = mw + 12
    canvas_h = mh + 12
    canvas = Image.new('RGBA', (canvas_w, canvas_h), TRANSPARENT)

    sprite_x = 6
    sprite_y = 6

    # Drop shadow (two-layer)
    far_shadow, near_shadow = render_drop_shadow(raw_mask)
    canvas.alpha_composite(far_shadow, (sprite_x + 6, sprite_y + 9))
    canvas.alpha_composite(near_shadow, (sprite_x + 3, sprite_y + 4))

    # Outline
    outline_mask = dilate(raw_mask, 1)
    outline_img = Image.new('RGBA', (mw, mh), TRANSPARENT)
    op = outline_img.load(); om = outline_mask.load()
    for y in range(mh):
        for x in range(mw):
            if om[x, y] > 128:
                op[x, y] = rgba(OUTLINE)
    canvas.alpha_composite(outline_img, (sprite_x, sprite_y))

    # Stone surface
    surface = render_stone_surface(raw_mask, seed=seed)
    add_chiseled_rim(surface, raw_mask)
    add_pits_and_chips(surface, raw_mask, seed=seed,
                       pit_count=8 if len(text) == 1 else 14)
    add_cracks(surface, raw_mask, seed=seed,
               count=2 if len(text) == 1 else 3)
    add_moss(surface, raw_mask, seed=seed)
    canvas.alpha_composite(surface, (sprite_x, sprite_y))

    return canvas


# ============================================================
#  Generate digits + ROUND word
# ============================================================
def generate_assets():
    """Render every digit 0-9 and the ROUND word, save at native + 4x + 8x."""
    results = {}

    for ch in '0123456789':
        sprite = render_tight(ch, FONT_SIZE, seed=ord(ch) * 13 + 7)
        sprite.save(f'{OUT_DIR}/digit_{ch}_native.png')
        sprite.resize((sprite.size[0] * 4, sprite.size[1] * 4),
                      Image.NEAREST).save(f'{OUT_DIR}/digit_{ch}_4x.png')
        sprite.resize((sprite.size[0] * 8, sprite.size[1] * 8),
                      Image.NEAREST).save(f'{OUT_DIR}/digit_{ch}_8x.png')
        results[ch] = sprite
        print(f'Wrote digit_{ch}')

    word = render_tight('ROUND', FONT_SIZE, seed=9999)
    word.save(f'{OUT_DIR}/round_word_native.png')
    word.resize((word.size[0] * 4, word.size[1] * 4),
                Image.NEAREST).save(f'{OUT_DIR}/round_word_4x.png')
    word.resize((word.size[0] * 8, word.size[1] * 8),
                Image.NEAREST).save(f'{OUT_DIR}/round_word_8x.png')
    results['ROUND'] = word
    print('Wrote round_word')

    return results


# ============================================================
#  Composition helper — builds "ROUND <N>" for any integer N
# ============================================================
def compose_round_number(n, scale=1,
                         gap_word_to_num=GAP_BETWEEN_WORD_AND_NUMBER,
                         gap_between_digits=GAP_BETWEEN_DIGITS):
    """Compose 'ROUND <N>' for any non-negative integer N.

    scale: 1 = native pixel size, 4 = 4x upscale, 8 = 8x upscale.

    Returns RGBA Image with transparent background.
    """
    suffix = '_native' if scale == 1 else f'_{scale}x'

    word = Image.open(f'{OUT_DIR}/round_word{suffix}.png').convert('RGBA')
    digit_imgs = [
        Image.open(f'{OUT_DIR}/digit_{c}{suffix}.png').convert('RGBA')
        for c in str(n)
    ]

    word_w, word_h = word.size
    word_gap = gap_word_to_num * scale
    digit_gap = gap_between_digits * scale

    digits_total_w = sum(d.size[0] for d in digit_imgs) + \
                     digit_gap * (len(digit_imgs) - 1)
    total_w = word_w + word_gap + digits_total_w
    total_h = max(word_h, max(d.size[1] for d in digit_imgs))

    canvas = Image.new('RGBA', (total_w, total_h), TRANSPARENT)

    # Place ROUND, vertically centered
    canvas.alpha_composite(word, (0, (total_h - word_h) // 2))

    # Place digits, baseline-aligned (bottom-aligned since all same height)
    x = word_w + word_gap
    for d in digit_imgs:
        canvas.alpha_composite(d, (x, (total_h - d.size[1]) // 2))
        x += d.size[0] + digit_gap

    return canvas


# ============================================================
#  Main
# ============================================================
if __name__ == '__main__':
    # Step 1: render every digit and the ROUND word
    generate_assets()

    # Step 2: pre-render examples at 4x scale showing how the
    # composer handles different digit counts
    EXAMPLES = [1, 3, 7, 10, 12, 47, 99, 100, 256, 999]
    for n in EXAMPLES:
        for sc in [1, 4]:
            img = compose_round_number(n, scale=sc)
            suffix = 'native' if sc == 1 else f'{sc}x'
            img.save(f'{OUT_DIR}/example_round_{n:03d}_{suffix}.png')
        print(f'Composed example_round_{n}')

    # Step 3: combined preview showing all examples stacked vertically
    rows = [Image.open(f'{OUT_DIR}/example_round_{n:03d}_4x.png')
            for n in EXAMPLES]
    max_w = max(r.size[0] for r in rows)
    row_h = max(r.size[1] for r in rows)
    pad = 16
    preview_w = max_w + pad * 2
    preview_h = (row_h + pad) * len(rows) + pad

    # checkerboard background so transparency is visible
    def checker(w, h, tile=16,
                c1=(60, 56, 70, 255), c2=(40, 36, 50, 255)):
        img = Image.new('RGBA', (w, h), c1)
        d = ImageDraw.Draw(img)
        for y in range(0, h, tile):
            for x in range(0, w, tile):
                if ((x // tile) + (y // tile)) % 2 == 1:
                    d.rectangle([x, y, x + tile - 1, y + tile - 1], fill=c2)
        return img

    preview = checker(preview_w, preview_h, tile=20)
    y_off = pad
    for r in rows:
        preview.paste(r, ((preview_w - r.size[0]) // 2, y_off), r)
        y_off += row_h + pad
    preview.save(f'{OUT_DIR}/round_examples_preview.png')
    print('Wrote round_examples_preview.png')

    # Step 4: a "digit set" preview — all 10 digits in one row, with
    # ROUND word on top, to give a sense of the full alphabet.
    digit_imgs = [Image.open(f'{OUT_DIR}/digit_{c}_4x.png')
                  for c in '0123456789']
    word_img = Image.open(f'{OUT_DIR}/round_word_4x.png')
    digits_total_w = sum(d.size[0] for d in digit_imgs) + 8 * 9
    set_w = max(digits_total_w, word_img.size[0]) + pad * 2
    set_h = word_img.size[1] + digit_imgs[0].size[1] + pad * 3
    set_preview = checker(set_w, set_h, tile=20)
    set_preview.paste(word_img, ((set_w - word_img.size[0]) // 2, pad), word_img)
    x = (set_w - digits_total_w) // 2
    y = pad * 2 + word_img.size[1]
    for d in digit_imgs:
        set_preview.paste(d, (x, y), d)
        x += d.size[0] + 8
    set_preview.save(f'{OUT_DIR}/round_digit_set_preview.png')
    print('Wrote round_digit_set_preview.png')
