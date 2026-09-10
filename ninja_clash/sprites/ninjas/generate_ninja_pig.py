"""
TEST SKIN: a chunky pig ninja ("PIGGY") — deliberately MORE detailed/animated
than the regular costume skins. A whole different critter: round pink body,
two floppy ears, a big central snout with nostrils, a curly tail and stubby
trotters. The clan COLOUR is carried as a ninja headband + belly sash so you
can still tell the four clans apart at a glance.

Front-view face like the base ninja (so horizontal flip stays clean), grips the
clan katana in the swing the same way the base ninja does (the game overlays the
clan blade sprite + slash_fx on top of these body frames).

Output per clan colour, into costumes/ (matches the skin path convention):
  sprite_pig_<color>_native_80x16.png             5-pose sheet (idle/walk1/walk2/jump/attack)
  sprite_pig_<color>_idle_6frame_native_96x16.png 6-frame breathing idle
  sprite_pig_<color>_walk_6frame_native_96x16.png 6-frame run cycle
  sprite_pig_<color>_swing_6frame_native_96x16.png 6-frame katana body swing
(+ _4x and _8x NEAREST upscales for each, plus a stacked _pig_preview.png)
"""

import os
from PIL import Image, ImageDraw

SPRITE = 16
OUT = os.path.dirname(os.path.abspath(__file__))
# Skin assets live in a per-style subfolder: costumes/<style>/<color>_*.png
COST = os.path.join(OUT, "costumes", "pig")
os.makedirs(COST, exist_ok=True)

# --- clan colours (matches generate_ninjas.py) ----------------------------
CLANS = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

# --- pig palette ----------------------------------------------------------
PINK     = (244, 168, 184)
PINK_HI  = (255, 208, 218)
PINK_SH  = (198, 116, 138)
SNOUT    = (236, 142, 162)
SNOUT_SH = (188, 100, 126)
NOSTRIL  = (132, 64, 92)
EYE      = (38, 28, 36)
EYE_HI   = (250, 250, 252)
TROTTER  = (74, 52, 58)
SWORD_GRIP = (95, 60, 32)
SWORD_EDGE = (130, 135, 150)
TRANSPARENT = (0, 0, 0, 0)

PIG = {'main': PINK, 'hi': PINK_HI, 'shadow': PINK_SH}


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# --- shared body parts ----------------------------------------------------
def draw_katana_on_back(d, ox, oy):
    px(d, ox + 12, oy + 0, SWORD_GRIP)
    px(d, ox + 13, oy + 1, SWORD_GRIP)
    px(d, ox + 12, oy + 1, SWORD_EDGE)
    px(d, ox + 13, oy + 2, SWORD_EDGE)


def draw_pig_head(d, clan, ox, oy, ear_up=0):
    """Front-view pig face. ear_up lifts the ear tips 1px (idle/run twitch)."""
    C, CH, CS = clan['main'], clan['hi'], clan['shadow']
    # ears (top corners) — floppy pink triangles with a darker inner fold
    et = oy - ear_up
    px(d, ox + 4, et + 0, PINK);    px(d, ox + 5, et + 0, PINK)
    px(d, ox + 5, oy + 1, PINK_SH)
    px(d, ox + 10, et + 0, PINK);   px(d, ox + 11, et + 0, PINK)
    px(d, ox + 10, oy + 1, PINK_SH)
    # head block
    rect(d, ox + 4, oy + 1, ox + 11, oy + 6, PINK)
    rect(d, ox + 4, oy + 1, ox + 4, oy + 6, PINK_HI)    # left highlight
    rect(d, ox + 11, oy + 1, ox + 11, oy + 6, PINK_SH)  # right shadow
    rect(d, ox + 5, oy + 6, ox + 10, oy + 6, PINK_SH)   # jaw shadow
    # clan headband across the brow + knot tail on the right
    rect(d, ox + 4, oy + 2, ox + 11, oy + 2, C)
    px(d, ox + 4, oy + 2, CH)
    px(d, ox + 11, oy + 2, CS)
    px(d, ox + 12, oy + 2, C); px(d, ox + 12, oy + 3, CS)  # trailing knot tail
    # eyes
    px(d, ox + 6, oy + 3, EYE); px(d, ox + 9, oy + 3, EYE)
    px(d, ox + 6, oy + 3, EYE)
    px(d, ox + 5, oy + 3, EYE_HI); px(d, ox + 8, oy + 3, EYE_HI)  # tiny catchlights
    # big central snout with two nostrils
    rect(d, ox + 6, oy + 4, ox + 9, oy + 5, SNOUT)
    rect(d, ox + 6, oy + 5, ox + 9, oy + 5, SNOUT_SH)
    px(d, ox + 7, oy + 4, NOSTRIL); px(d, ox + 8, oy + 4, NOSTRIL)


