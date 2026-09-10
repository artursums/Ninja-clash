"""
Four EXTRA-detailed "hero" test skins — legally-distinct homages that read as
famous action icons through signature ATTRIBUTES rather than copied designs.
Roughly 2x the internal detail of the pig skin (more tones, panel lines, glows,
per-frame eye/ear flicker). Each ships the full animation set in all 4 clans.

  ENDOBOT   chrome skull, ONE glowing red eye, bared metal teeth   (terminator-ish)
  NEKO      sleek ninja cat: ears, slit eyes, whiskers, swish tail (cool cat)
  STALKER   bio-masked hunter: dreadlocks, mandibles, shoulder cannon (predator-ish)
  IRONCLAD  armored suit: gold faceplate, glowing arc-reactor core  (iron-man-ish)

The clan COLOUR is carried as an accent (core / armor / mask / fur) so the four
clans stay distinguishable. Front-view faces (clean horizontal flip). Each grips
the clan katana in the swing exactly like the base ninja; the game overlays the
clan blade sprite + slash_fx on top of these body frames.

Output per character + clan, into costumes/<style>/ (skin-path convention):
  <color>_native_80x16.png              5-pose sheet (idle/walk1/walk2/jump/attack)
  <color>_idle_6frame_native_96x16.png  6-frame idle
  <color>_walk_6frame_native_96x16.png  6-frame run cycle
  <color>_swing_6frame_native_96x16.png 6-frame katana body swing
(+ _4x / _8x NEAREST upscales for the pose sheet, plus _heroes_preview.png)
"""

import os
from PIL import Image, ImageDraw

SPRITE = 16
OUT = os.path.dirname(os.path.abspath(__file__))

CLANS = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}
TRANSPARENT = (0, 0, 0, 0)

SWORD_GRIP = (95, 60, 32)
SWORD_EDGE = (130, 135, 150)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


def draw_sword_on_back(d, ox, oy):
    px(d, ox + 12, oy + 0, SWORD_GRIP)
    px(d, ox + 13, oy + 1, SWORD_GRIP)
    px(d, ox + 12, oy + 1, SWORD_EDGE)
    px(d, ox + 13, oy + 2, SWORD_EDGE)


def no_back(d, clan, ox, oy):
    pass


def back_sword(d, clan, ox, oy):
    draw_sword_on_back(d, ox, oy)


def draw_leg(d, pal, x, top, bot, foot_y, ox, oy):
    """3px-wide leg (x..x+2) with shaded trailing edge + a foot/hoof/boot row."""
    rect(d, ox + x, oy + top, ox + x + 2, oy + bot, pal['main'])
    for yy in range(top, bot + 1):
        px(d, ox + x + 2, oy + yy, pal['shadow'])
    rect(d, ox + x, oy + foot_y, ox + x + 2, oy + foot_y, pal['foot'])


# ==========================================================================
# ENDOBOT — chrome combat skull, one red optic, bared metal teeth
# ==========================================================================
ST_M, ST_H, ST_S = (152, 162, 178), (212, 218, 228), (94, 102, 122)
DARKMETAL = (50, 54, 70)
TEETH, TEETH_SH = (226, 230, 238), (150, 156, 172)
RED, RED_HI = (255, 52, 52), (255, 168, 150)


def endo_head(d, clan, ox, oy, anim=0):
    # cranium with a top gleam + side shading
    rect(d, ox + 4, oy + 0, ox + 11, oy + 0, ST_S)
    rect(d, ox + 4, oy + 1, ox + 11, oy + 4, ST_M)
    rect(d, ox + 4, oy + 1, ox + 4, oy + 4, ST_H)
    rect(d, ox + 11, oy + 1, ox + 11, oy + 4, ST_S)
    px(d, ox + 5, oy + 1, ST_H); px(d, ox + 6, oy + 1, ST_H)
    # sunken brow + cheek seams
    rect(d, ox + 5, oy + 2, ox + 10, oy + 2, DARKMETAL)
    px(d, ox + 4, oy + 3, ST_S); px(d, ox + 11, oy + 3, DARKMETAL)
    # ONE glowing red optic (front/left) + faint flicker halo; dead socket on the right
    halo = RED_HI if anim else (255, 120, 110)
    px(d, ox + 5, oy + 3, halo)
    px(d, ox + 6, oy + 3, RED)
    px(d, ox + 6, oy + 2, RED)
    px(d, ox + 9, oy + 3, DARKMETAL); px(d, ox + 10, oy + 3, ST_S)
    # bared metal teeth (clenched jaw)
    rect(d, ox + 5, oy + 5, ox + 10, oy + 5, TEETH)
    px(d, ox + 6, oy + 5, TEETH_SH); px(d, ox + 8, oy + 5, TEETH_SH); px(d, ox + 10, oy + 5, TEETH_SH)
    rect(d, ox + 5, oy + 6, ox + 10, oy + 6, ST_S)


