"""
Improved combat assets for the TowerFall-style ninja game:

  1. Katana V2 — 32x16 native sprite with the iconic katana curve (sori),
     visible hamon temper line, larger tsuba and a properly diamond-wrapped
     ito grip. Reads instantly as "katana" rather than just "sword".

     6 frames per ninja color:
       1. sheathed   — katana in saya
       2. drawn      — curved blade visible, hamon line on
       3. raised     — overhead vertical pose
       4. mid_swing  — horizontal swing with motion trail
       5. strike_hit — moment of impact, with a strike-flash baked at the tip
       6. follow_thru— diagonal follow-through after the cut

  2. Strike-flash FX — universal 4-frame animation that plays whenever a
     blade lands a hit. 24x24 native, transparent background. Drop on top
     of the impact point.

       1. ignition  — tiny bright dot
       2. burst     — 4-point star + small forks
       3. peak      — spike rays extending out
       4. fade      — translucent scattered sparks

  3. Clash-lightning FX — 5-frame animation that plays between two katanas
     when they meet. Pure electric-cyan-and-white palette, jagged lightning
     forks. 32x32 native, transparent. Spawn at the contact point.

       1. contact   — small bright nucleus
       2. fork      — first lightning forks branch out
       3. peak      — full crackle, 4-direction jagged bolts
       4. fade1     — bolts retract, scattered sparks
       5. fade2     — fragmented dust, mostly transparent

Outputs:
  ninjas/katanas_v2/katana_{color}_v2_6frame_*.png + preview
  ninjas/fx/strike_flash_4frame_*.png
  ninjas/fx/clash_lightning_5frame_*.png
  ninjas/fx/combat_fx_preview.png
"""

import os
import math
import random
from PIL import Image, ImageDraw


# ============================================================
# Common palette
# ============================================================
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

# Blade
BLADE_HI    = (250, 252, 255)
BLADE       = (200, 208, 222)
BLADE_MID   = (165, 175, 195)
BLADE_DARK  = (110, 120, 145)
BLADE_HAMON = (235, 240, 250)   # hamon temper line — slightly lighter
HABAKI      = (180, 140, 60)    # brass collar
HABAKI_HI   = (240, 200, 100)
HABAKI_DARK = (115, 85,  30)

# Furniture
TSUBA       = (32, 28, 46)      # iron guard
TSUBA_HI    = (95, 88,  115)
TSUBA_DARK  = (12, 10,  20)
MENUKI      = (210, 170, 60)
MENUKI_HI   = (255, 222, 110)
POMMEL      = (25, 22, 38)
POMMEL_HI   = (75, 68, 95)
SAYA        = (16, 12, 22)      # lacquer black scabbard
SAYA_HI     = (50, 44, 65)
SAYA_TIP    = (190, 150, 80)    # kojiri brass tip

# Strike flash (universal hit FX)
FLASH_WHITE = (255, 255, 240)
FLASH_CORE  = (255, 250, 200)
FLASH_MID   = (255, 220, 110)
FLASH_OUT   = (255, 160, 40)

# Clash lightning (electric, blue-white)
LIGHT_CORE  = (255, 255, 255)
LIGHT_INNER = (200, 235, 255)
LIGHT_MID   = (110, 200, 255)
LIGHT_BLUE  = (60,  140, 255)
LIGHT_PURPLE= (180, 110, 255)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c, a=255):
    d.point((x, y), fill=rgba(c, a))


def rect(d, x1, y1, x2, y2, c, a=255):
    if x2 < x1 or y2 < y1:
        return
    d.rectangle([x1, y1, x2, y2], fill=rgba(c, a))


# ============================================================
#  KATANA V2 — 32x16 frames
# ============================================================
K_FRAME_W, K_FRAME_H = 32, 16
K_FRAMES = ['sheathed', 'drawn', 'raised', 'mid_swing', 'strike_hit', 'follow_thru']
K_STRIP_W = K_FRAME_W * len(K_FRAMES)   # 192
K_STRIP_H = K_FRAME_H