def draw_pig_torso(d, clan, ox, oy, body_y=7, tail=True):
    C, CS = clan['main'], clan['shadow']
    by = oy + body_y
    # round-ish belly (4 rows)
    rect(d, ox + 3, by, ox + 12, by + 3, PINK)
    rect(d, ox + 3, by, ox + 3, by + 3, PINK_HI)
    rect(d, ox + 12, by, ox + 12, by + 3, PINK_SH)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, PINK_SH)
    # clan belly sash
    rect(d, ox + 4, by + 1, ox + 11, by + 1, C)
    px(d, ox + 11, by + 1, CS)
    # curly tail off the rump (right/back)
    if tail:
        px(d, ox + 13, by + 0, PINK)
        px(d, ox + 14, by + 1, PINK_SH)
        px(d, ox + 13, by + 2, PINK)


def draw_leg(d, x, top, bot, foot_y, ox, oy):
    """3px-wide pink trotter leg with shaded trailing edge + dark hoof."""
    rect(d, ox + x, oy + top, ox + x + 2, oy + bot, PINK)
    for yy in range(top, bot + 1):
        px(d, ox + x + 2, oy + yy, PINK_SH)
    rect(d, ox + x, oy + foot_y, ox + x + 2, oy + foot_y, TROTTER)


# ==========================================================================
# 5-POSE SHEET (idle / walk1 / walk2 / jump / attack) — 80x16
# ==========================================================================
def pose_idle(d, clan, ox, oy):
    draw_katana_on_back(d, ox, oy)
    draw_pig_head(d, clan, ox, oy)
    draw_pig_torso(d, clan, ox, oy, body_y=7)
    draw_leg(d, 4, 11, 12, 13, ox, oy)
    draw_leg(d, 9, 11, 12, 13, ox, oy)


def pose_walk1(d, clan, ox, oy):
    draw_katana_on_back(d, ox, oy)
    draw_pig_head(d, clan, ox, oy)
    draw_pig_torso(d, clan, ox, oy, body_y=7)
    draw_leg(d, 3, 11, 12, 13, ox, oy)
    draw_leg(d, 9, 11, 13, 14, ox, oy)


def pose_walk2(d, clan, ox, oy):
    draw_katana_on_back(d, ox, oy)
    draw_pig_head(d, clan, ox, oy)
    draw_pig_torso(d, clan, ox, oy, body_y=7)
    draw_leg(d, 4, 11, 13, 14, ox, oy)
    draw_leg(d, 10, 11, 12, 13, ox, oy)


def pose_jump(d, clan, ox, oy):
    draw_katana_on_back(d, ox, oy - 1)
    draw_pig_head(d, clan, ox, oy - 1)
    draw_pig_torso(d, clan, ox, oy - 1, body_y=7)
    # tucked trotters
    draw_leg(d, 4, 10, 11, 12, ox, oy)
    draw_leg(d, 9, 10, 11, 12, ox, oy)


def pose_attack(d, clan, ox, oy):
    # extended front-low strike pose (front = left)
    draw_pig_head(d, clan, ox, oy)
    draw_pig_torso(d, clan, ox, oy, body_y=7)
    # foreleg/hoof reaching forward-low
    px(d, ox + 2, oy + 9, PINK); px(d, ox + 1, oy + 10, PINK)
    px(d, ox + 2, oy + 10, PINK_SH)
    draw_leg(d, 3, 11, 13, 14, ox, oy)
    draw_leg(d, 10, 11, 12, 13, ox, oy)


POSES = [pose_idle, pose_walk1, pose_walk2, pose_jump, pose_attack]


# ==========================================================================
# 6-FRAME IDLE — gentle breathing bob + ear/tail twitch
# ==========================================================================
IDLE = [
    {'dy': 0, 'ear': 0}, {'dy': 0, 'ear': 1}, {'dy': -1, 'ear': 1},
    {'dy': -1, 'ear': 0}, {'dy': 0, 'ear': 0}, {'dy': 0, 'ear': 1},
]


def pose_idle6(d, clan, ox, oy, frame):
    f = IDLE[frame]
    dy = f['dy']
    draw_katana_on_back(d, ox, oy + dy)
    draw_pig_head(d, clan, ox, oy + dy, ear_up=f['ear'])
    draw_pig_torso(d, clan, ox, oy + dy, body_y=7)
    draw_leg(d, 4, 11, 12, 13, ox, oy)
    draw_leg(d, 9, 11, 12, 13, ox, oy)


