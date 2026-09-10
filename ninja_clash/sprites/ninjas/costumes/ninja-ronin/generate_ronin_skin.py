"""
RONIN — game-ready skin sheets.

Same 16x16 / 5-pose layout as sprites/ninjas/generate_ninjas.py (idle,
walk1, walk2, jump, attack -> 80x16 native), so it drops straight into the
in-game loader (main.gd resolves costumes/sprite_<style>_<color>_native_80x16.png).

The ronin look is a BLACK ninja whose scarf + waist sash take the CLAN COLOUR,
so the four players stay distinguishable in couch play. A short scarf tail
trails behind the neck to read as a ronin.

Writes to the parent costumes/ directory:
  sprite_ronin_<color>_native_80x16.png  (+ _4x_320x64, _8x_640x128)
for each clan colour (cyan, magenta, orange, green).
"""

import os
from PIL import Image, ImageDraw

SPRITE = 16
POSES = ['idle', 'walk1', 'walk2', 'jump', 'attack']
SHEET_W = SPRITE * len(POSES)   # 80
SHEET_H = SPRITE                 # 16

# Black ninja cloth (body is the same for every clan; colour lives in the scarf)
BLACK = {'main': (42, 38, 50), 'hi': (78, 72, 92), 'shadow': (24, 21, 30)}
MASK  = (16, 14, 22)

# Scarf + sash palettes = the four clan colours (matches generate_ninjas.py)
SCARVES = {
    'cyan':    {'main': (80, 210, 230), 'hi': (170, 240, 250), 'shadow': (40, 120, 160)},
    'magenta': {'main': (235, 80, 175), 'hi': (255, 170, 215), 'shadow': (160, 40, 110)},
    'orange':  {'main': (255, 145, 50), 'hi': (255, 195, 130), 'shadow': (180, 90, 25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70, 140, 55)},
}

EYE_GLOW    = (255, 240, 90)
FOOT        = (20, 16, 26)
SWORD_GRIP  = (95, 60, 32)
SWORD_EDGE  = (130, 135, 150)
SHURIKEN    = (180, 188, 200)
SHURIKEN_DRK = (90, 95, 110)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# ------------------------------------------------------------------
# Shared parts (origin at top-left of the 16x16 cell)
# ------------------------------------------------------------------
def draw_sword_on_back(d, ox, oy):
    px(d, ox + 12, oy + 0, SWORD_GRIP)
    px(d, ox + 13, oy + 1, SWORD_GRIP)
    px(d, ox + 12, oy + 1, SWORD_EDGE)
    px(d, ox + 13, oy + 2, SWORD_EDGE)


def draw_head(d, ox, oy):
    B = BLACK
    rect(d, ox + 5, oy + 1, ox + 10, oy + 1, B['hi'])     # top tip
    rect(d, ox + 4, oy + 2, ox + 11, oy + 2, B['main'])
    rect(d, ox + 4, oy + 3, ox + 11, oy + 5, B['main'])
    rect(d, ox + 11, oy + 2, ox + 11, oy + 5, B['shadow'])
    px(d, ox + 4, oy + 2, B['hi'])
    px(d, ox + 4, oy + 3, B['hi'])
    # mask band (slightly darker recess) + glowing eyes
    rect(d, ox + 5, oy + 3, ox + 10, oy + 5, MASK)
    px(d, ox + 6, oy + 4, EYE_GLOW)
    px(d, ox + 9, oy + 4, EYE_GLOW)


def draw_tail(d, sc, ox, oy):
    """Short clan-coloured scarf tail flicking out behind the neck (left)."""
    px(d, ox + 3, oy + 5, sc['main'])
    px(d, ox + 2, oy + 6, sc['main'])
    px(d, ox + 2, oy + 7, sc['hi'])
    px(d, ox + 3, oy + 7, sc['main'])


def draw_torso(d, sc, ox, oy, body_y=6):
    B = BLACK
    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, B['main'])
    rect(d, ox + 3, by, ox + 3, by + 3, B['hi'])
    rect(d, ox + 12, by, ox + 12, by + 3, B['shadow'])
    rect(d, ox + 4, by + 3, ox + 11, by + 3, B['shadow'])
    # clan-coloured sash
    rect(d, ox + 4, by + 1, ox + 11, by + 1, sc['main'])
    px(d, ox + 4, by + 1, sc['hi'])
    px(d, ox + 10, by + 2, sc['shadow'])
    px(d, ox + 11, by + 2, sc['shadow'])


# ------------------------------------------------------------------
# POSES (geometry mirrors generate_ninjas.py so frames line up in-game)
# ------------------------------------------------------------------
def pose_idle(d, sc, ox, oy):
    B = BLACK
    draw_sword_on_back(d, ox, oy)
    draw_head(d, ox, oy)
    draw_tail(d, sc, ox, oy)
    draw_torso(d, sc, ox, oy)
    rect(d, ox + 4, oy + 10, ox + 6, oy + 12, B['main'])
    rect(d, ox + 9, oy + 10, ox + 11, oy + 12, B['main'])
    rect(d, ox + 6, oy + 10, ox + 6, oy + 12, B['shadow'])
    rect(d, ox + 11, oy + 10, ox + 11, oy + 12, B['shadow'])
    rect(d, ox + 4, oy + 13, ox + 6, oy + 13, FOOT)
    rect(d, ox + 9, oy + 13, ox + 11, oy + 13, FOOT)


