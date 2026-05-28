"""
RONIN ninja — a black-clad ninja with a trailing RED scarf, in the same
pixel-art style as sprites/ninjas/generate_ninjas.py, but at a richer
32x32 native resolution (4x -> 128px per frame).

Reference look: pointed black hood + slim tapered body, glowing eyes, a
red neck scarf with flowing tails, a katana slung on the back, split-toe
tabi feet, and a fiery thrown projectile.

Output (written next to this script):
  - ronin_native_<W>x32.png    one transparent strip, all poses
  - ronin_4x_<W*4>x128.png      upscaled 4x  (each frame = 128px)
  - ronin_8x_<W*8>x256.png      upscaled 8x  (showcase)
  - ronin_katana_native_32x32.png / _4x_128x128.png   standalone weapon
  - ronin_fire_native_32x32.png  / _4x_128x128.png    thrown projectile
  - ronin_preview.png           review sheet
"""

import os
from PIL import Image, ImageDraw

SPRITE = 32
POSES = [
    'idle', 'idle2', 'crouch', 'run1', 'run2', 'jump',
    'slash', 'fire_slash', 'wall', 'throw', 'dead1', 'dead2',
]
SHEET_W = SPRITE * len(POSES)
SHEET_H = SPRITE

# ------------------------------------------------------------------
# Palette — black ninja cloth + red scarf (matches the reference art)
# ------------------------------------------------------------------
CLOTH    = (42, 38, 50)     # main black-violet cloth
CLOTH_HI = (78, 72, 92)     # rim light
CLOTH_SH = (24, 21, 30)     # shadow
OUTLINE  = (12, 10, 16)     # silhouette outline

SCARF    = (198, 44, 44)    # red scarf main
SCARF_HI = (236, 96, 82)    # red highlight
SCARF_SH = (122, 24, 28)    # red shadow

EYE_GLOW = (255, 224, 86)
FOOT     = (26, 22, 32)

GRIP     = (86, 56, 30)
GRIP_HI  = (124, 84, 44)
GUARD    = (208, 166, 66)
BLADE    = (216, 221, 231)
BLADE_EDGE = (150, 156, 172)

FIRE_CORE = (255, 244, 176)
FIRE_MID  = (255, 150, 46)
FIRE_OUT  = (214, 66, 20)

DUST = (206, 202, 212)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c, a=255):
    d.point((x, y), fill=rgba(c, a))


def rect(d, x1, y1, x2, y2, c, a=255):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c, a))


# ------------------------------------------------------------------
# Shared body parts. Figure is centred on x=16; a standing pose spans
# y4..28. dy shifts the upper body vertically; lean shifts it sideways.
# ------------------------------------------------------------------
def draw_back_katana(d, dy=0):
    """Katana slung diagonally across the back, hilt above right shoulder."""
    y = lambda v: v + dy
    px(d, 20, y(11), GUARD)                 # tsuba near shoulder
    px(d, 21, y(10), GRIP); px(d, 22, y(9), GRIP_HI)
    px(d, 23, y(8), BLADE_EDGE); px(d, 24, y(7), BLADE)


def draw_hood(d, dy=0, look=0):
    """Pointed black hood + masked face with glowing eyes."""
    y = lambda v: v + dy
    px(d, 15, y(4), CLOTH_HI); px(d, 16, y(4), CLOTH_HI)   # pointed tip
    rect(d, 14, y(5), 17, y(5), CLOTH)
    rect(d, 13, y(6), 18, y(6), CLOTH)
    rect(d, 12, y(7), 19, y(10), CLOTH)
    rect(d, 13, y(11), 18, y(11), CLOTH)                   # jaw narrows
    # left rim light / right shadow
    rect(d, 12, y(7), 12, y(10), CLOTH_HI)
    rect(d, 19, y(7), 19, y(10), CLOTH_SH)
    # recessed eye band
    rect(d, 13, y(8), 18, y(9), CLOTH_SH)
    ex = 1 if look > 0 else (-1 if look < 0 else 0)
    rect(d, 13 + ex, y(8), 14 + ex, y(8), EYE_GLOW)
    rect(d, 16 + ex, y(8), 17 + ex, y(8), EYE_GLOW)


def draw_scarf(d, dy=0, flip=False):
    """Red neck wrap + long flowing tails trailing behind."""
    y = lambda v: v + dy
    rect(d, 12, y(11), 19, y(12), SCARF)
    px(d, 12, y(11), SCARF_HI)
    px(d, 19, y(12), SCARF_SH)
    px(d, 11, y(12), SCARF)                                # knot
    tail = [(11, 11), (10, 12), (9, 12), (8, 13), (7, 13),
            (6, 14), (7, 15), (8, 14)]
    hi = {(9, 12), (7, 13)}
    if flip:
        tail = [(31 - tx, ty) for tx, ty in tail]
        hi = {(31 - hx, hy) for hx, hy in hi}
    for tx, ty in tail:
        px(d, tx, y(ty), SCARF_HI if (tx, ty) in hi else SCARF)