# ==========================================================================
# 6-FRAME WALK — bouncy trot with body bob + ear flap
# ==========================================================================
WALK = [
    {'dy': 0,  'L': (3, 11, 13, 13), 'R': (10, 11, 14, 14), 'ear': 0},
    {'dy': -1, 'L': (4, 11, 14, 14), 'R': (9, 10, 12, 12),  'ear': 1},
    {'dy': 0,  'L': (5, 11, 13, 13), 'R': (9, 11, 14, 14),  'ear': 0},
    {'dy': 0,  'L': (3, 11, 14, 14), 'R': (10, 11, 13, 13), 'ear': 0},
    {'dy': -1, 'L': (5, 10, 12, 12), 'R': (9, 11, 14, 14),  'ear': 1},
    {'dy': 0,  'L': (4, 11, 13, 13), 'R': (10, 11, 14, 14), 'ear': 0},
]


def pose_walk6(d, clan, ox, oy, frame):
    f = WALK[frame]
    dy = f['dy']
    draw_katana_on_back(d, ox, oy + dy)
    draw_pig_head(d, clan, ox, oy + dy, ear_up=f['ear'])
    draw_pig_torso(d, clan, ox, oy + dy, body_y=7)
    draw_leg(d, *f['L'], ox, oy)
    draw_leg(d, *f['R'], ox, oy)


# ==========================================================================
# 6-FRAME SWING — overhead katana slash (front = left). The pig grips the
# blade in both trotters and sweeps from a high-back windup down into a
# lunging front-low strike, then recovers. The game overlays the clan blade
# sprite + slash_fx near the grip; these frames carry the BODY motion.
# ==========================================================================
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


def pose_swing6(d, clan, ox, oy, frame):
    f = SWING[frame]
    lean = f['lean']
    draw_pig_head(d, clan, ox + lean, oy)
    draw_pig_torso(d, clan, ox + lean, oy, body_y=7, tail=False)
    draw_leg(d, *f['L'], ox, oy)
    draw_leg(d, *f['R'], ox, oy)
    # both forelegs reaching from the chest toward the grip
    sx, sy = f['arm_from']
    hx, hy = f['hands'][0]
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    for i in range(steps + 1):
        ax = round(sx + (hx - sx) * i / steps)
        ay = round(sy + (hy - sy) * i / steps)
        px(d, ox + ax, oy + ay, PINK)
    for j, (hx, hy) in enumerate(f['hands']):
        px(d, ox + hx, oy + hy, PINK_HI if j == 0 else PINK)


# --- render helpers -------------------------------------------------------
def render_poses(clan):
    img = Image.new('RGBA', (SPRITE * len(POSES), SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, fn in enumerate(POSES):
        fn(d, clan, i * SPRITE, 0)
    return img


def render_strip6(fn, clan):
    img = Image.new('RGBA', (SPRITE * 6, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i in range(6):
        fn(d, clan, i * SPRITE, 0, i)
    return img


def save_scaled(img, base):
    w, h = img.size
    img.save(os.path.join(COST, base + '.png'))
    img.resize((w * 4, h * 4), Image.NEAREST).save(os.path.join(COST, base + '_4x.png'))
    img.resize((w * 8, h * 8), Image.NEAREST).save(os.path.join(COST, base + '_8x.png'))


def main():
    rows = []
    for color, clan in CLANS.items():
        poses = render_poses(clan)
        idle = render_strip6(pose_idle6, clan)
        walk = render_strip6(pose_walk6, clan)
        swing = render_strip6(pose_swing6, clan)
        # names match the skin-path convention used by game_state.gd:
        # costumes/pig/<color>_<tag>.png
        poses.save(os.path.join(COST, f'{color}_native_80x16.png'))
        poses.resize((80 * 4, 16 * 4), Image.NEAREST).save(os.path.join(COST, f'{color}_4x_320x64.png'))
        poses.resize((80 * 8, 16 * 8), Image.NEAREST).save(os.path.join(COST, f'{color}_8x_640x128.png'))
        idle.save(os.path.join(COST, f'{color}_idle_6frame_native_96x16.png'))
        walk.save(os.path.join(COST, f'{color}_walk_6frame_native_96x16.png'))
        swing.save(os.path.join(COST, f'{color}_swing_6frame_native_96x16.png'))
        print('wrote pig', color)
        rows += [(f'{color} pose', poses), (f'{color} idle', idle),
                 (f'{color} walk', walk), (f'{color} swing', swing)]

    # stacked review sheet
    scale, pad = 8, 6
    w = SPRITE * 6 * scale + pad * 2
    h = len(rows) * (SPRITE * scale + pad) + pad
    pv = Image.new('RGBA', (w, h), (26, 22, 34, 255))
    y = pad
    for _, s in rows:
        big = s.resize((s.size[0] * scale, s.size[1] * scale), Image.NEAREST)
        pv.paste(big, (pad, y), big)
        y += SPRITE * scale + pad
    pv.save(os.path.join(COST, '_pig_preview.png'))
    print('wrote _pig_preview.png')


if __name__ == '__main__':
    main()
