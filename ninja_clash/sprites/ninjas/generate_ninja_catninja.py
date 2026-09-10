"""
BAKENEKO — a premium, extra-detailed ninja cat (the most detailed skin yet).
A two-tailed cat yokai dressed as a shinobi: a full cloth hood with the cat ears
poking through (one battle-notched), glowing amber slit-eyes, a pink nose under a
ninja mask band, whiskers, a clan obi sash + chest crest, a flowing scarf, glove-
wrapped paws, twin flicking tails, and a katana on the back. The clan COLOUR is
carried by the fur (ears/face/tails) + sash/scarf/trim so the four clans read at
a glance; the dark shinobi cloth stays constant.

Front-view face (clean horizontal flip). Grips the clan katana in the swing like
the base ninja (the game overlays the clan blade sprite + slash_fx on top).

Output into costumes/bakeneko/ (skin-path convention):
  <color>_native_80x16.png              5-pose sheet (idle/walk1/walk2/jump/attack)
  <color>_idle_6frame_native_96x16.png  6-frame idle (breathing + scarf/tail/ear)
  <color>_walk_6frame_native_96x16.png  6-frame run cycle (tails trailing)
  <color>_swing_6frame_native_96x16.png 6-frame katana body swing
(+ _4x / _8x pose upscales, plus _bakeneko_preview.png)
"""

import os
from PIL import Image, ImageDraw

SPRITE = 16
OUT = os.path.dirname(os.path.abspath(__file__))
COST = os.path.join(OUT, "costumes", "bakeneko")
os.makedirs(COST, exist_ok=True)

CLANS = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}
TRANSPARENT = (0, 0, 0, 0)

# shinobi cloth (constant) + accents
CLOTH, CLOTH_HI, CLOTH_SH = (42, 40, 58), (64, 62, 86), (24, 22, 36)
TABI = (16, 14, 24)
GLOVE = (92, 88, 118)
AMBER, AMBER_HI = (255, 206, 92), (255, 238, 176)
SLIT = (58, 30, 18)
NOSE = (246, 150, 172)
EAR_IN = (250, 182, 200)
WH = (236, 238, 248)
SWORD_GRIP = (95, 60, 32)
SWORD_EDGE = (130, 135, 150)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


def draw_back(d, clan, ox, oy):
    # katana strapped diagonally on the back
    px(d, ox + 12, oy + 0, SWORD_GRIP)
    px(d, ox + 13, oy + 1, SWORD_GRIP)
    px(d, ox + 12, oy + 1, SWORD_EDGE)
    px(d, ox + 13, oy + 2, SWORD_EDGE)