def draw_torso(d, dy=0, lean=0):
    """Slim tapered black torso with a small red waist sash."""
    y = lambda v: v + dy
    lx = lean
    rect(d, 12 + lx, y(12), 20 + lx, y(13), CLOTH)         # shoulders
    rect(d, 12 + lx, y(13), 19 + lx, y(15), CLOTH)         # chest
    rect(d, 13 + lx, y(16), 18 + lx, y(18), CLOTH)         # waist taper
    # rim light left, shadow right
    rect(d, 12 + lx, y(12), 12 + lx, y(15), CLOTH_HI)
    rect(d, 13 + lx, y(16), 13 + lx, y(18), CLOTH_HI)
    rect(d, 20 + lx, y(12), 20 + lx, y(13), CLOTH_SH)
    rect(d, 19 + lx, y(13), 19 + lx, y(15), CLOTH_SH)
    rect(d, 18 + lx, y(16), 18 + lx, y(18), CLOTH_SH)
    # red waist sash + small knot tail
    rect(d, 13 + lx, y(16), 18 + lx, y(16), SCARF)
    px(d, 13 + lx, y(16), SCARF_HI)
    px(d, 15 + lx, y(17), SCARF); px(d, 15 + lx, y(18), SCARF_SH)


def legs_stand(d, dy=0, stance=0):
    y = lambda v: v + dy
    rect(d, 13, y(19), 14, y(26), CLOTH)
    rect(d, 17, y(19), 18, y(26), CLOTH)
    px(d, 14, y(19), CLOTH_SH); px(d, 18, y(19), CLOTH_SH)
    # split-toe tabi feet
    rect(d, 12 - stance, y(27), 15, y(28), FOOT)
    rect(d, 17, y(27), 20 + stance, y(28), FOOT)


# ==================================================================
#  POSES  (each receives an ImageDraw bound to a fresh 32x32 tile)
# ==================================================================
def pose_idle(d):
    draw_back_katana(d)
    draw_hood(d)
    draw_scarf(d)
    draw_torso(d)
    rect(d, 11, 14, 11, 16, CLOTH)        # arms at sides
    rect(d, 21, 14, 21, 16, CLOTH)
    legs_stand(d)


def pose_idle2(d):
    # subtle breath: upper body sinks 1px, scarf tail flutters up
    draw_back_katana(d, dy=1)
    draw_hood(d, dy=1)
    draw_scarf(d, dy=1)
    draw_torso(d, dy=1)
    rect(d, 11, 15, 11, 17, CLOTH)
    rect(d, 21, 15, 21, 17, CLOTH)
    legs_stand(d)
    px(d, 6, 13, SCARF_HI)


def pose_crouch(d):
    # low sneaking stance, compressed downward
    draw_back_katana(d, dy=7)
    draw_hood(d, dy=7)
    draw_scarf(d, dy=7)
    rect(d, 13, 20, 19, 24, CLOTH)        # squashed torso
    rect(d, 13, 20, 13, 24, CLOTH_HI)
    rect(d, 19, 20, 19, 24, CLOTH_SH)
    rect(d, 13, 22, 18, 22, SCARF)
    # bent legs spread wide
    rect(d, 10, 25, 12, 27, CLOTH); rect(d, 20, 25, 22, 27, CLOTH)
    rect(d, 8, 28, 12, 28, FOOT); rect(d, 20, 28, 24, 28, FOOT)
    px(d, 7, 28, DUST, 160); px(d, 25, 27, DUST, 140)


def pose_run1(d):
    draw_back_katana(d)
    draw_hood(d, look=1)
    draw_scarf(d)
    draw_torso(d, lean=1)
    rect(d, 22, 14, 24, 15, CLOTH)        # leading arm forward
    rect(d, 10, 15, 11, 16, CLOTH)        # trailing arm back
    rect(d, 13, 19, 14, 25, CLOTH)        # front leg
    rect(d, 18, 20, 19, 24, CLOTH)        # back leg
    rect(d, 12, 26, 15, 27, FOOT)
    rect(d, 18, 25, 21, 26, FOOT)
    px(d, 10, 27, DUST, 160); px(d, 9, 26, DUST, 120)


def pose_run2(d):
    draw_back_katana(d)
    draw_hood(d, look=1)
    draw_scarf(d)
    draw_torso(d, lean=1)
    rect(d, 23, 15, 25, 16, CLOTH)
    rect(d, 10, 14, 11, 15, CLOTH)
    rect(d, 17, 19, 18, 25, CLOTH)        # opposite stride
    rect(d, 13, 20, 14, 24, CLOTH)
    rect(d, 16, 26, 19, 27, FOOT)
    rect(d, 12, 25, 15, 26, FOOT)
    px(d, 23, 27, DUST, 150)


