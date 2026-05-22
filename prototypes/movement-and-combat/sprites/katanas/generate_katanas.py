"""
Katana weapon sprites for each ninja color.

Each color has 6 frames laid out on a 24x16 canvas:
  Frame 1: sheathed   — katana in its saya (scabbard), held horizontal
  Frame 2: drawn      — bare blade, held horizontal
  Frame 3: raised     — katana raised overhead, vertical
  Frame 4: mid_swing  — horizontal mid-swing with motion-trail streaks
  Frame 5: follow_thru— diagonal follow-through after the cut
  Frame 6: slash_fx   — pure slash arc (no katana) — drop-in attack FX

The grip's ito (cord wrap) and the saya's sageo (binding cord) take the
ninja's main color, so each katana visually belongs to its archer.
"""

from PIL import Image, ImageDraw

FRAME_W, FRAME_H = 24, 16
FRAMES = ['sheathed', 'drawn', 'raised', 'mid_swing', 'follow_thru', 'slash_fx']
STRIP_W = FRAME_W * len(FRAMES)   # 144
STRIP_H = FRAME_H                  # 16

# Ninja palette (same as character sprites)
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

# Universal katana colors
BLADE_HI    = (245, 248, 255)   # top edge of the blade (shinogi line)
BLADE       = (195, 200, 215)   # main silver
BLADE_DARK  = (125, 130, 150)   # bottom shadow
TSUBA       = (38, 32, 50)      # iron guard
TSUBA_HI    = (95, 90, 115)
MENUKI      = (210, 170, 60)    # tiny gold ornament on the grip
MENUKI_HI   = (255, 220, 110)
POMMEL      = (28, 24, 38)      # kashira (pommel cap)
POMMEL_HI   = (70, 60, 85)
SAYA        = (15, 11, 20)      # black lacquer scabbard
SAYA_HI     = (45, 38, 60)
SAYA_TIP    = (90, 75, 50)      # kojiri (tip cap, brass)
SLASH_OUT   = (255, 240, 200)
SLASH_IN    = (255, 255, 255)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c, a=255):
    d.point((x, y), fill=rgba(c, a))


