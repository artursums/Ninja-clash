"""
Richer movement + a real katana swing for the 4 base ninja clans.

Two NEW sprite strips per colour, on top of the existing 5-pose sheet
(generate_ninjas.py). The game loads these as extra "walk" / "swing" visual
modes (player.gd), the same way it already swaps in the 6-frame idle sheet:

  ninja_<color>_walk_6frame_native_96x16.png   full 6-step run cycle (was 2 frames)
  ninja_<color>_swing_6frame_native_96x16.png  overhead katana slash: windup -> strike -> recover

Native 16x16 cells, 6 frames each -> 96x16, upscaled 4x/8x with NEAREST.
Palette + head/torso geometry are copied from generate_ninjas.py so these
frames line up seamlessly with the idle/jump poses already in game.
"""

import os
from PIL import Image, ImageDraw

SPRITE = 16
N = 6
SHEET_W = SPRITE * N   # 96
SHEET_H = SPRITE       # 16

OUT = os.path.dirname(os.path.abspath(__file__))

# --- palette (matches generate_ninjas.py) ---------------------------------
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}
MASK_BLACK  = (20, 16, 30)
EYE_GLOW    = (255, 240, 90)
SASH        = (245, 240, 225)
SASH_SHADE  = (170, 160, 145)
FOOT        = (32, 26, 42)
SWORD_GRIP  = (95, 60, 32)
SWORD_EDGE  = (130, 135, 150)
TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# --- shared body parts (copied from generate_ninjas.py) -------------------
def draw_sword_on_back(d, ox, oy):
    px(d, ox + 12, oy + 0, SWORD_GRIP)
    px(d, ox + 13, oy + 1, SWORD_GRIP)
    px(d, ox + 12, oy + 1, SWORD_EDGE)
    px(d, ox + 13, oy + 2, SWORD_EDGE)


def draw_head(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    rect(d, ox + 5, oy + 1, ox + 10, oy + 1, H)
    rect(d, ox + 4, oy + 2, ox + 11, oy + 2, M)
    rect(d, ox + 4, oy + 3, ox + 11, oy + 5, M)
    rect(d, ox + 11, oy + 2, ox + 11, oy + 5, S)
    rect(d, ox + 10, oy + 5, ox + 11, oy + 5, S)
    px(d, ox + 4, oy + 2, H)
    px(d, ox + 4, oy + 3, H)
    rect(d, ox + 5, oy + 3, ox + 10, oy + 5, MASK_BLACK)
    px(d, ox + 6, oy + 4, EYE_GLOW)
    px(d, ox + 9, oy + 4, EYE_GLOW)


def draw_torso(d, p, ox, oy, body_y=6):
    M, H, S = p['main'], p['hi'], p['shadow']
    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, M)
    rect(d, ox + 3, by, ox + 3, by + 3, H)
    rect(d, ox + 12, by, ox + 12, by + 3, S)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, S)
    rect(d, ox + 4, by + 1, ox + 11, by + 1, SASH)
    px(d, ox + 10, by + 2, SASH_SHADE)
    px(d, ox + 11, by + 2, SASH_SHADE)


def draw_leg(d, p, ox, oy, x, top, bot, foot_y):
    """A 3px-wide vertical leg (x..x+2) with a shaded trailing edge + tabi foot."""
    M, S = p['main'], p['shadow']
    rect(d, ox + x, oy + top, ox + x + 2, oy + bot, M)
    for yy in range(top, bot + 1):
        px(d, ox + x + 2, oy + yy, S)
    rect(d, ox + x, oy + foot_y, ox + x + 2, oy + foot_y, FOOT)


# ==========================================================================
# WALK — 6-frame run cycle with a vertical body bob and an arm pump.
# Each entry: body_dy, left leg (x, top, bot, foot_y), right leg, arm side.
# ==========================================================================
WALK = [
    {'dy': 0,  'L': (3, 10, 12, 13), 'R': (10, 10, 13, 14), 'arm': 'R'},  # left contact (fwd)
    {'dy': -1, 'L': (4, 10, 13, 14), 'R': (9,  9, 11, 12),  'arm': 'R'},  # push, right knee up
    {'dy': 0,  'L': (5, 10, 12, 13), 'R': (9, 10, 13, 14),  'arm': 'N'},  # pass
    {'dy': 0,  'L': (3, 10, 13, 14), 'R': (10, 10, 12, 13), 'arm': 'L'},  # right contact (fwd)
    {'dy': -1, 'L': (5,  9, 11, 12), 'R': (9, 10, 13, 14),  'arm': 'L'},  # push, left knee up
    {'dy': 0,  'L': (4, 10, 12, 13), 'R': (10, 10, 13, 14), 'arm': 'N'},  # pass
]


def draw_arm(d, p, ox, oy, side, by):
    """Small forearm pump near a shoulder, opposite the leading leg."""
    M, S = p['main'], p['shadow']
    if side == 'L':
        px(d, ox + 2, by + 1, M); px(d, ox + 2, by + 2, S)
    elif side == 'R':
        px(d, ox + 13, by + 1, M); px(d, ox + 13, by + 2, S)