def draw_handle_v2(d, p, ox, oy, cy=8):
    """Long ito-wrapped grip with diamond pattern, at cols 25-29.
       cy = vertical center row of the handle."""
    M, H, S = p['main'], p['hi'], p['shadow']
    top, bot = cy - 2, cy + 2
    # base ito wrap (main color)
    rect(d, ox+25, oy+top, ox+29, oy+bot, M)
    # diamond crisscross — alternating shadow squares
    # ito knots pattern (5 cols × 5 rows)
    for cx in range(25, 30):
        for ry in range(top, bot + 1):
            # checker pattern for ito wraps
            if (cx + ry) % 2 == 0 and not (cx == 27 and (ry == cy or ry == cy-0)):
                px(d, ox+cx, oy+ry, S)
    # highlight a diagonal
    px(d, ox+25, oy+top, H)
    px(d, ox+29, oy+bot, S)
    # menuki (gold ornament in the middle of grip)
    px(d, ox+27, oy+cy-1, MENUKI_HI)
    px(d, ox+27, oy+cy,   MENUKI)
    px(d, ox+27, oy+cy+1, MENUKI)


def draw_tsuba_v2(d, ox, oy, cy=8):
    """Larger, more visible tsuba at col 24."""
    top, bot = cy - 3, cy + 3
    rect(d, ox+24, oy+top, ox+24, oy+bot, TSUBA)
    # highlight + dark edges
    px(d, ox+24, oy+top, TSUBA_HI)
    px(d, ox+24, oy+bot, TSUBA_HI)
    px(d, ox+24, oy+cy,  TSUBA_DARK)


def draw_pommel_v2(d, ox, oy, cy=8):
    """Pommel (kashira) at col 30."""
    rect(d, ox+30, oy+cy-2, ox+30, oy+cy+2, POMMEL)
    px(d, ox+30, oy+cy-2, POMMEL_HI)


def draw_habaki_v2(d, ox, oy, cy=8):
    """Brass habaki collar at col 23, between blade and tsuba."""
    rect(d, ox+23, oy+cy-2, ox+23, oy+cy+2, HABAKI)
    px(d, ox+23, oy+cy-2, HABAKI_HI)
    px(d, ox+23, oy+cy+2, HABAKI_DARK)


def blade_spine_top(x, x_start=2, x_end=22, base_y=8, curve_h=2.0):
    """Top of blade y — curves UP toward the tip (lower y = higher on screen).
       Returns float y; caller rounds."""
    t = (x_end - x) / (x_end - x_start)
    if t < 0: t = 0
    if t > 1: t = 1
    return base_y - 2 - curve_h * (t * t * 0.6 + t * 0.4)


def blade_edge_bot(x, x_start=2, x_end=22, base_y=8, curve_h=2.0):
    """Bottom (cutting edge) y — also curves up but shifted down ~2px."""
    t = (x_end - x) / (x_end - x_start)
    if t < 0: t = 0
    if t > 1: t = 1
    # at handle: y = base_y; near tip: tapers a little
    if t < 0.85:
        return base_y - curve_h * (t * t * 0.6 + t * 0.4)
    else:
        # near the tip, edge curves up faster to converge to spine
        return base_y - curve_h * (t * t * 0.6 + t * 0.4) - (t - 0.85) * 6