def endo_torso(d, clan, ox, oy, by_off, tail=True, anim=0):
    C, CH = clan['main'], clan['hi']
    by = oy + by_off
    rect(d, ox + 3, by, ox + 12, by + 3, ST_M)
    rect(d, ox + 3, by, ox + 3, by + 3, ST_H)
    rect(d, ox + 12, by, ox + 12, by + 3, ST_S)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, ST_S)
    # rib / piston panel lines
    px(d, ox + 5, by + 1, ST_S); px(d, ox + 10, by + 1, ST_S)
    px(d, ox + 5, by + 2, DARKMETAL); px(d, ox + 10, by + 2, DARKMETAL)
    # glowing clan-coloured chest core
    px(d, ox + 7, by + 1, CH); px(d, ox + 8, by + 1, CH)
    px(d, ox + 7, by + 2, C); px(d, ox + 8, by + 2, C)


ENDOBOT = {
    'name': 'endobot', 'label': 'ENDOBOT',
    'head': endo_head, 'torso': endo_torso, 'back': no_back,
    'leg': {'main': ST_M, 'hi': ST_H, 'shadow': ST_S, 'foot': DARKMETAL},
    'arm': ST_M, 'armhi': ST_H,
}


# ==========================================================================
# NEKO — sleek ninja cat: pointed ears, slit eyes, whiskers, swishy tail
# ==========================================================================
EAR_IN = (250, 180, 200)
CAT_EYE, CAT_SLIT = (150, 255, 150), (24, 44, 24)
NOSE = (245, 150, 175)
WH = (242, 242, 252)
CREAM = (250, 240, 220)
SCARF = (44, 44, 60)