def pose_walk1(d, sc, ox, oy):
    B = BLACK
    draw_sword_on_back(d, ox, oy)
    draw_head(d, ox, oy)
    draw_tail(d, sc, ox, oy)
    draw_torso(d, sc, ox, oy)
    rect(d, ox + 3, oy + 10, ox + 5, oy + 12, B['main'])
    px(d, ox + 5, oy + 10, B['shadow']); px(d, ox + 5, oy + 12, B['shadow'])
    rect(d, ox + 9, oy + 10, ox + 11, oy + 13, B['main'])
    for yy in range(10, 14):
        px(d, ox + 11, oy + yy, B['shadow'])
    rect(d, ox + 3, oy + 13, ox + 5, oy + 13, FOOT)
    rect(d, ox + 9, oy + 14, ox + 11, oy + 14, FOOT)


def pose_walk2(d, sc, ox, oy):
    B = BLACK
    draw_sword_on_back(d, ox, oy)
    draw_head(d, ox, oy)
    draw_tail(d, sc, ox, oy)
    draw_torso(d, sc, ox, oy)
    rect(d, ox + 4, oy + 10, ox + 6, oy + 13, B['main'])
    for yy in range(10, 14):
        px(d, ox + 6, oy + yy, B['shadow'])
    rect(d, ox + 10, oy + 10, ox + 12, oy + 12, B['main'])
    px(d, ox + 12, oy + 10, B['shadow']); px(d, ox + 12, oy + 12, B['shadow'])
    rect(d, ox + 4, oy + 14, ox + 6, oy + 14, FOOT)
    rect(d, ox + 10, oy + 13, ox + 12, oy + 13, FOOT)


def pose_jump(d, sc, ox, oy):
    B = BLACK
    draw_sword_on_back(d, ox, oy - 1)
    draw_head(d, ox, oy - 1)
    draw_tail(d, sc, ox, oy - 1)
    by = oy + 5
    rect(d, ox + 3, by, ox + 12, by + 3, B['main'])
    rect(d, ox + 3, by, ox + 3, by + 3, B['hi'])
    rect(d, ox + 12, by, ox + 12, by + 3, B['shadow'])
    rect(d, ox + 4, by + 3, ox + 11, by + 3, B['shadow'])
    rect(d, ox + 4, by + 1, ox + 11, by + 1, sc['main'])
    px(d, ox + 10, by + 2, sc['shadow']); px(d, ox + 11, by + 2, sc['shadow'])
    # arms out
    px(d, ox + 2, by + 1, B['main']); px(d, ox + 1, by + 2, B['main']); px(d, ox + 2, by + 2, B['shadow'])
    px(d, ox + 13, by + 1, B['main']); px(d, ox + 14, by + 2, B['main']); px(d, ox + 13, by + 2, B['shadow'])
    # tucked legs
    rect(d, ox + 4, oy + 9, ox + 6, oy + 11, B['main'])
    rect(d, ox + 9, oy + 9, ox + 11, oy + 11, B['main'])
    rect(d, ox + 6, oy + 9, ox + 6, oy + 11, B['shadow'])
    rect(d, ox + 11, oy + 9, ox + 11, oy + 11, B['shadow'])
    rect(d, ox + 5, oy + 12, ox + 6, oy + 12, FOOT)
    rect(d, ox + 9, oy + 12, ox + 10, oy + 12, FOOT)


def pose_attack(d, sc, ox, oy):
    B = BLACK
    draw_sword_on_back(d, ox, oy)
    draw_head(d, ox, oy)
    draw_tail(d, sc, ox, oy)
    draw_torso(d, sc, ox, oy)
    # extended throwing arm (right)
    px(d, ox + 13, oy + 7, B['main']); px(d, ox + 14, oy + 7, B['main'])
    px(d, ox + 13, oy + 8, B['shadow']); px(d, ox + 14, oy + 8, B['shadow'])
    # shuriken in flight
    px(d, ox + 15, oy + 6, SHURIKEN)
    px(d, ox + 15, oy + 7, SHURIKEN)
    px(d, ox + 15, oy + 8, SHURIKEN)
    px(d, ox + 14, oy + 6, SHURIKEN_DRK)
    # lunge legs
    rect(d, ox + 4, oy + 10, ox + 6, oy + 12, B['main'])
    rect(d, ox + 6, oy + 10, ox + 6, oy + 12, B['shadow'])
    rect(d, ox + 8, oy + 11, ox + 11, oy + 12, B['main'])
    rect(d, ox + 11, oy + 11, ox + 11, oy + 12, B['shadow'])
    rect(d, ox + 4, oy + 13, ox + 6, oy + 13, FOOT)
    rect(d, ox + 8, oy + 13, ox + 11, oy + 13, FOOT)


POSE_FUNCS = {
    'idle': pose_idle, 'walk1': pose_walk1, 'walk2': pose_walk2,
    'jump': pose_jump, 'attack': pose_attack,
}


def render_strip(scarf):
    img = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, pose in enumerate(POSES):
        POSE_FUNCS[pose](d, scarf, i * SPRITE, 0)
    return img


# ------------------------------------------------------------------
# Output to the parent costumes/ dir, matching the costume naming scheme
# ------------------------------------------------------------------
COSTUMES_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))


def save(img, name):
    path = os.path.join(COSTUMES_DIR, name)
    img.save(path)
    print('wrote', name)


def main():
    for color, scarf in SCARVES.items():
        strip = render_strip(scarf)
        save(strip, f'sprite_ronin_{color}_native_80x16.png')
        save(strip.resize((SHEET_W * 4, SHEET_H * 4), Image.NEAREST),
             f'sprite_ronin_{color}_4x_320x64.png')
        save(strip.resize((SHEET_W * 8, SHEET_H * 8), Image.NEAREST),
             f'sprite_ronin_{color}_8x_640x128.png')


if __name__ == '__main__':
    main()