def rect(d, x1, y1, x2, y2, c):
    if x2 < x1 or y2 < y1:
        return
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# ============================================================
# Frame 1 — SHEATHED (horizontal, handle on right)
# Layout: scabbard cols 1..16, tsuba col 17, handle cols 18..21, pommel col 22
# ============================================================
def draw_sheathed(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']

    # Scabbard (saya) — slightly tapered at left tip
    rect(d, ox+2, oy+7, ox+16, oy+9, SAYA)
    px(d, ox+1, oy+8, SAYA)            # tip
    rect(d, ox+2, oy+7, ox+16, oy+7, SAYA_HI)    # top highlight stripe
    # kojiri (brass tip)
    px(d, ox+2, oy+7, SAYA_TIP)
    px(d, ox+2, oy+8, SAYA_TIP)
    px(d, ox+2, oy+9, SAYA_TIP)
    # koiguchi (mouth of scabbard) — small reinforced ring near tsuba
    rect(d, ox+15, oy+7, ox+16, oy+9, (60, 50, 75))

    # sageo cord wrap — short tied loops in ninja color around the saya mouth
    px(d, ox+13, oy+6, M)
    px(d, ox+14, oy+6, M)
    px(d, ox+13, oy+10, M)
    px(d, ox+14, oy+10, M)
    px(d, ox+14, oy+7, H)   # bright highlight knot
    px(d, ox+14, oy+9, S)

    # Tsuba (guard)
    rect(d, ox+17, oy+6, ox+17, oy+10, TSUBA)
    px(d, ox+17, oy+6, TSUBA_HI)
    px(d, ox+17, oy+10, TSUBA_HI)

    # Handle (tsuka) with ito wrap — diamond/crisscross pattern
    rect(d, ox+18, oy+7, ox+21, oy+9, M)
    # ito wrap diamonds — alternating darker squares
    px(d, ox+19, oy+8, S)
    px(d, ox+21, oy+8, S)
    px(d, ox+18, oy+7, H)
    px(d, ox+20, oy+7, H)
    px(d, ox+18, oy+9, H)
    px(d, ox+20, oy+9, H)
    # menuki (small gold ornament)
    px(d, ox+19, oy+7, MENUKI_HI)
    px(d, ox+19, oy+9, MENUKI)

    # Pommel (kashira)
    rect(d, ox+22, oy+7, ox+22, oy+9, POMMEL)
    px(d, ox+22, oy+7, POMMEL_HI)


# ============================================================
# Frame 2 — DRAWN (horizontal, blade visible, handle on right)
# ============================================================
def draw_drawn(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']

    # Blade — silver with edge highlight on top, shadow on bottom
    rect(d, ox+2, oy+8, ox+16, oy+8, BLADE)          # main blade body
    rect(d, ox+2, oy+7, ox+16, oy+7, BLADE_HI)       # top shinogi-ji
    rect(d, ox+3, oy+9, ox+16, oy+9, BLADE_DARK)     # bottom shadow / cutting edge
    # kissaki (pointed tip) — taper at left
    px(d, ox+1, oy+8, BLADE)
    px(d, ox+0, oy+8, BLADE_HI)
    px(d, ox+1, oy+7, BLADE_HI)
    px(d, ox+2, oy+9, BLADE)    # soften bottom of tip
    # habaki (collar at base of blade)
    rect(d, ox+16, oy+7, ox+16, oy+9, (170, 130, 60))
    px(d, ox+16, oy+7, (220, 180, 90))

    # Tsuba
    rect(d, ox+17, oy+6, ox+17, oy+10, TSUBA)
    px(d, ox+17, oy+6, TSUBA_HI)
    px(d, ox+17, oy+10, TSUBA_HI)

    # Handle (tsuka) — same as sheathed
    rect(d, ox+18, oy+7, ox+21, oy+9, M)
    px(d, ox+19, oy+8, S);  px(d, ox+21, oy+8, S)
    px(d, ox+18, oy+7, H);  px(d, ox+20, oy+7, H)
    px(d, ox+18, oy+9, H);  px(d, ox+20, oy+9, H)
    px(d, ox+19, oy+7, MENUKI_HI)
    px(d, ox+19, oy+9, MENUKI)

    # Pommel
    rect(d, ox+22, oy+7, ox+22, oy+9, POMMEL)
    px(d, ox+22, oy+7, POMMEL_HI)


# ============================================================
# Frame 3 — RAISED OVERHEAD (vertical, handle bottom, blade up)
# ============================================================
def draw_raised(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']

    # Blade vertical — centered at col 12 of the frame
    cx = ox + 12
    # kissaki tip
    px(d, cx, oy+0, BLADE_HI)
    px(d, cx-1, oy+1, BLADE_HI)
    px(d, cx, oy+1, BLADE)
    # main blade
    for y in range(2, 11):
        px(d, cx-1, oy+y, BLADE_HI)
        px(d, cx,   oy+y, BLADE)
        px(d, cx+1, oy+y, BLADE_DARK)
    # habaki
    px(d, cx-1, oy+11, (220, 180, 90))
    px(d, cx,   oy+11, (170, 130, 60))
    px(d, cx+1, oy+11, (170, 130, 60))

    # Tsuba — horizontal bar
    rect(d, cx-2, oy+12, cx+2, oy+12, TSUBA)
    px(d, cx-2, oy+12, TSUBA_HI)
    px(d, cx+2, oy+12, TSUBA_HI)

    # Handle — vertical
    rect(d, cx-1, oy+13, cx+1, oy+15, M)
    px(d, cx-1, oy+13, H);   px(d, cx+1, oy+13, S)
    px(d, cx-1, oy+15, H);   px(d, cx+1, oy+15, S)
    # menuki
    px(d, cx, oy+14, MENUKI_HI)


# ============================================================
# Frame 4 — MID-SWING (horizontal blade with motion trail)
# ============================================================
def draw_mid_swing(d, p, ox, oy):
    # base = drawn pose
    draw_drawn(d, p, ox, oy)
    # motion-trail streaks behind the blade (further into the past)
    streak_y = oy + 8
    for x, alpha in [(ox+5, 110), (ox+7, 80), (ox+9, 60)]:
        for dy in (-1, 0, 1):
            yy = streak_y + dy
            if 0 <= yy < oy + FRAME_H:
                d.point((x, yy), fill=(BLADE_HI[0], BLADE_HI[1], BLADE_HI[2], alpha))
    # arc highlight above blade
    for x, dy in [(ox+3, -2), (ox+5, -2), (ox+7, -1), (ox+9, -1)]:
        d.point((x, oy + 8 + dy), fill=(255, 255, 230, 140))


# ============================================================
# Frame 5 — FOLLOW-THROUGH (diagonal blade pointing down-right)
# Uses Bresenham-style diagonal line for the blade.
# Handle near top-left, blade extending toward bottom-right.
# ============================================================
def draw_follow_thru(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']

    # Blade — diagonal line from (ox+18, oy+2) toward (ox+4, oy+14)
    # Walk the line and draw 2-px-thick blade
    pts = []
    x0, y0 = 17, 3
    x1, y1 = 5, 13
    dx = x1 - x0
    dy = y1 - y0
    steps = max(abs(dx), abs(dy))
    for i in range(steps + 1):
        t = i / steps
        x = round(x0 + dx * t)
        y = round(y0 + dy * t)
        pts.append((x, y))

    # Draw blade thickness — top-right side = highlight, bottom-left = shadow
    for (x, y) in pts:
        # main blade
        px(d, ox+x, oy+y, BLADE)
        # highlight on upper-right
        px(d, ox+x+1, oy+y, BLADE_HI)
        # shadow on lower-left
        px(d, ox+x-1, oy+y+1, BLADE_DARK)

    # kissaki (tip) at the bottom-left end
    bx, by = pts[-1]
    px(d, ox+bx-1, oy+by, BLADE_HI)
    px(d, ox+bx-1, oy+by+1, BLADE)

    # habaki near the base (top-right end of blade)
    hx, hy = pts[0]
    px(d, ox+hx, oy+hy-1, (220, 180, 90))
    px(d, ox+hx+1, oy+hy-1, (170, 130, 60))

    # Tsuba — small dark cluster at the base of the blade
    px(d, ox+18, oy+2, TSUBA)
    px(d, ox+19, oy+2, TSUBA_HI)
    px(d, ox+18, oy+3, TSUBA)

    # Handle — at top-right of the frame, diagonal toward upper-right
    handle_pts = [(19, 2), (20, 1), (21, 1), (22, 0)]
    for (hx, hy) in handle_pts:
        px(d, ox+hx, oy+hy, M)
    # ito accents
    px(d, ox+20, oy+1, H)
    px(d, ox+22, oy+0, S)
    px(d, ox+21, oy+1, MENUKI)

    # Pommel
    px(d, ox+23, oy+0, POMMEL)


# ============================================================
# Frame 6 — SLASH FX (curved arc, no katana — use as separate slash effect)
# ============================================================
def draw_slash_fx(d, p, ox, oy):
    # crescent arc — built from a curved cluster of pixels
    # outer arc
    arc_outer = [
        (3, 11), (4, 9), (5, 8), (6, 7), (7, 6), (8, 5), (9, 4),
        (11, 3), (13, 3), (15, 4), (17, 5), (18, 6), (19, 7), (20, 9), (21, 10)
    ]
    arc_inner = [
        (5, 11), (6, 10), (7, 9), (8, 8), (9, 7), (10, 6), (11, 5),
        (12, 5), (13, 5), (14, 5), (15, 6), (16, 7), (17, 8), (18, 9), (19, 10)
    ]
    arc_core = [
        (7, 10), (8, 9), (9, 8), (10, 7), (11, 6), (12, 6), (13, 6),
        (14, 6), (15, 7), (16, 8), (17, 9)
    ]
    # outer — outline with ninja color tint
    M = p['main']
    for (x, y) in arc_outer:
        d.point((ox + x, oy + y), fill=(SLASH_OUT[0], SLASH_OUT[1], SLASH_OUT[2], 200))
    for (x, y) in arc_inner:
        d.point((ox + x, oy + y), fill=(SLASH_IN[0], SLASH_IN[1], SLASH_IN[2], 255))
    for (x, y) in arc_core:
        d.point((ox + x, oy + y), fill=rgba(M))
    # speed lines trailing the arc
    for (sx, sy) in [(2, 13), (4, 12), (20, 12), (22, 13)]:
        d.point((ox + sx, oy + sy), fill=(SLASH_OUT[0], SLASH_OUT[1], SLASH_OUT[2], 160))


FRAME_FUNCS = {
    'sheathed':    draw_sheathed,
    'drawn':       draw_drawn,
    'raised':      draw_raised,
    'mid_swing':   draw_mid_swing,
    'follow_thru': draw_follow_thru,
    'slash_fx':    draw_slash_fx,
}


def render_katana_strip(palette):
    img = Image.new('RGBA', (STRIP_W, STRIP_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, fname in enumerate(FRAMES):
        FRAME_FUNCS[fname](d, palette, i * FRAME_W, 0)
    return img


import os
OUT = '/sessions/nice-zen-rubin/mnt/outputs/ninjas/katanas'
os.makedirs(OUT, exist_ok=True)

for name, palette in PALETTES.items():
    strip = render_katana_strip(palette)
    strip.save(f'{OUT}/katana_{name}_6frame_native_144x16.png')
    strip.resize((STRIP_W*4, STRIP_H*4), Image.NEAREST).save(
        f'{OUT}/katana_{name}_6frame_4x_576x64.png'
    )
    strip.resize((STRIP_W*8, STRIP_H*8), Image.NEAREST).save(
        f'{OUT}/katana_{name}_6frame_8x_1152x128.png'
    )
    print(f'Wrote katana_{name} (native, 4x, 8x)')

# Combined preview — 4 katanas stacked
preview = Image.new('RGBA', (STRIP_W * 8, (STRIP_H * 8 + 8) * 4), (24, 18, 36, 255))
y_off = 0
for name in ['cyan', 'magenta', 'orange', 'green']:
    s = Image.open(f'{OUT}/katana_{name}_6frame_8x_1152x128.png')
    preview.paste(s, (0, y_off), s)
    y_off += STRIP_H * 8 + 8
preview.save(f'{OUT}/katanas_preview_all.png')
print('Wrote katanas_preview_all.png')