def neko_head(d, clan, ox, oy, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    et = oy - (1 if anim else 0)   # ears flick up
    # ears (tall triangles, pink inner)
    px(d, ox + 4, et + 0, M); px(d, ox + 4, oy + 1, M); px(d, ox + 5, oy + 1, EAR_IN)
    px(d, ox + 11, et + 0, M); px(d, ox + 11, oy + 1, M); px(d, ox + 10, oy + 1, EAR_IN)
    # head
    rect(d, ox + 4, oy + 2, ox + 11, oy + 6, M)
    rect(d, ox + 4, oy + 2, ox + 4, oy + 6, H)
    rect(d, ox + 11, oy + 2, ox + 11, oy + 6, S)
    rect(d, ox + 5, oy + 6, ox + 10, oy + 6, S)
    # big eyes with vertical slit pupils
    rect(d, ox + 5, oy + 3, ox + 6, oy + 4, CAT_EYE); rect(d, ox + 6, oy + 3, ox + 6, oy + 4, CAT_SLIT)
    rect(d, ox + 9, oy + 3, ox + 10, oy + 4, CAT_EYE); rect(d, ox + 9, oy + 3, ox + 9, oy + 4, CAT_SLIT)
    # muzzle: nose + tiny fang
    px(d, ox + 7, oy + 5, NOSE); px(d, ox + 8, oy + 5, NOSE)
    px(d, ox + 7, oy + 6, WH)
    # whiskers
    px(d, ox + 2, oy + 4, WH); px(d, ox + 3, oy + 5, WH)
    px(d, ox + 13, oy + 4, WH); px(d, ox + 12, oy + 5, WH)


def neko_torso(d, clan, ox, oy, by_off, tail=True, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    by = oy + by_off
    rect(d, ox + 3, by, ox + 12, by + 3, M)
    rect(d, ox + 3, by, ox + 3, by + 3, H)
    rect(d, ox + 12, by, ox + 12, by + 3, S)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, S)
    # cream belly + dark ninja scarf
    rect(d, ox + 6, by + 1, ox + 9, by + 3, CREAM)
    rect(d, ox + 4, by, ox + 11, by, SCARF)
    px(d, ox + 4, by, S)
    # swishy tail off the rump
    if tail:
        if anim:
            px(d, ox + 13, by + 1, M); px(d, ox + 14, by + 0, M); px(d, ox + 14, by - 1, H)
        else:
            px(d, ox + 13, by + 1, M); px(d, ox + 14, by + 1, M); px(d, ox + 14, by + 0, H)


NEKO = {
    'name': 'neko', 'label': 'NEKO',
    'head': neko_head, 'torso': neko_torso, 'back': back_sword,
    'leg': 'clan', 'foot': (40, 40, 55),
    'arm': 'clan', 'armhi': 'clan',
}


# ==========================================================================
# STALKER — bio-masked hunter: dreadlocks, mandible tusks, shoulder cannon
# ==========================================================================
SKIN, SKIN_H, SKIN_S = (198, 178, 130), (224, 208, 162), (150, 128, 88)
DREAD, DREAD_TIP = (58, 46, 38), (150, 132, 96)
TUSK = (232, 222, 200)
CANNON, CANNON_HI = (96, 102, 116), (150, 158, 172)
NETDOT = (120, 108, 80)


def stalker_back(d, clan, ox, oy):
    # shoulder plasma cannon arm over the right shoulder, glowing clan tip
    px(d, ox + 12, oy + 4, CANNON); px(d, ox + 13, oy + 4, CANNON_HI)
    px(d, ox + 12, oy + 3, CANNON)
    px(d, ox + 13, oy + 3, clan['hi'])   # targeting glow


def stalker_head(d, clan, ox, oy, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    # dreadlocks framing the head (banded: dark with light tips)
    for hx in (4, 11):
        px(d, ox + hx, oy + 1, DREAD)
    px(d, ox + 3, oy + 3, DREAD); px(d, ox + 3, oy + 4, DREAD_TIP)
    px(d, ox + 12, oy + 3, DREAD); px(d, ox + 12, oy + 4, DREAD_TIP)
    px(d, ox + 4, oy + 6, DREAD); px(d, ox + 11, oy + 6, DREAD)
    # bio-mask (clan metal) with side shading
    rect(d, ox + 5, oy + 1, ox + 10, oy + 5, M)
    rect(d, ox + 5, oy + 1, ox + 5, oy + 5, H)
    rect(d, ox + 10, oy + 1, ox + 10, oy + 5, S)
    px(d, ox + 7, oy + 2, S); px(d, ox + 8, oy + 2, S)   # mask seam
    # glowing eye slits
    px(d, ox + 6, oy + 3, (210, 255, 255)); px(d, ox + 9, oy + 3, (210, 255, 255))
    # mandible tusks + teeth at the jaw
    px(d, ox + 5, oy + 6, SKIN_S); px(d, ox + 6, oy + 6, SKIN)
    px(d, ox + 9, oy + 6, SKIN); px(d, ox + 10, oy + 6, SKIN_S)
    px(d, ox + 7, oy + 6, TUSK); px(d, ox + 8, oy + 6, TUSK)


def stalker_torso(d, clan, ox, oy, by_off, tail=True, anim=0):
    C, H, S = clan['main'], clan['hi'], clan['shadow']
    by = oy + by_off
    rect(d, ox + 3, by, ox + 12, by + 3, SKIN)
    rect(d, ox + 3, by, ox + 3, by + 3, SKIN_H)
    rect(d, ox + 12, by, ox + 12, by + 3, SKIN_S)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, SKIN_S)
    # net-mesh texture
    px(d, ox + 6, by + 2, NETDOT); px(d, ox + 8, by + 2, NETDOT); px(d, ox + 10, by + 1, NETDOT)
    # clan shoulder pauldrons
    rect(d, ox + 3, by, ox + 4, by + 1, C); px(d, ox + 3, by, H)
    rect(d, ox + 11, by, ox + 12, by + 1, C); px(d, ox + 12, by, S)
    # bandolier (dark diagonal)
    px(d, ox + 5, by, DREAD); px(d, ox + 6, by + 1, DREAD); px(d, ox + 7, by + 2, DREAD)


STALKER = {
    'name': 'stalker', 'label': 'STALKER',
    'head': stalker_head, 'torso': stalker_torso, 'back': stalker_back,
    'leg': {'main': SKIN, 'hi': SKIN_H, 'shadow': SKIN_S, 'foot': (58, 48, 40)},
    'arm': SKIN, 'armhi': SKIN_H,
}


# ==========================================================================
# IRONCLAD — armored suit: gold faceplate, glowing eye slits + arc-reactor core
# ==========================================================================
GOLD, GOLD_SH = (238, 198, 96), (186, 142, 52)
CORE, CORE_HI = (190, 248, 255), (255, 255, 255)
SLIT_EYE = (200, 250, 255)
MOUTH = (60, 50, 30)


def iron_head(d, clan, ox, oy, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    # helmet shell
    rect(d, ox + 5, oy + 0, ox + 10, oy + 0, M)
    rect(d, ox + 4, oy + 1, ox + 11, oy + 6, M)
    rect(d, ox + 4, oy + 1, ox + 4, oy + 6, H)
    rect(d, ox + 11, oy + 1, ox + 11, oy + 6, S)
    px(d, ox + 6, oy + 1, H)                 # forehead gleam
    # gold faceplate
    rect(d, ox + 5, oy + 2, ox + 10, oy + 5, GOLD)
    rect(d, ox + 5, oy + 5, ox + 10, oy + 5, GOLD_SH)
    px(d, ox + 5, oy + 2, (255, 230, 150))
    # angular glowing eye slits
    px(d, ox + 6, oy + 3, SLIT_EYE); px(d, ox + 9, oy + 3, SLIT_EYE)
    px(d, ox + 7, oy + 3, GOLD_SH); px(d, ox + 8, oy + 3, GOLD_SH)
    # mouth vent
    rect(d, ox + 6, oy + 5, ox + 9, oy + 5, MOUTH)


def iron_torso(d, clan, ox, oy, by_off, tail=True, anim=0):
    M, H, S = clan['main'], clan['hi'], clan['shadow']
    by = oy + by_off
    rect(d, ox + 3, by, ox + 12, by + 3, M)
    rect(d, ox + 3, by, ox + 3, by + 3, H)
    rect(d, ox + 12, by, ox + 12, by + 3, S)
    rect(d, ox + 4, by + 3, ox + 11, by + 3, S)
    # gold shoulder trim + waist line
    px(d, ox + 3, by, GOLD); px(d, ox + 12, by, GOLD)
    px(d, ox + 4, by + 3, GOLD_SH); px(d, ox + 11, by + 3, GOLD_SH)
    # arc-reactor chest core (bright)
    px(d, ox + 7, by + 1, CORE); px(d, ox + 8, by + 1, CORE_HI)
    px(d, ox + 7, by + 2, CORE_HI); px(d, ox + 8, by + 2, CORE)


IRONCLAD = {
    'name': 'ironclad', 'label': 'IRONCLAD',
    'head': iron_head, 'torso': iron_torso, 'back': no_back,
    'leg': 'clan', 'foot': GOLD_SH,
    'arm': 'clan', 'armhi': 'clan',
}


CHARACTERS = [ENDOBOT, NEKO, STALKER, IRONCLAD]


# --- shared animation rig -------------------------------------------------
def legpal(ch, clan):
    if ch['leg'] == 'clan':
        return {'main': clan['main'], 'hi': clan['hi'], 'shadow': clan['shadow'], 'foot': ch['foot']}
    return ch['leg']


def armcol(ch, clan):
    a = clan['main'] if ch['arm'] == 'clan' else ch['arm']
    ah = clan['hi'] if ch['armhi'] == 'clan' else ch['armhi']
    return a, ah


# 5-pose sheet --------------------------------------------------------------
def pose(ch, clan, d, ox, oy, which):
    lp = legpal(ch, clan)
    if which == 'jump':
        ch['back'](d, clan, ox, oy - 1)
        ch['head'](d, clan, ox, oy - 1, 0)
        ch['torso'](d, clan, ox, oy - 1, 7)
        draw_leg(d, lp, 4, 10, 11, 12, ox, oy)
        draw_leg(d, lp, 9, 10, 11, 12, ox, oy)
        return
    if which != 'attack':
        ch['back'](d, clan, ox, oy)
    ch['head'](d, clan, ox, oy, 0)
    ch['torso'](d, clan, ox, oy, 7)
    if which == 'idle':
        draw_leg(d, lp, 4, 11, 12, 13, ox, oy); draw_leg(d, lp, 9, 11, 12, 13, ox, oy)
    elif which == 'walk1':
        draw_leg(d, lp, 3, 11, 12, 13, ox, oy); draw_leg(d, lp, 9, 11, 13, 14, ox, oy)
    elif which == 'walk2':
        draw_leg(d, lp, 4, 11, 13, 14, ox, oy); draw_leg(d, lp, 10, 11, 12, 13, ox, oy)
    elif which == 'attack':
        a, ah = armcol(ch, clan)
        px(d, ox + 2, oy + 9, a); px(d, ox + 1, oy + 10, ah); px(d, ox + 2, oy + 10, lp['shadow'])
        draw_leg(d, lp, 3, 11, 13, 14, ox, oy); draw_leg(d, lp, 10, 11, 12, 13, ox, oy)


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


def idle6(ch, clan, d, ox, oy, f):
    e = IDLE[f]; dy = e['dy']; lp = legpal(ch, clan)
    ch['back'](d, clan, ox, oy + dy)
    ch['head'](d, clan, ox, oy + dy, e['a'])
    ch['torso'](d, clan, ox, oy + dy, 7, True, e['a'])
    draw_leg(d, lp, 4, 11, 12, 13, ox, oy); draw_leg(d, lp, 9, 11, 12, 13, ox, oy)


def walk6(ch, clan, d, ox, oy, f):
    e = WALK[f]; dy = e['dy']; lp = legpal(ch, clan)
    ch['back'](d, clan, ox, oy + dy)
    ch['head'](d, clan, ox, oy + dy, e['a'])
    ch['torso'](d, clan, ox, oy + dy, 7, True, e['a'])
    draw_leg(d, lp, *e['L'], ox, oy); draw_leg(d, lp, *e['R'], ox, oy)


def swing6(ch, clan, d, ox, oy, f):
    e = SWING[f]; lean = e['lean']; lp = legpal(ch, clan)
    a, ah = armcol(ch, clan)
    ch['head'](d, clan, ox + lean, oy, 0)
    ch['torso'](d, clan, ox + lean, oy, 7, False, 0)   # tail tucked during the slash
    draw_leg(d, lp, *e['L'], ox, oy); draw_leg(d, lp, *e['R'], ox, oy)
    sx, sy = e['arm_from']; hx, hy = e['hands'][0]
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    for i in range(steps + 1):
        ax = round(sx + (hx - sx) * i / steps); ay = round(sy + (hy - sy) * i / steps)
        px(d, ox + ax, oy + ay, a)
    for j, (hx, hy) in enumerate(e['hands']):
        px(d, ox + hx, oy + hy, ah if j == 0 else a)


# --- render ---------------------------------------------------------------
def render_poses(ch, clan):
    img = Image.new('RGBA', (SPRITE * 5, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, w in enumerate(POSE_ORDER):
        pose(ch, clan, d, i * SPRITE, 0, w)
    return img


def render_strip6(fn, ch, clan):
    img = Image.new('RGBA', (SPRITE * 6, SPRITE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i in range(6):
        fn(ch, clan, d, i * SPRITE, 0, i)
    return img


def main():
    rows = []
    for ch in CHARACTERS:
        cost = os.path.join(OUT, 'costumes', ch['name'])
        os.makedirs(cost, exist_ok=True)
        for color, clan in CLANS.items():
            poses = render_poses(ch, clan)
            idle = render_strip6(idle6, ch, clan)
            walk = render_strip6(walk6, ch, clan)
            swing = render_strip6(swing6, ch, clan)
            poses.save(os.path.join(cost, f'{color}_native_80x16.png'))
            poses.resize((80 * 4, 16 * 4), Image.NEAREST).save(os.path.join(cost, f'{color}_4x_320x64.png'))
            poses.resize((80 * 8, 16 * 8), Image.NEAREST).save(os.path.join(cost, f'{color}_8x_640x128.png'))
            idle.save(os.path.join(cost, f'{color}_idle_6frame_native_96x16.png'))
            walk.save(os.path.join(cost, f'{color}_walk_6frame_native_96x16.png'))
            swing.save(os.path.join(cost, f'{color}_swing_6frame_native_96x16.png'))
            if color == 'magenta':
                rows += [(f"{ch['label']} pose", poses), (f"{ch['label']} idle", idle),
                         (f"{ch['label']} walk", walk), (f"{ch['label']} swing", swing)]
        # 4-colour pose comparison row for this character
        cmp = Image.new('RGBA', (SPRITE * 5 * 4 + 4 * 3, SPRITE), TRANSPARENT)
        x = 0
        for color, clan in CLANS.items():
            cmp.paste(render_poses(ch, clan), (x, 0))
            x += SPRITE * 5 + 4
        rows.append((f"{ch['label']} 4-clan", cmp))
        print('wrote', ch['name'])

    # stacked review sheet (magenta sheets + per-char 4-clan rows), 8x
    scale, pad = 8, 6
    w = max(s.size[0] for _, s in rows) * scale + pad * 2
    h = sum(s.size[1] * scale + pad for _, s in rows) + pad
    pv = Image.new('RGBA', (w, h), (26, 22, 34, 255))
    y = pad
    for _, s in rows:
        big = s.resize((s.size[0] * scale, s.size[1] * scale), Image.NEAREST)
        pv.paste(big, (pad, y), big)
        y += s.size[1] * scale + pad
    pv.save(os.path.join(OUT, 'costumes', '_heroes_preview.png'))
    print('wrote _heroes_preview.png')


if __name__ == '__main__':
    main()