def draw_curved_blade(d, ox, oy, base_y=8, hamon=True):
    """Draws a horizontal curved katana blade from x=2 (tip) to x=22 (habaki)."""
    # Render column-by-column
    for x in range(2, 23):
        y_top = blade_spine_top(x)
        y_bot = blade_edge_bot(x)
        # Round
        y_top_i = int(round(y_top))
        y_bot_i = int(round(y_bot))
        # Ensure at least 1px high near tip
        if y_bot_i < y_top_i:
            y_bot_i = y_top_i
        # Spine (lightest)
        px(d, ox+x, oy+y_top_i, BLADE_HI)
        # Fill between
        for y in range(y_top_i + 1, y_bot_i):
            px(d, ox+x, oy+y, BLADE)
        # Cutting edge (darkest)
        if y_bot_i > y_top_i:
            px(d, ox+x, oy+y_bot_i, BLADE_DARK)
        # Hamon wavy line — just above cutting edge, brighter pixel
        if hamon and x > 4 and y_bot_i - y_top_i >= 2:
            # wave: alternating row offset
            wave = -1 if (x // 2) % 2 == 0 else 0
            hy = y_bot_i - 1 + wave
            if hy > y_top_i and hy < y_bot_i:
                px(d, ox+x, oy+hy, BLADE_HAMON)
    # Pointed tip — a single bright apex pixel at x=2
    px(d, ox+2, oy+int(round(blade_spine_top(2))), BLADE_HI)


# ----------- Frame 1: SHEATHED -------------------------------
def frame_k_sheathed(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    # Saya body — slightly tapered at left tip
    rect(d, ox+2, oy+6, ox+22, oy+10, SAYA)
    px(d, ox+1, oy+8, SAYA)
    px(d, ox+2, oy+5, SAYA)
    px(d, ox+2, oy+11, SAYA)
    # top highlight
    rect(d, ox+3, oy+6, ox+22, oy+6, SAYA_HI)
    # bottom shadow (just slightly darker)
    # kojiri brass tip
    px(d, ox+1, oy+8, SAYA_TIP)
    px(d, ox+2, oy+7, SAYA_TIP)
    px(d, ox+2, oy+9, SAYA_TIP)
    # sageo cord wrap — knots in ninja color around mouth of saya
    px(d, ox+19, oy+5, M); px(d, ox+20, oy+5, M)
    px(d, ox+19, oy+11, M); px(d, ox+20, oy+11, M)
    px(d, ox+20, oy+6, H)
    px(d, ox+20, oy+10, S)
    # koiguchi (mouth ring)
    rect(d, ox+21, oy+6, ox+22, oy+10, (60, 50, 75))

    draw_habaki_v2(d, ox, oy)
    draw_tsuba_v2(d, ox, oy)
    draw_handle_v2(d, p, ox, oy)
    draw_pommel_v2(d, ox, oy)


# ----------- Frame 2: DRAWN ----------------------------------
def frame_k_drawn(d, p, ox, oy):
    draw_curved_blade(d, ox, oy)
    draw_habaki_v2(d, ox, oy)
    draw_tsuba_v2(d, ox, oy)
    draw_handle_v2(d, p, ox, oy)
    draw_pommel_v2(d, ox, oy)


# ----------- Frame 3: RAISED OVERHEAD (vertical) -------------
def frame_k_raised(d, p, ox, oy):
    """Katana vertical, handle bottom, blade up. Blade curves slightly to one side."""
    M, H, S = p['main'], p['hi'], p['shadow']
    cx = ox + 16  # vertical centerline of the frame
    # Vertical blade — 11 rows tall, with slight rightward bow
    for i in range(11):
        # bow factor: blade curves so top tip is offset by 1px
        bow = -1 if i < 4 else 0
        bx = cx + bow
        px(d, bx-1, oy+i, BLADE_HI)   # left highlight
        px(d, bx,   oy+i, BLADE)
        px(d, bx+1, oy+i, BLADE_DARK)
        # hamon brighter pixel
        if i > 1 and i % 2 == 0:
            px(d, bx, oy+i, BLADE_HAMON)
    # Tip — sharper at top
    px(d, cx-1, oy+0, BLADE_HI)
    # Habaki
    rect(d, cx-1, oy+11, cx+1, oy+11, HABAKI)
    px(d, cx, oy+11, HABAKI_HI)
    # Tsuba — wide horizontal bar
    rect(d, cx-3, oy+12, cx+3, oy+12, TSUBA)
    px(d, cx-3, oy+12, TSUBA_HI)
    px(d, cx+3, oy+12, TSUBA_HI)
    # Handle vertical
    rect(d, cx-1, oy+13, cx+1, oy+15, M)
    px(d, cx-1, oy+13, H); px(d, cx+1, oy+13, S)
    px(d, cx-1, oy+15, H); px(d, cx+1, oy+15, S)
    px(d, cx, oy+14, MENUKI_HI)


# ----------- Frame 4: MID-SWING (with motion trail) ----------
def frame_k_mid_swing(d, p, ox, oy):
    # base = drawn
    frame_k_drawn(d, p, ox, oy)
    # Motion-trail streaks behind the blade — semi-transparent white pixels
    for tx, alpha in [(8, 120), (12, 95), (16, 75)]:
        for dy in (-1, 0, 1):
            yy = oy + 8 + dy
            xx = ox + tx
            if 0 <= xx < ox + K_FRAME_W and 0 <= yy < oy + K_FRAME_H:
                d.point((xx, yy), fill=(BLADE_HI[0], BLADE_HI[1], BLADE_HI[2], alpha))
    # Speed-line arc above blade
    for tx, dy in [(5, -3), (8, -3), (11, -2), (14, -2)]:
        d.point((ox+tx, oy + 8 + dy), fill=(255, 255, 230, 150))


# ----------- Frame 5: STRIKE HIT (impact w/ flash at tip) ----
def frame_k_strike_hit(d, p, ox, oy):
    """Katana mid-strike. Blade is at full extension and a strike-flash burst
    is overlaid at the blade tip — perfect for the exact contact frame."""
    frame_k_drawn(d, p, ox, oy)
    # Add a strike flash at the tip (x=2, y=8)
    flash_cx, flash_cy = ox + 2, oy + 8
    # core
    px(d, flash_cx, flash_cy, FLASH_WHITE)
    # 4-point star
    px(d, flash_cx-1, flash_cy, FLASH_CORE)
    px(d, flash_cx+1, flash_cy, FLASH_CORE)
    px(d, flash_cx, flash_cy-1, FLASH_CORE)
    px(d, flash_cx, flash_cy+1, FLASH_CORE)
    # outer points
    for dx, dy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
        ax, ay = flash_cx + dx, flash_cy + dy
        if 0 <= ax < ox + K_FRAME_W and 0 <= ay < oy + K_FRAME_H:
            d.point((ax, ay), fill=rgba(FLASH_MID))
    # diagonal sparks
    for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        ax, ay = flash_cx + dx, flash_cy + dy
        if 0 <= ax < ox + K_FRAME_W and 0 <= ay < oy + K_FRAME_H:
            d.point((ax, ay), fill=rgba(FLASH_MID))


# ----------- Frame 6: FOLLOW-THROUGH (diagonal) --------------
def frame_k_follow_thru(d, p, ox, oy):
    """Diagonal blade pointing down-left after the cut."""
    M, H, S = p['main'], p['hi'], p['shadow']
    # diagonal line from (ox+22, oy+3) toward (ox+4, oy+13)
    x0, y0 = 22, 3
    x1, y1 = 4, 13
    dx, dy = x1 - x0, y1 - y0
    steps = max(abs(dx), abs(dy))
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = round(x0 + dx * t)
        y = round(y0 + dy * t)
        pts.append((x, y))
    # blade thickness — top-right side = highlight, bottom-left = shadow
    for (x, y) in pts:
        px(d, ox+x, oy+y, BLADE)
        px(d, ox+x+1, oy+y, BLADE_HI)
        px(d, ox+x-1, oy+y+1, BLADE_DARK)
    # hamon shimmer along blade
    for i in range(1, steps, 3):
        bx, by = pts[i]
        px(d, ox+bx, oy+by, BLADE_HAMON)
    # tip
    tx, ty = pts[-1]
    px(d, ox+tx-1, oy+ty, BLADE_HI)
    # habaki at start
    sx, sy = pts[0]
    px(d, ox+sx, oy+sy-1, HABAKI_HI)
    px(d, ox+sx+1, oy+sy-1, HABAKI)
    # tsuba block
    px(d, ox+23, oy+2, TSUBA)
    px(d, ox+24, oy+2, TSUBA_HI)
    px(d, ox+23, oy+3, TSUBA)
    # handle diagonal up-right
    handle_pts = [(24, 2), (25, 1), (26, 1), (27, 0), (28, 0)]
    for (hx, hy) in handle_pts:
        px(d, ox+hx, oy+hy, M)
    px(d, ox+25, oy+1, H)
    px(d, ox+27, oy+0, S)
    px(d, ox+26, oy+1, MENUKI)
    # pommel
    px(d, ox+29, oy+0, POMMEL)


K_FRAME_FUNCS = {
    'sheathed':    frame_k_sheathed,
    'drawn':       frame_k_drawn,
    'raised':      frame_k_raised,
    'mid_swing':   frame_k_mid_swing,
    'strike_hit':  frame_k_strike_hit,
    'follow_thru': frame_k_follow_thru,
}


def render_katana_v2(palette):
    img = Image.new('RGBA', (K_STRIP_W, K_STRIP_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, fname in enumerate(K_FRAMES):
        K_FRAME_FUNCS[fname](d, palette, i * K_FRAME_W, 0)
    return img


# ============================================================
#  STRIKE FLASH FX — 24x24, 4 frames
# ============================================================
SF_W, SF_H = 24, 24
SF_FRAMES = ['ignition', 'burst', 'peak', 'fade']
SF_STRIP_W = SF_W * len(SF_FRAMES)


def sf_circle(d, cx, cy, r, color, alpha=255):
    """Filled circle approximation."""
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx*dx + dy*dy <= r*r:
                d.point((cx + dx, cy + dy), fill=(color[0], color[1], color[2], alpha))


def frame_sf_ignition(d, ox, oy):
    cx, cy = ox + 12, oy + 12
    px(d, cx, cy, FLASH_WHITE)
    px(d, cx-1, cy, FLASH_CORE)
    px(d, cx+1, cy, FLASH_CORE)
    px(d, cx, cy-1, FLASH_CORE)
    px(d, cx, cy+1, FLASH_CORE)


def frame_sf_burst(d, ox, oy):
    cx, cy = ox + 12, oy + 12
    # core
    sf_circle(d, cx, cy, 1, FLASH_WHITE)
    # 4-point star arms
    for length, c in [(3, FLASH_CORE), (5, FLASH_MID)]:
        for i in range(1, length + 1):
            for dx, dy in [(i, 0), (-i, 0), (0, i), (0, -i)]:
                d.point((cx + dx, cy + dy), fill=rgba(c))
    # diagonal small sparks
    for dx, dy in [(2, 2), (-2, 2), (2, -2), (-2, -2)]:
        d.point((cx + dx, cy + dy), fill=rgba(FLASH_OUT, 220))


def frame_sf_peak(d, ox, oy):
    cx, cy = ox + 12, oy + 12
    # core
    sf_circle(d, cx, cy, 2, FLASH_WHITE)
    sf_circle(d, cx, cy, 3, FLASH_CORE, alpha=200)
    # long 4-point spike rays
    for length, c, a in [(9, FLASH_MID, 240), (5, FLASH_CORE, 255)]:
        for i in range(2, length + 1):
            for dx, dy in [(i, 0), (-i, 0), (0, i), (0, -i)]:
                d.point((cx + dx, cy + dy), fill=(c[0], c[1], c[2], a))
    # diagonal medium sparks
    for r in (3, 5, 7):
        for dx, dy in [(r, r), (-r, r), (r, -r), (-r, -r)]:
            alpha = 220 if r < 6 else 130
            d.point((cx + dx, cy + dy), fill=rgba(FLASH_OUT, alpha))


def frame_sf_fade(d, ox, oy):
    cx, cy = ox + 12, oy + 12
    # faded core
    sf_circle(d, cx, cy, 1, FLASH_CORE, alpha=140)
    # scattered fading sparks
    rnd = random.Random(7)
    for _ in range(14):
        ang = rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(4, 10)
        sx = int(round(cx + math.cos(ang) * dist))
        sy = int(round(cy + math.sin(ang) * dist))
        if abs(sx - cx) < SF_W // 2 and abs(sy - cy) < SF_H // 2:
            d.point((sx, sy), fill=(FLASH_MID[0], FLASH_MID[1], FLASH_MID[2], 130))
    # tiny X
    for dx, dy in [(2,2),(-2,-2),(2,-2),(-2,2)]:
        d.point((cx+dx, cy+dy), fill=rgba(FLASH_OUT, 100))


SF_FRAME_FUNCS = {
    'ignition': frame_sf_ignition,
    'burst':    frame_sf_burst,
    'peak':     frame_sf_peak,
    'fade':     frame_sf_fade,
}


def render_strike_flash():
    img = Image.new('RGBA', (SF_STRIP_W, SF_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, fname in enumerate(SF_FRAMES):
        SF_FRAME_FUNCS[fname](d, i * SF_W, 0)
    return img


# ============================================================
#  CLASH LIGHTNING FX — 32x32, 5 frames
# ============================================================
CL_W, CL_H = 32, 32
CL_FRAMES = ['contact', 'fork', 'peak', 'fade1', 'fade2']
CL_STRIP_W = CL_W * len(CL_FRAMES)


def jagged_bolt(d, ox, oy, x0, y0, angle_deg, length, segments=4,
                core_color=LIGHT_CORE, outer_color=LIGHT_MID, alpha=255, seed=0):
    """Draws a jagged lightning bolt from (x0,y0) outward at angle.
       Segments alternate slight angle offsets for a zigzag look."""
    rnd = random.Random(seed)
    seg_len = length / segments
    cx, cy = x0, y0
    angle = math.radians(angle_deg)
    for s in range(segments):
        # perturb angle a little each segment
        ang = angle + math.radians(rnd.uniform(-25, 25))
        nx = cx + math.cos(ang) * seg_len
        ny = cy + math.sin(ang) * seg_len
        # rasterize segment with Bresenham-ish line
        steps = max(2, int(seg_len))
        for i in range(steps + 1):
            t = i / steps
            px_x = int(round(cx + (nx - cx) * t))
            px_y = int(round(cy + (ny - cy) * t))
            if 0 <= px_x - ox < CL_W and 0 <= px_y - oy < CL_H:
                # outer glow (thicker)
                for ddx, ddy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    d.point((px_x + ddx, px_y + ddy),
                            fill=(outer_color[0], outer_color[1], outer_color[2],
                                  max(0, alpha - 80)))
                # core line
                d.point((px_x, px_y), fill=(core_color[0], core_color[1], core_color[2], alpha))
        cx, cy = nx, ny
    return cx, cy


def frame_cl_contact(d, ox, oy):
    cx, cy = ox + 16, oy + 16
    sf_circle(d, cx, cy, 1, LIGHT_CORE)
    sf_circle(d, cx, cy, 2, LIGHT_INNER, alpha=210)
    # tiny initial sparks
    for dx, dy in [(2,0),(-2,0),(0,2),(0,-2)]:
        d.point((cx+dx, cy+dy), fill=rgba(LIGHT_MID))


def frame_cl_fork(d, ox, oy):
    cx, cy = ox + 16, oy + 16
    # bright center
    sf_circle(d, cx, cy, 2, LIGHT_CORE)
    sf_circle(d, cx, cy, 3, LIGHT_INNER, alpha=200)
    # 4 short forks at cardinal angles
    for i, ang in enumerate([0, 90, 180, 270]):
        jagged_bolt(d, ox, oy, cx, cy, ang, length=8, segments=3,
                    core_color=LIGHT_CORE, outer_color=LIGHT_MID,
                    alpha=240, seed=i * 7 + 3)
    # 4 small diagonal sparks
    for r, dx, dy in [(4, 3, 3), (4, -3, 3), (4, 3, -3), (4, -3, -3)]:
        d.point((cx+dx, cy+dy), fill=rgba(LIGHT_BLUE, 200))


def frame_cl_peak(d, ox, oy):
    cx, cy = ox + 16, oy + 16
    # blazing core
    sf_circle(d, cx, cy, 3, LIGHT_CORE)
    sf_circle(d, cx, cy, 4, LIGHT_INNER, alpha=180)
    sf_circle(d, cx, cy, 5, LIGHT_MID, alpha=120)
    # 8 main forks (4 cardinal long + 4 diagonal medium)
    for i, ang in enumerate([0, 45, 90, 135, 180, 225, 270, 315]):
        length = 14 if i % 2 == 0 else 11
        jagged_bolt(d, ox, oy, cx, cy, ang, length=length, segments=4,
                    core_color=LIGHT_CORE, outer_color=LIGHT_MID,
                    alpha=255, seed=i * 11 + 5)
    # branching sub-forks from each main bolt — emergent crackles
    for i, ang in enumerate([20, 70, 110, 160, 200, 250, 290, 340]):
        # offset start a bit from center
        sx = cx + int(round(math.cos(math.radians(ang)) * 4))
        sy = cy + int(round(math.sin(math.radians(ang)) * 4))
        jagged_bolt(d, ox, oy, sx, sy, ang, length=6, segments=2,
                    core_color=LIGHT_INNER, outer_color=LIGHT_BLUE,
                    alpha=200, seed=i * 13)
    # subtle purple-edge halo
    rnd = random.Random(42)
    for _ in range(18):
        ang = rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(10, 14)
        sx = int(round(cx + math.cos(ang) * dist))
        sy = int(round(cy + math.sin(ang) * dist))
        if 0 <= sx - ox < CL_W and 0 <= sy - oy < CL_H:
            d.point((sx, sy), fill=rgba(LIGHT_PURPLE, 130))


def frame_cl_fade1(d, ox, oy):
    cx, cy = ox + 16, oy + 16
    sf_circle(d, cx, cy, 2, LIGHT_INNER, alpha=180)
    # retracting forks — shorter
    for i, ang in enumerate([0, 90, 180, 270]):
        jagged_bolt(d, ox, oy, cx, cy, ang, length=7, segments=3,
                    core_color=LIGHT_INNER, outer_color=LIGHT_BLUE,
                    alpha=180, seed=i * 17 + 11)
    # scattered remaining sparks
    rnd = random.Random(99)
    for _ in range(14):
        ang = rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(5, 11)
        sx = int(round(cx + math.cos(ang) * dist))
        sy = int(round(cy + math.sin(ang) * dist))
        if 0 <= sx - ox < CL_W and 0 <= sy - oy < CL_H:
            d.point((sx, sy), fill=rgba(LIGHT_MID, 180))


def frame_cl_fade2(d, ox, oy):
    cx, cy = ox + 16, oy + 16
    # ghost core
    sf_circle(d, cx, cy, 1, LIGHT_INNER, alpha=110)
    # very few fading sparks
    rnd = random.Random(123)
    for _ in range(10):
        ang = rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(6, 13)
        sx = int(round(cx + math.cos(ang) * dist))
        sy = int(round(cy + math.sin(ang) * dist))
        if 0 <= sx - ox < CL_W and 0 <= sy - oy < CL_H:
            d.point((sx, sy), fill=rgba(LIGHT_BLUE, 120))
    # a couple of purple wisps
    for _ in range(4):
        ang = rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(8, 14)
        sx = int(round(cx + math.cos(ang) * dist))
        sy = int(round(cy + math.sin(ang) * dist))
        if 0 <= sx - ox < CL_W and 0 <= sy - oy < CL_H:
            d.point((sx, sy), fill=rgba(LIGHT_PURPLE, 110))


CL_FRAME_FUNCS = {
    'contact': frame_cl_contact,
    'fork':    frame_cl_fork,
    'peak':    frame_cl_peak,
    'fade1':   frame_cl_fade1,
    'fade2':   frame_cl_fade2,
}


def render_clash_lightning():
    img = Image.new('RGBA', (CL_STRIP_W, CL_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, fname in enumerate(CL_FRAMES):
        CL_FRAME_FUNCS[fname](d, i * CL_W, 0)
    return img


# ============================================================
#  Render everything + save
# ============================================================
# Output locally, relative to this script's place in the prototype tree.
#   <script dir> == prototypes/movement-and-combat/sprites/katanas/katana_v2
#   → katana V2 strips stay here; combat FX go to sprites/fx (sibling of katanas).
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KATANA_DIR  = _SCRIPT_DIR
FX_DIR      = os.path.normpath(os.path.join(_SCRIPT_DIR, '..', '..', 'fx'))
os.makedirs(KATANA_DIR, exist_ok=True)
os.makedirs(FX_DIR, exist_ok=True)

# --- Katana V2 (4 colors) ---
for name, palette in PALETTES.items():
    strip = render_katana_v2(palette)
    strip.save(f'{KATANA_DIR}/katana_{name}_v2_6frame_native_192x16.png')
    strip.resize((K_STRIP_W*4, K_STRIP_H*4), Image.NEAREST).save(
        f'{KATANA_DIR}/katana_{name}_v2_6frame_4x_768x64.png'
    )
    strip.resize((K_STRIP_W*8, K_STRIP_H*8), Image.NEAREST).save(
        f'{KATANA_DIR}/katana_{name}_v2_6frame_8x_1536x128.png'
    )
    print(f'Wrote katana_{name}_v2')

# Combined V2 katana preview
preview_h = (K_STRIP_H * 8 + 8) * 4
katana_preview = Image.new('RGBA', (K_STRIP_W * 8, preview_h), (24, 18, 36, 255))
y_off = 0
for name in ['cyan', 'magenta', 'orange', 'green']:
    s = Image.open(f'{KATANA_DIR}/katana_{name}_v2_6frame_8x_1536x128.png')
    katana_preview.paste(s, (0, y_off), s)
    y_off += K_STRIP_H * 8 + 8
katana_preview.save(f'{KATANA_DIR}/katanas_v2_preview_all.png')
print('Wrote katanas_v2_preview_all.png')

# --- Strike flash FX ---
sf_strip = render_strike_flash()
sf_strip.save(f'{FX_DIR}/strike_flash_4frame_native_96x24.png')
sf_strip.resize((SF_STRIP_W*4, SF_H*4), Image.NEAREST).save(
    f'{FX_DIR}/strike_flash_4frame_4x_384x96.png'
)
sf_strip.resize((SF_STRIP_W*8, SF_H*8), Image.NEAREST).save(
    f'{FX_DIR}/strike_flash_4frame_8x_768x192.png'
)
print('Wrote strike_flash FX')

# --- Clash lightning FX ---
cl_strip = render_clash_lightning()
cl_strip.save(f'{FX_DIR}/clash_lightning_5frame_native_160x32.png')
cl_strip.resize((CL_STRIP_W*4, CL_H*4), Image.NEAREST).save(
    f'{FX_DIR}/clash_lightning_5frame_4x_640x128.png'
)
cl_strip.resize((CL_STRIP_W*8, CL_H*8), Image.NEAREST).save(
    f'{FX_DIR}/clash_lightning_5frame_8x_1280x256.png'
)
print('Wrote clash_lightning FX')

# --- Combined FX preview ---
fx_preview_w = max(SF_STRIP_W * 8, CL_STRIP_W * 8)
fx_preview_h = SF_H * 8 + 16 + CL_H * 8
fx_preview = Image.new('RGBA', (fx_preview_w, fx_preview_h), (18, 14, 30, 255))
sf_big = Image.open(f'{FX_DIR}/strike_flash_4frame_8x_768x192.png')
cl_big = Image.open(f'{FX_DIR}/clash_lightning_5frame_8x_1280x256.png')
fx_preview.paste(sf_big, (0, 0), sf_big)
fx_preview.paste(cl_big, (0, SF_H * 8 + 16), cl_big)
fx_preview.save(f'{FX_DIR}/combat_fx_preview.png')
print('Wrote combat_fx_preview.png')