def pose_walk(d, p, ox, oy, frame):
    f = WALK[frame]
    dy = f['dy']
    draw_sword_on_back(d, ox, oy + dy)
    draw_head(d, p, ox, oy + dy)
    draw_torso(d, p, ox, oy + dy, body_y=6)
    draw_arm(d, p, ox, oy + dy, f['arm'], oy + dy + 6)
    draw_leg(d, p, ox, oy, *f['L'])
    draw_leg(d, p, ox, oy, *f['R'])


# ==========================================================================
# SWING — overhead katana slash. The ninja GRIPS the blade in both hands and
# sweeps it from an upper-back windup down to a lunging front-low strike, then
# recovers. Art faces LEFT (front = -x), matching the rest of the sheet; the
# game mirrors it for right-facing. The clan-coloured blade sprite + slash_fx
# overlay near the hands at runtime — these frames carry the BODY of the swing.
# Each entry: torso lean (dx), grip hands [(x,y)...], legs, draw_blade hint.
# ==========================================================================
SWING = [
    # f0 windup — coiled, weight back, hands cocked high behind the shoulder (right/back)
    {'lean': 1,  'hands': [(12, 2), (13, 3)], 'arm_from': (10, 7),
     'L': (5, 10, 13, 14), 'R': (9, 10, 13, 14)},
    # f1 rise — hands lift to the top
    {'lean': 1,  'hands': [(9, 1), (10, 2)], 'arm_from': (9, 7),
     'L': (5, 10, 13, 14), 'R': (9, 10, 13, 14)},
    # f2 sweep — blade comes over the top toward the front
    {'lean': 0,  'hands': [(6, 3), (7, 4)], 'arm_from': (7, 7),
     'L': (4, 10, 13, 14), 'R': (9, 10, 13, 14)},
    # f3 STRIKE — thrust front-low into a lunge (front/left leg forward)
    {'lean': -2, 'hands': [(2, 7), (3, 8)], 'arm_from': (5, 7),
     'L': (1, 11, 13, 14), 'R': (10, 10, 13, 14)},
    # f4 follow-through — blade carries down-front, deep lunge
    {'lean': -2, 'hands': [(1, 9), (2, 10)], 'arm_from': (5, 8),
     'L': (1, 11, 13, 14), 'R': (11, 10, 13, 14)},
    # f5 recover — pulling back toward centre guard
    {'lean': 0,  'hands': [(4, 6), (5, 7)], 'arm_from': (6, 7),
     'L': (4, 10, 13, 14), 'R': (9, 10, 13, 14)},
]


def pose_swing(d, p, ox, oy, frame):
    M, H, S = p['main'], p['hi'], p['shadow']
    f = SWING[frame]
    lean = f['lean']
    # head + torso shifted by the lean to sell the weight transfer
    draw_head(d, p, ox + lean, oy)
    draw_torso(d, p, ox + lean, oy, body_y=6)
    # legs (anchored, no lean — feet stay on the ground)
    draw_leg(d, p, ox, oy, *f['L'])
    draw_leg(d, p, ox, oy, *f['R'])
    # both arms reaching from the chest toward the grip (a straight forearm line)
    sx, sy = f['arm_from']
    hx, hy = f['hands'][0]
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    for i in range(steps + 1):
        ax = round(sx + (hx - sx) * i / steps)
        ay = round(sy + (hy - sy) * i / steps)
        px(d, ox + ax, oy + ay, M)
    # the two gripping hands (highlight = knuckles)
    for j, (hx, hy) in enumerate(f['hands']):
        px(d, ox + hx, oy + hy, H if j == 0 else M)


# --- render + save --------------------------------------------------------
def render(pose_fn, palette):
    img = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i in range(N):
        pose_fn(d, palette, i * SPRITE, 0, i)
    return img


def save(img, name):
    img.save(os.path.join(OUT, name))
    print('wrote', name)


def main():
    rows = []
    for color, palette in PALETTES.items():
        for tag, fn in (('walk', pose_walk), ('swing', pose_swing)):
            strip = render(fn, palette)
            save(strip, f'ninja_{color}_{tag}_6frame_native_96x16.png')
            save(strip.resize((SHEET_W * 4, SHEET_H * 4), Image.NEAREST),
                 f'ninja_{color}_{tag}_6frame_4x_384x64.png')
            save(strip.resize((SHEET_W * 8, SHEET_H * 8), Image.NEAREST),
                 f'ninja_{color}_{tag}_6frame_8x_768x128.png')
            rows.append((f'{color} {tag}', strip))

    # review sheet: every strip stacked, 8x, dark backdrop
    scale, pad = 8, 6
    w = SHEET_W * scale + pad * 2
    h = len(rows) * (SHEET_H * scale + pad) + pad
    pv = Image.new('RGBA', (w, h), (26, 22, 34, 255))
    y = pad
    for _, s in rows:
        big = s.resize((SHEET_W * scale, SHEET_H * scale), Image.NEAREST)
        pv.paste(big, (pad, y), big)
        y += SHEET_H * scale + pad
    save(pv, '_walk_swing_preview.png')


if __name__ == '__main__':
    main()
