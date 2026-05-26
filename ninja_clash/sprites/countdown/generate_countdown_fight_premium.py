"""
Countdown 3 / 2 / 1 + FIGHT — PREMIUM stone edition.

Approach (each sprite is built as 11 distinct layers, in order):

  1. Atmospheric backdrop      — subtle warm sky tint at top, cool earth shadow
                                  at bottom, vignette around the corners.
  2. Floating dust motes        — small low-opacity warm pixels.
  3. Far drop shadow            — soft, broad shadow with gaussian blur.
  4. Near drop shadow           — tighter, denser shadow for grounding.
  5. Stone-shaped silhouette    — clean letter mask rendered with Lato Black.
  6. Stone surface base         — value-noise driven color variation across
                                  5 stone tones, modulated by a directional
                                  light gradient (upper-left light source).
  7. Chiseled rim highlight     — bright pixels on top edges + left edges
                                  suggesting carved bevel catching the light.
  8. Surface pits & chips        — small dark spots and edge nicks.
  9. Structural crack network   — cracks originate from convex corners
                                  (stress points) and branch with Y-forks.
                                  Multi-tone dark with subtle edge lift.
 10. Organic moss colonies      — clusters on TOP edges (gravity-correct),
                                  multi-stop greens with drip trails hanging
                                  down, lichen flecks, soft shadow cast on
                                  the stone below.
 11. Embedded bronze shurikens  — stuck INTO the stone at a slight angle,
                                  full multi-tone bronze with patina in the
                                  grooves and a small impact crack radiating
                                  from where each blade meets the stone.

Outputs to ui/countdown_premium/.
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter


# ============================================================
#  CONFIG
# ============================================================
DIGIT_W, DIGIT_H = 128, 128
FIGHT_W, FIGHT_H = 320, 128

FONT_PATH = '/usr/share/fonts/truetype/lato/Lato-Black.ttf'
DIGIT_FONT_SIZE = 110
FIGHT_FONT_SIZE = 96


# ============================================================
#  PALETTE
# ============================================================
# Atmosphere
ATMO_SKY      = (38, 30, 56)      # warm purple top
ATMO_EARTH    = (10, 8, 18)       # cool dark bottom
DUST_WARM     = (220, 198, 162)

# Stone — warm sand-grey, 6 stops
STONE_HI      = (228, 212, 178)   # warm cream — chiseled highlight
STONE_LIGHT   = (192, 174, 138)   # light beige
STONE_BASE    = (152, 136, 104)   # main mid-tone
STONE_MID     = (118, 102, 78)    # softer shadow
STONE_DARK    = (78, 66, 50)      # deep shadow
STONE_VDARK   = (44, 36, 26)      # crack depth

# Moss — multi-tone green palette
MOSS_DEEP     = (22, 44, 18)
MOSS_DARK     = (44, 78, 30)
MOSS_MID      = (76, 122, 50)
MOSS_BRIGHT   = (130, 178, 76)
MOSS_TIP      = (188, 222, 132)
MOSS_DRY      = (165, 152, 78)   # dried/yellow patches

# Lichen flecks
LICHEN_ORG    = (220, 170, 90)
LICHEN_WHITE  = (210, 220, 215)

# Cracks
CRACK_DEEP    = (16, 12, 22)
CRACK_MID     = (38, 30, 44)
CRACK_LIFT    = (175, 158, 122)   # subtle rim around cracks

# Outline
OUTLINE       = (18, 14, 24)

# Drop shadow
SHADOW_NEAR   = (22, 16, 30)
SHADOW_FAR    = (44, 32, 54)

# Bronze (aged metal)
BRONZE_HI     = (245, 195, 100)
BRONZE        = (180, 130, 65)
BRONZE_MID    = (125, 85, 35)
BRONZE_DARK   = (75, 50, 22)
BRONZE_BLACK  = (28, 18, 8)

# Patina (green oxidation)
PATINA_HI     = (130, 200, 145)
PATINA        = (75, 145, 95)
PATINA_DARK   = (35, 85, 55)

# Ninja accent colors (color-coded shurikens)
NINJA_COLORS = {
    'cyan':    (80, 210, 230),
    'magenta': (235, 80, 175),
    'orange':  (255, 145, 50),
    'green':   (140, 220, 100),
}

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ============================================================
#  NOISE  —  hash-based smooth value noise (no external libs)
# ============================================================
def _hash(ix, iy, seed):
    """Deterministic 0..1 hash for integer grid points."""
    h = math.sin(ix * 127.1 + iy * 311.7 + seed * 71.3) * 43758.5453
    return h - math.floor(h)


def _smoothstep(t):
    return t * t * (3 - 2 * t)


def value_noise(x, y, seed=0):
    """Smooth value noise at fractional (x, y) — returns 0..1."""
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
    """Sum multiple octaves of value noise for richer detail."""
    total = 0.0
    amp = 1.0
    freq = 1.0
    norm = 0.0
    for o in range(octaves):
        total += value_noise(x * freq, y * freq, seed + o * 17) * amp
        norm += amp
        amp *= persistence
        freq *= lacunarity
    return total / norm


# ============================================================
#  Font mask
# ============================================================
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


def erode(mask, px):
    if px <= 0: return mask
    return mask.filter(ImageFilter.MinFilter(px * 2 + 1))


# ============================================================
#  Layer 1 — Atmospheric backdrop
# ============================================================
def render_atmosphere(w, h):
    img = Image.new('RGBA', (w, h), TRANSPARENT)
    px = img.load()
    cx, cy = w / 2, h / 2
    max_dist = math.sqrt(cx * cx + cy * cy)
    for y in range(h):
        # vertical gradient: warm purple top -> cool earth bottom
        t = y / h
        r = int(ATMO_SKY[0] + (ATMO_EARTH[0] - ATMO_SKY[0]) * t)
        g = int(ATMO_SKY[1] + (ATMO_EARTH[1] - ATMO_SKY[1]) * t)
        b = int(ATMO_SKY[2] + (ATMO_EARTH[2] - ATMO_SKY[2]) * t)
        for x in range(w):
            # subtle vignette
            d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max_dist
            vig = 1.0 - d * 0.45
            vig = max(0.55, vig)
            px[x, y] = (int(r * vig), int(g * vig), int(b * vig), 230)
    return img


# ============================================================
#  Layer 2 — Floating dust motes
# ============================================================
def render_dust(w, h, count=18, seed=0):
    img = Image.new('RGBA', (w, h), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed + 999)
    for _ in range(count):
        x = rnd.randint(0, w - 1)
        y = rnd.randint(0, h - 1)
        alpha = rnd.randint(40, 130)
        d.point((x, y), fill=(DUST_WARM[0], DUST_WARM[1], DUST_WARM[2], alpha))
        # occasional slightly bigger speck
        if rnd.random() < 0.25:
            d.point((x + 1, y), fill=(DUST_WARM[0], DUST_WARM[1], DUST_WARM[2],
                                       max(20, alpha - 50)))
    return img


# ============================================================
#  Layers 3+4 — Drop shadow (two-stop, soft)
# ============================================================
def render_drop_shadow(mask, offset_near=(4, 5), offset_far=(8, 11)):
    """Returns (far_shadow_img, near_shadow_img) — composite far first."""
    w, h = mask.size
    # Far shadow — bigger, blurrier, lighter
    far_mask = dilate(mask, 4)
    far_img = Image.new('RGBA', (w, h), TRANSPARENT)
    fp = far_img.load(); fm = far_mask.load()
    for y in range(h):
        for x in range(w):
            if fm[x, y] > 128:
                fp[x, y] = (SHADOW_FAR[0], SHADOW_FAR[1], SHADOW_FAR[2], 80)
    far_img = far_img.filter(ImageFilter.GaussianBlur(radius=3.5))

    # Near shadow — tighter, denser
    near_mask = dilate(mask, 2)
    near_img = Image.new('RGBA', (w, h), TRANSPARENT)
    np_px = near_img.load(); nm = near_mask.load()
    for y in range(h):
        for x in range(w):
            if nm[x, y] > 128:
                np_px[x, y] = (SHADOW_NEAR[0], SHADOW_NEAR[1], SHADOW_NEAR[2], 145)
    near_img = near_img.filter(ImageFilter.GaussianBlur(radius=1.5))
    return far_img, near_img


# ============================================================
#  Layer 5+6 — Stone surface (noise-driven, lit)
# ============================================================
def render_stone_surface(mask, seed=0, light_dir=(-1, -1)):
    """Fill mask with rich stone material modulated by noise + lighting."""
    w, h = mask.size
    img = Image.new('RGBA', (w, h), TRANSPARENT)
    px = img.load()
    mp = mask.load()

    # Pre-compute lighting gradient (normalized 0..1 across diagonal)
    # Light from upper-left = dot product of (x,y) with light_dir
    lx, ly = light_dir
    norm = math.sqrt(lx * lx + ly * ly)
    lx /= norm; ly /= norm
    # Find min/max projection across the bounding box for normalization
    proj_min = lx * 0 + ly * 0
    proj_max = lx * w + ly * h
    if proj_max < proj_min:
        proj_min, proj_max = proj_max, proj_min

    # Stone tones graded by brightness
    tones = [STONE_VDARK, STONE_DARK, STONE_MID, STONE_BASE,
             STONE_LIGHT, STONE_HI]

    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128:
                continue

            # 1) Macro noise — large-scale stone variation
            n_macro = fractal_noise(x / 22, y / 22, octaves=2, seed=seed)
            # 2) Micro noise — surface mottling
            n_micro = fractal_noise(x / 5, y / 5, octaves=2, seed=seed + 50) - 0.5

            # 3) Lighting projection — upper-left = bright, lower-right = dark
            proj = (lx * x + ly * y)
            light_t = (proj - proj_min) / (proj_max - proj_min)
            # Invert: upper-left has smaller proj when light_dir is (-1,-1)
            light_t = 1.0 - light_t

            # Combine: lighting drives the main tone selection,
            # macro noise shifts it, micro noise adds grain
            value = light_t * 0.65 + n_macro * 0.30 + n_micro * 0.18
            value = max(0.0, min(1.0, value))

            # Pick tone — bias toward middle of palette
            idx_f = value * (len(tones) - 1)
            idx = int(idx_f)
            color = tones[max(0, min(len(tones) - 1, idx))]

            # Subtle warm/cool shift based on micro noise
            warm = n_micro * 8
            r = max(0, min(255, color[0] + int(warm)))
            g = max(0, min(255, color[1] + int(warm * 0.5)))
            b = max(0, min(255, color[2] - int(warm * 0.5)))

            px[x, y] = (r, g, b, 255)

    return img


# ============================================================
#  Layer 7 — Chiseled rim highlight (top + left edges)
# ============================================================
def add_chiseled_rim(surface_img, mask):
    """Bright pixel on the top-most and left-most edge of each stroke,
       suggesting a chiseled bevel catching the upper-left light."""
    w, h = mask.size
    sp = surface_img.load()
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128:
                continue
            # is this a top edge (empty pixel above)?
            top_empty = (y == 0 or mp[x, y - 1] <= 128)
            # is this a left edge (empty pixel to left)?
            left_empty = (x == 0 or mp[x - 1, y] <= 128)
            if top_empty:
                sp[x, y] = rgba(STONE_HI)
                # second row slightly less bright
                if y + 1 < h and mp[x, y + 1] > 128:
                    cur = sp[x, y + 1]
                    sp[x, y + 1] = rgba(STONE_LIGHT)
            elif left_empty:
                # left rim — slightly cooler highlight
                sp[x, y] = rgba(STONE_LIGHT)


# ============================================================
#  Layer 8 — Surface pits & edge chips
# ============================================================
def add_pits_and_chips(surface_img, mask, seed=0, pit_count=14):
    """Small dark divots scattered across the surface + edge chips."""
    w, h = mask.size
    sp = surface_img.load()
    mp = mask.load()
    rnd = random.Random(seed + 333)

    # Internal pits
    placed = 0
    attempts = 0
    while placed < pit_count and attempts < 200:
        attempts += 1
        x = rnd.randint(2, w - 3)
        y = rnd.randint(2, h - 3)
        if mp[x, y] > 128 and (y > 0 and mp[x, y - 1] > 128):
            # pit = dark center + soft rim
            sp[x, y] = rgba(STONE_DARK)
            if rnd.random() < 0.6 and mp[x + 1, y] > 128:
                sp[x + 1, y] = rgba(STONE_MID)
            if rnd.random() < 0.4 and mp[x, y + 1] > 128:
                sp[x, y + 1] = rgba(STONE_MID)
            placed += 1

    # Convex-corner chips — find where two empty neighbors meet at a corner
    edge_pixels = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if mp[x, y] <= 128:
                continue
            # corner = two adjacent neighbors empty (e.g., top + right)
            tl = mp[x - 1, y - 1] <= 128
            tr = mp[x + 1, y - 1] <= 128
            bl = mp[x - 1, y + 1] <= 128
            br = mp[x + 1, y + 1] <= 128
            t = mp[x, y - 1] <= 128
            r = mp[x + 1, y] <= 128
            b = mp[x, y + 1] <= 128
            l = mp[x - 1, y] <= 128
            if (t and r) or (t and l) or (b and r) or (b and l):
                edge_pixels.append((x, y))

    chip_count = max(4, len(edge_pixels) // 12)
    if edge_pixels:
        sampled = rnd.sample(edge_pixels, min(chip_count, len(edge_pixels)))
        for cx, cy in sampled:
            # darken edge to suggest chip
            sp[cx, cy] = rgba(STONE_DARK)
            if rnd.random() < 0.5 and cx + 1 < w:
                sp[cx + 1, cy] = rgba(STONE_MID)


# ============================================================
#  Layer 9 — Structural crack network
# ============================================================
def find_stress_points(mask, max_points=4, seed=0):
    """Find convex corners of the mask — these are crack-origin candidates."""
    w, h = mask.size
    mp = mask.load()
    candidates = []
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            if mp[x, y] <= 128:
                continue
            # count empty neighbors in 5x5 area
            empty = 0
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if mp[x + dx, y + dy] <= 128:
                        empty += 1
            # high empty count = exposed corner
            if 11 <= empty <= 16:
                candidates.append((x, y, empty))
    rnd = random.Random(seed + 444)
    rnd.shuffle(candidates)
    # spread points apart
    selected = []
    for x, y, _ in candidates:
        too_close = False
        for sx, sy in selected:
            if math.hypot(x - sx, y - sy) < 15:
                too_close = True; break
        if not too_close:
            selected.append((x, y))
        if len(selected) >= max_points:
            break
    return selected


def add_cracks(surface_img, mask, seed=0, count=3):
    """Cracks originate from stress points, walk jagged paths into the stone,
       and branch with Y-forks. Each crack has a dark core and a subtle lift
       (slightly lighter rim) on one side suggesting depth."""
    w, h = mask.size
    sp = surface_img.load()
    mp = mask.load()
    rnd = random.Random(seed + 555)

    origins = find_stress_points(mask, max_points=count, seed=seed)

    def walk_crack(x0, y0, angle, length, depth=0):
        cx, cy = float(x0), float(y0)
        for step in range(length):
            cx += math.cos(angle) * 1.4
            cy += math.sin(angle) * 1.4
            angle += rnd.uniform(-0.4, 0.4)
            ix, iy = int(cx), int(cy)
            if not (0 <= ix < w and 0 <= iy < h): break
            if mp[ix, iy] <= 128: break
            # main crack
            sp[ix, iy] = rgba(CRACK_DEEP)
            # subtle lift on one side (depending on light)
            lift_dx = 1 if math.cos(angle) > 0 else -1
            lift_dy = 1 if math.sin(angle) > 0 else -1
            if 0 <= ix + lift_dx < w and 0 <= iy + lift_dy < h:
                if mp[ix + lift_dx, iy + lift_dy] > 128:
                    sp[ix + lift_dx, iy + lift_dy] = rgba(CRACK_LIFT)
            # Y-fork chance
            if depth < 1 and step > 4 and rnd.random() < 0.12:
                branch_angle = angle + rnd.uniform(0.7, 1.3) * rnd.choice([-1, 1])
                walk_crack(ix, iy, branch_angle, length // 2, depth + 1)

    for ox, oy in origins:
        # inward angle — pointing roughly away from the nearest edge
        # we approximate by scanning local emptiness
        best_dir = (0, 0); best_score = -1
        for ang_deg in range(0, 360, 30):
            ang = math.radians(ang_deg)
            dx, dy = math.cos(ang), math.sin(ang)
            score = 0
            for r in range(1, 6):
                px_ = int(ox + dx * r); py_ = int(oy + dy * r)
                if 0 <= px_ < w and 0 <= py_ < h and mp[px_, py_] > 128:
                    score += 1
            if score > best_score:
                best_score = score
                best_dir = (dx, dy)
        ang = math.atan2(best_dir[1], best_dir[0])
        walk_crack(ox, oy, ang, length=rnd.randint(14, 22))


# ============================================================
#  Layer 10 — Organic moss colonies
# ============================================================
def add_moss(surface_img, mask, seed=0):
    """Multi-tone moss colonies clustered on TOP edges (gravity-correct).
       Includes drip trails, lichen flecks, soft shadow on stone below."""
    w, h = mask.size
    sp = surface_img.load()
    mp = mask.load()
    rnd = random.Random(seed + 666)

    # Find top-edge pixels (empty above) and bucket them into clusters
    top_edges = []
    for y in range(h):
        for x in range(w):
            if mp[x, y] > 128 and (y == 0 or mp[x, y - 1] <= 128):
                top_edges.append((x, y))
    if not top_edges:
        return

    # Group nearby top-edge pixels into colony seeds
    rnd.shuffle(top_edges)
    seeds_used = []
    for (x, y) in top_edges:
        ok = True
        for (sx_, sy_) in seeds_used:
            if abs(x - sx_) < 10 and abs(y - sy_) < 6:
                ok = False; break
        if ok:
            seeds_used.append((x, y))

    # Skip some seeds randomly for variation (not every edge has moss)
    seeds_used = [s for s in seeds_used if rnd.random() < 0.7]

    for (cx, cy) in seeds_used:
        # 1) Base colony — irregular cluster of MOSS_DEEP underneath
        colony_size = rnd.randint(3, 7)
        cluster_pts = set()
        for _ in range(colony_size * 3):
            ox = cx + rnd.randint(-colony_size, colony_size)
            oy = cy + rnd.randint(0, 2)
            if 0 <= ox < w and 0 <= oy < h and mp[ox, oy] > 128:
                cluster_pts.add((ox, oy))
        for (px_, py_) in cluster_pts:
            sp[px_, py_] = rgba(MOSS_DARK)

        # 2) Mid-tone moss on top of base
        for (px_, py_) in cluster_pts:
            if rnd.random() < 0.7 and py_ - 1 >= 0:
                sp[px_, py_] = rgba(MOSS_MID)
            if rnd.random() < 0.4:
                # bright tips
                sp[px_, py_] = rgba(MOSS_BRIGHT)

        # 3) Brightest highlight on top-most pixels
        top_of_colony = [p for p in cluster_pts
                         if (p[0], p[1] - 1) not in cluster_pts]
        for (px_, py_) in top_of_colony:
            if rnd.random() < 0.55:
                sp[px_, py_] = rgba(MOSS_TIP)

        # 4) Drip trails hanging down 1-3 pixels
        for (px_, py_) in cluster_pts:
            if rnd.random() < 0.18:
                drip_len = rnd.randint(1, 3)
                for d in range(1, drip_len + 1):
                    ny = py_ + d
                    if ny < h and mp[px_, ny] > 128:
                        # drip uses darker green and fades
                        if d == 1:
                            sp[px_, ny] = rgba(MOSS_MID)
                        else:
                            sp[px_, ny] = rgba(MOSS_DARK)

        # 5) Lichen flecks (occasional orange/white spots)
        if rnd.random() < 0.4 and cluster_pts:
            (lx, ly) = rnd.choice(list(cluster_pts))
            if rnd.random() < 0.5:
                sp[lx, ly] = rgba(LICHEN_ORG)
            else:
                sp[lx, ly] = rgba(LICHEN_WHITE)

        # 6) Yellow/dry patch occasionally
        if rnd.random() < 0.2 and cluster_pts:
            (yx, yy) = rnd.choice(list(cluster_pts))
            sp[yx, yy] = rgba(MOSS_DRY)


# ============================================================
#  Embedded bronze shuriken — stuck IN the stone
# ============================================================
def star_polygon(cx, cy, r_outer, r_inner, n_points, rotation_rad):
    verts = []
    for i in range(n_points * 2):
        r = r_outer if i % 2 == 0 else r_inner
        angle = i * math.pi / n_points - math.pi / 2 + rotation_rad
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        verts.append((x, y))
    return verts


def embed_shuriken(canvas, mask, cx, cy, rotation_deg, accent_color,
                   size=11, seed=0):
    """Bronze shuriken stuck INTO the stone — half-embedded with damage
       radiating from impact and patina in the grooves."""
    w, h = canvas.size
    rot = math.radians(rotation_deg)
    overlay = Image.new('RGBA', (w, h), TRANSPARENT)
    d = ImageDraw.Draw(overlay)
    rnd = random.Random(seed + 777)

    # 1) Impact damage in stone behind shuriken — cracks radiating out
    if mask is not None:
        mp = mask.load()
        sp = canvas.load()
        # short cracks emanating from impact center
        for i in range(5):
            ang = rnd.uniform(0, 2 * math.pi)
            length = rnd.randint(4, 8)
            for r in range(2, length):
                px_ = int(cx + math.cos(ang) * r)
                py_ = int(cy + math.sin(ang) * r)
                if 0 <= px_ < w and 0 <= py_ < h and mp[px_, py_] > 128:
                    sp[px_, py_] = rgba(CRACK_DEEP, 255)

    # 2) Drop shadow of shuriken on stone (offset down-right)
    shadow_verts = star_polygon(cx + 1.5, cy + 2.5, size, size * 0.27, 4, rot)
    d.polygon(shadow_verts, fill=(0, 0, 0, 110))

    # 3) Dark outline of shuriken
    outline_verts = star_polygon(cx, cy, size, size * 0.28, 4, rot)
    d.polygon(outline_verts, fill=rgba(BRONZE_BLACK))

    # 4) Main bronze body — 4 shading stops
    # Dark base
    d.polygon(star_polygon(cx, cy, size - 0.7, size * 0.26, 4, rot),
              fill=rgba(BRONZE_DARK))
    # Mid bronze (shifted toward light)
    d.polygon(star_polygon(cx - 0.4, cy - 0.4, size - 1.4, size * 0.24, 4, rot),
              fill=rgba(BRONZE_MID))
    # Main bronze
    d.polygon(star_polygon(cx - 0.7, cy - 0.7, size - 2.3, size * 0.22, 4, rot),
              fill=rgba(BRONZE))
    # Highlight bronze (top-left light)
    d.polygon(star_polygon(cx - 1.1, cy - 1.1, size - 3.2, size * 0.18, 4, rot),
              fill=rgba(BRONZE_HI))

    # 5) Patina in the grooves (between blades — inner radius valleys)
    patina_pts = []
    for i in range(4):  # 4 valleys
        ang = (i * math.pi / 2) + math.pi / 4 + rot
        # midway out from center toward valley
        for r in [size * 0.35, size * 0.45]:
            patina_pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    for px_, py_ in patina_pts:
        if rnd.random() < 0.7:
            d.point((px_, py_), fill=rgba(PATINA))
        if rnd.random() < 0.4:
            d.point((px_ + 0.5, py_), fill=rgba(PATINA_DARK))

    # 6) Color hub — accent color tying to ninja
    hub_r = size * 0.30
    d.ellipse([cx - hub_r, cy - hub_r, cx + hub_r, cy + hub_r],
              fill=rgba(accent_color), outline=rgba(BRONZE_BLACK))
    # subtle highlight on hub
    d.ellipse([cx - hub_r * 0.55, cy - hub_r * 0.55,
               cx - hub_r * 0.05, cy - hub_r * 0.05],
              fill=(min(255, accent_color[0] + 40),
                    min(255, accent_color[1] + 40),
                    min(255, accent_color[2] + 40), 200))
    # center hole
    d.ellipse([cx - 1.1, cy - 1.1, cx + 1.1, cy + 1.1], fill=rgba(BRONZE_BLACK))

    # 7) A subtle scratch line across one blade
    if rnd.random() < 0.7:
        scratch_ang = rot + rnd.uniform(0, math.pi / 2)
        sx1 = cx + math.cos(scratch_ang) * (size - 2)
        sy1 = cy + math.sin(scratch_ang) * (size - 2)
        sx2 = cx + math.cos(scratch_ang) * (size - 5)
        sy2 = cy + math.sin(scratch_ang) * (size - 5)
        d.line([(sx1, sy1), (sx2, sy2)], fill=rgba(BRONZE_HI), width=1)

    canvas.alpha_composite(overlay)


# ============================================================
#  COMPOSE — assemble all layers
# ============================================================
def compose_sprite(text, font_size, canvas_w, canvas_h, seed,
                   shurikens_spec):
    """shurikens_spec = list of dicts: {x, y, rot, color, size}"""
    # 1+2. Atmosphere + dust
    canvas = Image.new('RGBA', (canvas_w, canvas_h), TRANSPARENT)
    canvas.alpha_composite(render_atmosphere(canvas_w, canvas_h))
    canvas.alpha_composite(render_dust(canvas_w, canvas_h, count=22, seed=seed))

    # Build text mask
    raw_mask = text_mask(text, font_size, padding=12)
    mw, mh = raw_mask.size
    # Center the mask within canvas
    sprite_x = (canvas_w - mw) // 2
    sprite_y = (canvas_h - mh) // 2

    # 3+4. Drop shadow
    far_shadow, near_shadow = render_drop_shadow(raw_mask)
    canvas.alpha_composite(far_shadow, (sprite_x + 8, sprite_y + 11))
    canvas.alpha_composite(near_shadow, (sprite_x + 4, sprite_y + 5))

    # 5. Outline + 6. Stone surface
    # Build outline by dilating
    outline_mask = dilate(raw_mask, 1)
    outline_img = Image.new('RGBA', (mw, mh), TRANSPARENT)
    op = outline_img.load(); om = outline_mask.load()
    for y in range(mh):
        for x in range(mw):
            if om[x, y] > 128:
                op[x, y] = rgba(OUTLINE)
    canvas.alpha_composite(outline_img, (sprite_x, sprite_y))

    # Stone surface (interior fill)
    surface = render_stone_surface(raw_mask, seed=seed)
    # 7. Chiseled rim
    add_chiseled_rim(surface, raw_mask)
    # 8. Pits + chips
    add_pits_and_chips(surface, raw_mask, seed=seed, pit_count=18)
    # 9. Cracks
    add_cracks(surface, raw_mask, seed=seed, count=3)
    # 10. Moss
    add_moss(surface, raw_mask, seed=seed)
    canvas.alpha_composite(surface, (sprite_x, sprite_y))

    # 11. Embedded shurikens (positions are in canvas coords)
    # Build a full-canvas mask for the cracks-in-stone effect
    full_mask = Image.new('L', (canvas_w, canvas_h), 0)
    full_mask.paste(raw_mask, (sprite_x, sprite_y))
    for spec in shurikens_spec:
        embed_shuriken(canvas, full_mask,
                       spec['x'], spec['y'],
                       spec['rot'], spec['color'],
                       size=spec['size'], seed=seed + spec.get('seed', 0))

    return canvas


# ============================================================
#  Per-sprite specs
# ============================================================
DIGIT_SPECS = {
    '3': {
        'seed': 31,
        'shurikens': [
            # one big shuriken stuck into the lower right
            {'x': DIGIT_W - 30, 'y': DIGIT_H - 32, 'rot': 18,
             'color': NINJA_COLORS['cyan'], 'size': 11, 'seed': 1},
            # smaller one upper-left
            {'x': 26, 'y': 28, 'rot': 50,
             'color': NINJA_COLORS['magenta'], 'size': 7, 'seed': 2},
        ],
    },
    '2': {
        'seed': 17,
        'shurikens': [
            {'x': 32, 'y': DIGIT_H - 30, 'rot': 35,
             'color': NINJA_COLORS['orange'], 'size': 11, 'seed': 3},
            {'x': DIGIT_W - 28, 'y': 26, 'rot': 65,
             'color': NINJA_COLORS['green'], 'size': 7, 'seed': 4},
        ],
    },
    '1': {
        'seed': 23,
        'shurikens': [
            {'x': DIGIT_W // 2 + 20, 'y': 30, 'rot': 22,
             'color': NINJA_COLORS['magenta'], 'size': 11, 'seed': 5},
            {'x': DIGIT_W // 2 - 20, 'y': DIGIT_H - 28, 'rot': 48,
             'color': NINJA_COLORS['orange'], 'size': 7, 'seed': 6},
        ],
    },
}

FIGHT_SPEC = {
    'seed': 71,
    'shurikens': [
        # Big embedded shuriken near F (left edge)
        {'x': 30, 'y': FIGHT_H // 2 + 4, 'rot': 22,
         'color': NINJA_COLORS['cyan'], 'size': 13, 'seed': 10},
        # Big embedded near T (right edge)
        {'x': FIGHT_W - 30, 'y': FIGHT_H // 2 - 4, 'rot': 67,
         'color': NINJA_COLORS['magenta'], 'size': 13, 'seed': 11},
        # Smaller accent shurikens
        {'x': 65, 'y': 26, 'rot': 33,
         'color': NINJA_COLORS['orange'], 'size': 7, 'seed': 12},
        {'x': FIGHT_W - 65, 'y': FIGHT_H - 26, 'rot': 51,
         'color': NINJA_COLORS['green'], 'size': 7, 'seed': 13},
    ],
}


# ============================================================
#  Render & save
# ============================================================
ROOT = '/sessions/nice-zen-rubin/mnt/outputs'
OUT_DIR = f'{ROOT}/ui/countdown_premium'
os.makedirs(OUT_DIR, exist_ok=True)


def save_with_upscales(img, base_name):
    img.save(f'{OUT_DIR}/{base_name}_native.png')
    w, h = img.size
    img.resize((w * 4, h * 4), Image.NEAREST).save(
        f'{OUT_DIR}/{base_name}_4x.png'
    )
    img.resize((w * 8, h * 8), Image.NEAREST).save(
        f'{OUT_DIR}/{base_name}_8x.png'
    )


# Digits
for d_str in ['3', '2', '1']:
    spec = DIGIT_SPECS[d_str]
    sprite = compose_sprite(d_str, DIGIT_FONT_SIZE, DIGIT_W, DIGIT_H,
                            seed=spec['seed'], shurikens_spec=spec['shurikens'])
    save_with_upscales(sprite, f'countdown_{d_str}_premium')
    print(f'Wrote countdown_{d_str}_premium')

# FIGHT
fight = compose_sprite('FIGHT', FIGHT_FONT_SIZE, FIGHT_W, FIGHT_H,
                       seed=FIGHT_SPEC['seed'],
                       shurikens_spec=FIGHT_SPEC['shurikens'])
save_with_upscales(fight, 'fight_premium')
print('Wrote fight_premium')

# Combined preview (4x for size limits)
gap = 24
pad = 32
seq_w = DIGIT_W * 4 * 3 + FIGHT_W * 4 + gap * 3 + pad * 2
seq_h = max(DIGIT_H, FIGHT_H) * 4 + pad * 2
preview = Image.new('RGBA', (seq_w, seq_h), (16, 12, 22, 255))
x = pad
for d_str in ['3', '2', '1']:
    s = Image.open(f'{OUT_DIR}/countdown_{d_str}_premium_4x.png')
    preview.paste(s, (x, pad), s)
    x += DIGIT_W * 4 + gap
f = Image.open(f'{OUT_DIR}/fight_premium_4x.png')
preview.paste(f, (x, pad), f)
preview.save(f'{OUT_DIR}/countdown_premium_preview_4x.png')
print('Wrote countdown_premium_preview_4x.png')

# Also save 8x preview for hi-res viewing
seq_w8 = DIGIT_W * 8 * 3 + FIGHT_W * 8 + gap * 3 + pad * 2
seq_h8 = max(DIGIT_H, FIGHT_H) * 8 + pad * 2
preview8 = Image.new('RGBA', (seq_w8, seq_h8), (16, 12, 22, 255))
x = pad
for d_str in ['3', '2', '1']:
    s = Image.open(f'{OUT_DIR}/countdown_{d_str}_premium_8x.png')
    preview8.paste(s, (x, pad), s)
    x += DIGIT_W * 8 + gap
f = Image.open(f'{OUT_DIR}/fight_premium_8x.png')
preview8.paste(f, (x, pad), f)
preview8.save(f'{OUT_DIR}/countdown_premium_preview_8x.png')
print('Wrote countdown_premium_preview_8x.png')