def pose_jump(d):
    # airborne tuck, arms out
    draw_back_katana(d, dy=-1)
    draw_hood(d, dy=-1)
    draw_scarf(d, dy=-1)
    rect(d, 12, 11, 20, 16, CLOTH)
    rect(d, 12, 11, 12, 16, CLOTH_HI); rect(d, 20, 11, 20, 16, CLOTH_SH)
    rect(d, 13, 14, 18, 14, SCARF)
    rect(d, 8, 12, 11, 13, CLOTH); rect(d, 21, 12, 24, 13, CLOTH)   # arms spread
    rect(d, 13, 17, 15, 21, CLOTH); rect(d, 17, 17, 19, 21, CLOTH)  # tucked legs
    rect(d, 13, 22, 15, 23, FOOT); rect(d, 17, 22, 19, 23, FOOT)


def _katana_blade(d, hx, hy, dx, length, glow=False):
    """Katana blade extending from (hx,hy) toward +dx, optional fire glow."""
    for i in range(length):
        x = hx + dx * i
        px(d, x, hy, BLADE_EDGE if i % 4 == 0 else BLADE)
        px(d, x, hy - 1, BLADE_EDGE)
        if glow:
            px(d, x, hy + 1, FIRE_MID, 230)
            if i % 2 == 0:
                px(d, x, hy + 2, FIRE_OUT, 180)
    px(d, hx + dx * length, hy, BLADE)    # tip


def pose_slash(d):
    # forward lunge, katana drawn and extended to the right
    draw_hood(d, look=1)
    draw_scarf(d)
    draw_torso(d, lean=1)
    rect(d, 21, 14, 23, 15, CLOTH)        # sword arm extended
    px(d, 24, 15, GRIP); px(d, 25, 15, GUARD)
    _katana_blade(d, 26, 15, +1, 5)
    # lunge legs
    rect(d, 12, 20, 13, 26, CLOTH)
    rect(d, 18, 22, 21, 24, CLOTH)
    rect(d, 11, 27, 14, 28, FOOT)
    rect(d, 21, 24, 24, 25, FOOT)


def pose_fire_slash(d):
    # upward fiery arc, katana wreathed in flame
    draw_hood(d, look=1)
    draw_scarf(d)
    draw_torso(d, lean=1)
    rect(d, 21, 13, 23, 14, CLOTH)
    px(d, 24, 13, GRIP); px(d, 24, 12, GUARD)
    for i in range(7):                    # diagonal flaming blade up-right
        x, yy = 25 + i, 12 - i
        px(d, x, yy, BLADE)
        px(d, x, yy + 1, FIRE_MID, 230)
        px(d, x + 1, yy + 1, FIRE_OUT, 170)
        if i % 2 == 0:
            px(d, x, yy + 2, FIRE_CORE, 200)
    legs_stand(d, stance=1)


def pose_wall(d):
    # clinging to a wall on the RIGHT — body pressed against x~23
    draw_hood(d, look=1)
    draw_scarf(d, flip=True)
    rect(d, 16, 12, 23, 18, CLOTH)        # torso slid right
    rect(d, 16, 12, 16, 18, CLOTH_HI)
    rect(d, 23, 12, 23, 18, CLOTH_SH)
    rect(d, 17, 16, 22, 16, SCARF)
    rect(d, 23, 12, 25, 12, CLOTH)        # gripping hand
    rect(d, 17, 19, 18, 25, CLOTH); rect(d, 20, 20, 21, 24, CLOTH)   # braced legs
    rect(d, 16, 26, 19, 27, FOOT); rect(d, 20, 25, 23, 25, FOOT)
    px(d, 26, 20, DUST, 150); px(d, 26, 23, DUST, 120)               # wall scrape


def pose_throw(d):
    # recoil after hurling the fire bolt (arm snapped forward)
    draw_back_katana(d)
    draw_hood(d, look=1)
    draw_scarf(d)
    draw_torso(d, lean=1)
    rect(d, 21, 14, 24, 15, CLOTH); px(d, 25, 15, CLOTH_SH)   # extended arm
    px(d, 27, 14, FIRE_CORE); px(d, 27, 15, FIRE_MID)         # bolt leaving hand
    px(d, 28, 15, FIRE_OUT); px(d, 29, 15, FIRE_OUT, 180)
    legs_stand(d, stance=1)