def draw_head(d, clan, ox, oy, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    # ---- shinobi hood (frames the face) ----
    rect(d, ox + 3, oy + 1, ox + 12, oy + 6, CLOTH)
    rect(d, ox + 4, oy + 0, ox + 11, oy + 0, CLOTH)
    rect(d, ox + 3, oy + 1, ox + 3, oy + 6, CLOTH_HI)
    rect(d, ox + 12, oy + 1, ox + 12, oy + 6, CLOTH_SH)
    px(d, ox + 4, oy + 1, CLOTH_HI)
    # ---- ears poking through the hood (one battle-notched) ----
    et = oy - (1 if anim else 0)
    rect(d, ox + 4, et + 0, ox + 5, et + 0, M); px(d, ox + 5, oy + 1, EAR_IN)
    rect(d, ox + 10, et + 0, ox + 11, et + 0, M); px(d, ox + 10, oy + 1, EAR_IN)
    px(d, ox + 11, et + 0, CLOTH_SH)   # notched right ear tip
    # ---- fur face opening ----
    rect(d, ox + 5, oy + 2, ox + 10, oy + 5, M)
    rect(d, ox + 5, oy + 2, ox + 5, oy + 5, H)
    rect(d, ox + 10, oy + 2, ox + 10, oy + 5, S)
    px(d, ox + 4, oy + 2, H); px(d, ox + 11, oy + 2, S)   # clan hood trim
    # ---- glowing amber slit-eyes ----
    px(d, ox + 5, oy + 3, AMBER_HI); px(d, ox + 6, oy + 3, AMBER)
    px(d, ox + 9, oy + 3, AMBER);    px(d, ox + 10, oy + 3, AMBER_HI)
    px(d, ox + 6, oy + 3, SLIT if not anim else AMBER)   # blink: slit shows when calm
    px(d, ox + 9, oy + 3, SLIT if not anim else AMBER)
    # ---- pink nose ----
    px(d, ox + 7, oy + 4, NOSE); px(d, ox + 8, oy + 4, NOSE)
    # ---- ninja mask band over the muzzle ----
    rect(d, ox + 5, oy + 5, ox + 10, oy + 5, CLOTH)
    px(d, ox + 5, oy + 5, CLOTH_HI); px(d, ox + 10, oy + 5, CLOTH_SH)
    rect(d, ox + 5, oy + 6, ox + 10, oy + 6, CLOTH_SH)
    # ---- whiskers ----
    px(d, ox + 3, oy + 4, WH); px(d, ox + 2, oy + 5, WH)
    px(d, ox + 12, oy + 4, WH); px(d, ox + 13, oy + 5, WH)


def draw_torso(d, clan, ox, oy, by_off, tail=True, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    by = oy + by_off
    # gi cloth
    rect(d, ox + 3, by, ox + 12, by + 3, CLOTH)
    rect(d, ox + 3, by, ox + 3, by + 3, CLOTH_HI)
    rect(d, ox + 12, by, ox + 12, by + 3, CLOTH_SH)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, CLOTH_SH)
    # clan shoulder rivets + chest crest
    px(d, ox + 3, by, H); px(d, ox + 12, by, S)
    px(d, ox + 7, by, H); px(d, ox + 8, by, H)
    # clan obi sash + knot
    rect(d, ox + 4, by + 1, ox + 11, by + 1, M)
    px(d, ox + 11, by + 1, S)
    px(d, ox + 7, by + 2, H); px(d, ox + 8, by + 2, M)
    # flowing scarf trailing front (left), animated
    if anim:
        px(d, ox + 2, by - 1, H); px(d, ox + 2, by, M); px(d, ox + 1, by, H)
    else:
        px(d, ox + 2, by, H); px(d, ox + 1, by + 1, M); px(d, ox + 2, by + 1, H)
    # twin flicking tails at the back-right
    if tail:
        ty = -1 if anim else 0
        px(d, ox + 13, by + ty, M); px(d, ox + 14, by - 1 + ty, H); px(d, ox + 14, by - 2 + ty, CLOTH_SH)
        px(d, ox + 13, by + 2, M); px(d, ox + 14, by + 2, M); px(d, ox + 14, by + 1, H)


def draw_leg(d, clan, x, top, bot, foot_y, ox, oy):
    rect(d, ox + x, oy + top, ox + x + 2, oy + bot, CLOTH)
    for yy in range(top, bot + 1):
        px(d, ox + x + 2, oy + yy, CLOTH_SH)
    px(d, ox + x, oy + top, clan['main'])   # clan cuff at the hip
    px(d, ox + x + 1, oy + top, clan['shadow'])
    rect(d, ox + x, oy + foot_y, ox + x + 2, oy + foot_y, TABI)


# --- shared frame data (matches the other rich skins) ---------------------
POSE_ORDER = ['idle', 'walk1', 'walk2', 'jump', 'attack']

IDLE = [{'dy': 0, 'a': 0}, {'dy': 0, 'a': 1}, {'dy': -1, 'a': 1},
        {'dy': -1, 'a': 0}, {'dy': 0, 'a': 0}, {'dy': 0, 'a': 1}]

WALK = [
    {'dy': 0,  'L': (3, 11, 13, 13), 'R': (10, 11, 14, 14), 'a': 0},
    {'dy': -1, 'L': (4, 11, 14, 14), 'R': (9, 10, 12, 12),  'a': 1},
    {'dy': 0,  'L': (5, 11, 13, 13), 'R': (9, 11, 14, 14),  'a': 0},
    {'dy': 0,  'L': (3, 11, 14, 14), 'R': (10, 11, 13, 13), 'a': 0},
    {'dy': -1, 'L': (5, 10, 12, 12), 'R': (9, 11, 14, 14),  'a': 1},
    {'dy': 0,  'L': (4, 11, 13, 13), 'R': (10, 11, 14, 14), 'a': 0},
]

SWING = [
    {'lean': 1,  'hands': [(12, 3), (13, 4)], 'arm_from': (10, 8),
     'L': (5, 11, 14, 14), 'R': (9, 11, 14, 14)},
    {'lean': 1,  'hands': [(9, 2), (10, 3)],  'arm_from': (9, 8),
     'L': (5, 11, 14, 14), 'R': (9, 11, 14, 14)},
    {'lean': 0,  'hands': [(6, 4), (7, 5)],   'arm_from': (7, 8),
     'L': (4, 11, 14, 14), 'R': (9, 11, 14, 14)},
    {'lean': -2, 'hands': [(2, 8), (3, 9)],   'arm_from': (5, 8),
     'L': (1, 12, 14, 14), 'R': (10, 11, 14, 14)},
    {'lean': -2, 'hands': [(1, 10), (2, 11)], 'arm_from': (5, 9),
     'L': (1, 12, 14, 14), 'R': (11, 11, 14, 14)},
    {'lean': 0,  'hands': [(4, 7), (5, 8)],   'arm_from': (6, 8),
     'L': (4, 11, 14, 14), 'R': (9, 11, 14, 14)},
]


def pose(clan, d, ox, oy, which):
    if which == 'jump':
        draw_back(d, clan, ox, oy - 1); draw_head(d, clan, ox, oy - 1); draw_torso(d, clan, ox, oy - 1, 7)
        draw_leg(d, clan, 4, 10, 11, 12, ox, oy); draw_leg(d, clan, 9, 10, 11, 12, ox, oy)
        return
    if which != 'attack':
        draw_back(d, clan, ox, oy)
    draw_head(d, clan, ox, oy); draw_torso(d, clan, ox, oy, 7)
    if which == 'idle':
        draw_leg(d, clan, 4, 11, 12, 13, ox, oy); draw_leg(d, clan, 9, 11, 12, 13, ox, oy)
    elif which == 'walk1':
        draw_leg(d, clan, 3, 11, 12, 13, ox, oy); draw_leg(d, clan, 9, 11, 13, 14, ox, oy)
    elif which == 'walk2':
        draw_leg(d, clan, 4, 11, 13, 14, ox, oy); draw_leg(d, clan, 10, 11, 12, 13, ox, oy)
    elif which == 'attack':
        px(d, ox + 2, oy + 9, GLOVE); px(d, ox + 1, oy + 10, clan['hi']); px(d, ox + 2, oy + 10, CLOTH_SH)
        draw_leg(d, clan, 3, 11, 13, 14, ox, oy); draw_leg(d, clan, 10, 11, 12, 13, ox, oy)


def idle6(clan, d, ox, oy, f):
    e = IDLE[f]; dy = e['dy']
    draw_back(d, clan, ox, oy + dy); draw_head(d, clan, ox, oy + dy, e['a']); draw_torso(d, clan, ox, oy + dy, 7, True, e['a'])
    draw_leg(d, clan, 4, 11, 12, 13, ox, oy); draw_leg(d, clan, 9, 11, 12, 13, ox, oy)


def walk6(clan, d, ox, oy, f):
    e = WALK[f]; dy = e['dy']
    draw_back(d, clan, ox, oy + dy); draw_head(d, clan, ox, oy + dy, e['a']); draw_torso(d, clan, ox, oy + dy, 7, True, e['a'])
    draw_leg(d, clan, *e['L'], ox, oy); draw_leg(d, clan, *e['R'], ox, oy)


def swing6(clan, d, ox, oy, f):
    e = SWING[f]; lean = e['lean']
    draw_head(d, clan, ox + lean, oy, 0); draw_torso(d, clan, ox + lean, oy, 7, False, 0)
    draw_leg(d, clan, *e['L'], ox, oy); draw_leg(d, clan, *e['R'], ox, oy)
    sx, sy = e['arm_from']; hx, hy = e['hands'][0]
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    for i in range(steps + 1):
        ax = round(sx + (hx - sx) * i / steps); ay = round(sy + (hy - sy) * i / steps)
        px(d, ox + ax, oy + ay, GLOVE)
    for j, (hx, hy) in enumerate(e['hands']):
        px(d, ox + hx, oy + hy, clan['hi'] if j == 0 else clan['main'])


def render_poses(clan):
    img = Image.new('RGBA', (SPRITE * 5, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, w in enumerate(POSE_ORDER):
        pose(clan, d, i * SPRITE, 0, w)
    return img


def render_strip6(fn, clan):
    img = Image.new('RGBA', (SPRITE * 6, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i in range(6):
        fn(clan, d, i * SPRITE, 0, i)
    return img


def main():
    rows = []
    for color, clan in CLANS.items():
        poses = render_poses(clan)
        idle = render_strip6(idle6, clan)
        walk = render_strip6(walk6, clan)
        swing = render_strip6(swing6, clan)
        poses.save(os.path.join(COST, f'{color}_native_80x16.png'))
        poses.resize((80 * 4, 16 * 4), Image.NEAREST).save(os.path.join(COST, f'{color}_4x_320x64.png'))
        poses.resize((80 * 8, 16 * 8), Image.NEAREST).save(os.path.join(COST, f'{color}_8x_640x128.png'))
        idle.save(os.path.join(COST, f'{color}_idle_6frame_native_96x16.png'))
        walk.save(os.path.join(COST, f'{color}_walk_6frame_native_96x16.png'))
        swing.save(os.path.join(COST, f'{color}_swing_6frame_native_96x16.png'))
        rows.append((color, [poses, idle, walk, swing]))
        print('wrote bakeneko', color)

    scale, pad = 10, 6
    sheets_per = 4
    w = SPRITE * 6 * scale + pad * 2
    h = len(rows) * sheets_per * (SPRITE * scale + pad) + pad
    pv = Image.new('RGBA', (w, h), (26, 22, 34, 255))
    y = pad
    for _, sheets in rows:
        for s in sheets:
            big = s.resize((s.size[0] * scale, s.size[1] * scale), Image.NEAREST)
            pv.paste(big, (pad, y), big)
            y += SPRITE * scale + pad
    pv.save(os.path.join(COST, '_bakeneko_preview.png'))
    print('wrote _bakeneko_preview.png')


if __name__ == '__main__':
    main()