def pose_dead1(d):
    # knocked off balance, falling backward
    draw_hood(d, dy=8, look=-1)
    draw_scarf(d, dy=8)
    rect(d, 11, 22, 19, 26, CLOTH)
    rect(d, 11, 22, 11, 26, CLOTH_HI); rect(d, 19, 22, 19, 26, CLOTH_SH)
    rect(d, 12, 24, 18, 24, SCARF)
    rect(d, 8, 23, 10, 23, CLOTH); rect(d, 20, 22, 23, 23, CLOTH)    # splayed arms
    rect(d, 10, 27, 13, 28, CLOTH); rect(d, 17, 27, 21, 28, CLOTH)   # splayed legs
    rect(d, 9, 29, 12, 29, FOOT); rect(d, 19, 29, 22, 29, FOOT)


def pose_dead2(d):
    # fully prone on the ground
    rect(d, 9, 26, 24, 29, CLOTH)         # body lying flat
    rect(d, 9, 26, 24, 26, CLOTH_HI)
    rect(d, 9, 29, 24, 29, CLOTH_SH)
    rect(d, 6, 25, 11, 28, CLOTH)         # hood at left end
    px(d, 7, 27, EYE_GLOW, 160)           # dim eye
    rect(d, 11, 27, 16, 28, SCARF)        # scarf pooled
    px(d, 10, 29, SCARF_SH)
    px(d, 25, 28, GRIP); _katana_blade(d, 26, 28, +1, 4)   # dropped katana


POSE_FUNCS = {
    'idle': pose_idle, 'idle2': pose_idle2, 'crouch': pose_crouch,
    'run1': pose_run1, 'run2': pose_run2, 'jump': pose_jump,
    'slash': pose_slash, 'fire_slash': pose_fire_slash, 'wall': pose_wall,
    'throw': pose_throw, 'dead1': pose_dead1, 'dead2': pose_dead2,
}


# ------------------------------------------------------------------
# Standalone props (referenced by attack/throw poses)
# ------------------------------------------------------------------
def render_katana():
    img = Image.new('RGBA', (SPRITE, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rect(d, 4, 16, 9, 16, GRIP)
    px(d, 5, 16, GRIP_HI); px(d, 7, 16, GRIP_HI)
    rect(d, 10, 14, 10, 18, GUARD)        # tsuba guard
    _katana_blade(d, 12, 16, +1, 16)
    return outlined(img, OUTLINE)


def render_fire():
    # crescent fire projectile (thrown bolt) like the reference's flaming arc
    img = Image.new('RGBA', (SPRITE, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    arc = [(8, 10), (10, 9), (13, 9), (16, 10), (19, 12), (21, 15),
           (22, 18), (20, 20), (17, 21), (14, 21), (11, 20), (9, 18)]
    for x, y in arc:
        px(d, x, y, FIRE_CORE)
        px(d, x, y + 1, FIRE_MID)
        px(d, x, y + 2, FIRE_OUT, 200)
        px(d, x - 1, y, FIRE_MID, 220)
    rect(d, 22, 14, 24, 17, FIRE_CORE)    # bright leading edge
    px(d, 25, 15, FIRE_MID); px(d, 26, 16, FIRE_OUT, 180)
    return img


# ------------------------------------------------------------------
# 1px dark outline around the opaque silhouette (no bleed past tile)
# ------------------------------------------------------------------
def outlined(tile, color):
    src = tile.load()
    w, h = tile.size
    out = tile.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                    dst[x, y] = rgba(color)
                    break
    return out


def render_strip():
    strip = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    for i, pose in enumerate(POSES):
        tile = Image.new('RGBA', (SPRITE, SPRITE), TRANSPARENT)
        POSE_FUNCS[pose](ImageDraw.Draw(tile))
        tile = outlined(tile, OUTLINE)
        strip.paste(tile, (i * SPRITE, 0), tile)
    return strip


def scaled(img, factor):
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


# ==================================================================
#  MAIN
# ==================================================================
OUT = os.path.dirname(os.path.abspath(__file__))


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print('wrote', os.path.relpath(path, OUT))


def main():
    strip = render_strip()
    save(strip, f'ronin_native_{SHEET_W}x{SHEET_H}.png')
    save(scaled(strip, 4), f'ronin_4x_{SHEET_W*4}x{SHEET_H*4}.png')
    save(scaled(strip, 8), f'ronin_8x_{SHEET_W*8}x{SHEET_H*8}.png')

    katana = render_katana()
    save(katana, 'ronin_katana_native_32x32.png')
    save(scaled(katana, 4), 'ronin_katana_4x_128x128.png')

    fire = render_fire()
    save(fire, 'ronin_fire_native_32x32.png')
    save(scaled(fire, 4), 'ronin_fire_4x_128x128.png')

    pad = 16
    pv = Image.new('RGBA', (strip.width * 8 + pad * 2, strip.height * 8 + pad * 2),
                   (22, 18, 30, 255))
    pv.paste(scaled(strip, 8), (pad, pad), scaled(strip, 8))
    save(pv, 'ronin_preview.png')


if __name__ == '__main__':
    main()
