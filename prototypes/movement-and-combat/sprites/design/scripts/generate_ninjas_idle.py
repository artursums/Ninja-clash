"""
Idle-animation variation frames for each TowerFall-style ninja.
6 frames per ninja, designed to loop as a subtle "alive" idle:

  Frame 1: neutral       (rest)
  Frame 2: inhale_up     (body bobs up 1px - breathing in)
  Frame 3: exhale_down   (body bobs down 1px, knees bend - breathing out)
  Frame 4: blink         (eyes closed for a frame)
  Frame 5: look_left     (eyes shifted left - alertness)
  Frame 6: look_right    (eyes shifted right - alertness)

Suggested in-engine loop (60 fps):
  1,1,1,1,2,2,2,3,3,3,1,1,1,4,1,1,1,1,2,2,2,3,3,3,1,1,5,5,1,1,1,1,...
  i.e. mostly cycle 1->2->3 for breathing (~10 ticks/frame),
  occasionally pop a 4 (blink) or 5/6 (glance) at random.

Output: per-ninja transparent PNG strip (96x16 native + upscales).
"""

from PIL import Image, ImageDraw

SPRITE = 16
FRAMES = ['neutral', 'inhale_up', 'exhale_down', 'blink', 'look_left', 'look_right']
STRIP_W = SPRITE * len(FRAMES)   # 96
STRIP_H = SPRITE                 # 16

# Same palette as the main ninja generator
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

MASK_BLACK   = (20, 16, 30)
EYE_GLOW     = (255, 240, 90)
EYE_DIM      = (200, 180, 60)
SASH         = (245, 240, 225)
SASH_SHADE   = (170, 160, 145)
FOOT         = (32, 26, 42)
SWORD_GRIP   = (95, 60, 32)
SWORD_BLADE  = (210, 215, 225)
SWORD_EDGE   = (130, 135, 150)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    if x2 < x1 or y2 < y1:
        return
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# ---------------------------------------------------------
# Reusable parts — each takes a y-offset for bobbing
# ---------------------------------------------------------
def draw_sword_on_back(d, ox, oy):
    px(d, ox+12, oy+0, SWORD_GRIP)
    px(d, ox+13, oy+1, SWORD_GRIP)
    px(d, ox+12, oy+1, SWORD_EDGE)
    px(d, ox+13, oy+2, SWORD_EDGE)


def draw_head(d, p, ox, oy, eye_state='open', eye_dx=0):
    """eye_state: 'open' | 'closed'. eye_dx: -1, 0, +1 to shift eyes."""
    M, H, S = p['main'], p['hi'], p['shadow']
    # hood silhouette
    rect(d, ox+5, oy+1, ox+10, oy+1, H)
    rect(d, ox+4, oy+2, ox+11, oy+2, M)
    rect(d, ox+4, oy+3, ox+11, oy+5, M)
    rect(d, ox+11, oy+2, ox+11, oy+5, S)
    rect(d, ox+10, oy+5, ox+11, oy+5, S)
    px(d, ox+4, oy+2, H)
    px(d, ox+4, oy+3, H)
    # face mask band
    rect(d, ox+5, oy+3, ox+10, oy+5, MASK_BLACK)
    # eyes
    if eye_state == 'open':
        # clamp eye positions inside the mask band cols 5..10
        ex1 = max(5, min(10, 6 + eye_dx))
        ex2 = max(5, min(10, 9 + eye_dx))
        px(d, ox + ex1, oy+4, EYE_GLOW)
        px(d, ox + ex2, oy+4, EYE_GLOW)
    elif eye_state == 'closed':
        # closed eye = small dark slit (just black, kind of invisible),
        # use a faint dim mark so it still reads as "eyes closed"
        px(d, ox+6, oy+4, EYE_DIM)
        px(d, ox+9, oy+4, EYE_DIM)


def draw_torso(d, p, ox, oy_top, height=4):
    """Torso starts at oy_top, height=4 normal, =3 compressed, =5 stretched."""
    M, H, S = p['main'], p['hi'], p['shadow']
    by = oy_top
    rect(d, ox+3, by, ox+12, by + height - 1, M)
    rect(d, ox+3, by, ox+3,  by + height - 1, H)
    rect(d, ox+12, by, ox+12, by + height - 1, S)
    rect(d, ox+4, by + height - 1, ox+11, by + height - 1, S)
    # sash one row from the top
    rect(d, ox+4, by + 1, ox+11, by + 1, SASH)
    px(d, ox+10, by + 2, SASH_SHADE)
    px(d, ox+11, by + 2, SASH_SHADE)


def draw_legs_standing(d, p, ox, oy):
    """Standard standing legs at rows 10-13."""
    M, H, S = p['main'], p['hi'], p['shadow']
    rect(d, ox+4, oy+10, ox+6,  oy+12, M)
    rect(d, ox+9, oy+10, ox+11, oy+12, M)
    rect(d, ox+6, oy+10, ox+6,  oy+12, S)
    rect(d, ox+11,oy+10, ox+11, oy+12, S)
    rect(d, ox+4, oy+13, ox+6,  oy+13, FOOT)
    rect(d, ox+9, oy+13, ox+11, oy+13, FOOT)


def draw_legs_bent(d, p, ox, oy):
    """Compressed legs (knees bent) — feet still at row 13, body sinks."""
    M, H, S = p['main'], p['hi'], p['shadow']
    rect(d, ox+4, oy+11, ox+6,  oy+12, M)
    rect(d, ox+9, oy+11, ox+11, oy+12, M)
    rect(d, ox+6, oy+11, ox+6,  oy+12, S)
    rect(d, ox+11,oy+11, ox+11, oy+12, S)
    rect(d, ox+4, oy+13, ox+6,  oy+13, FOOT)
    rect(d, ox+9, oy+13, ox+11, oy+13, FOOT)


# ---------------------------------------------------------
# 6 idle variation frames
# ---------------------------------------------------------
def frame_neutral(d, p, ox, oy):
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy, eye_state='open', eye_dx=0)
    draw_torso(d, p, ox, oy+6, height=4)
    draw_legs_standing(d, p, ox, oy)


def frame_inhale_up(d, p, ox, oy):
    """Whole upper body bobs up 1px — torso stretches by 1 row to keep legs planted."""
    # head shifted up 1
    draw_sword_on_back(d, ox, oy - 1)
    draw_head(d, p, ox, oy - 1, eye_state='open', eye_dx=0)
    # torso stretched to 5 rows (oy+5 .. oy+9) to fill the gap to legs at oy+10
    draw_torso(d, p, ox, oy + 5, height=5)
    draw_legs_standing(d, p, ox, oy)


def frame_exhale_down(d, p, ox, oy):
    """Whole upper body sinks 1px — torso compresses, knees bend slightly."""
    draw_sword_on_back(d, ox, oy + 1)
    draw_head(d, p, ox, oy + 1, eye_state='open', eye_dx=0)
    # torso compressed to 3 rows (oy+7 .. oy+9)
    draw_torso(d, p, ox, oy + 7, height=3)
    draw_legs_bent(d, p, ox, oy)


def frame_blink(d, p, ox, oy):
    """Neutral pose with eyes closed."""
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy, eye_state='closed')
    draw_torso(d, p, ox, oy + 6, height=4)
    draw_legs_standing(d, p, ox, oy)


def frame_look_left(d, p, ox, oy):
    """Neutral pose, eyes shifted 1px left."""
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy, eye_state='open', eye_dx=-1)
    draw_torso(d, p, ox, oy + 6, height=4)
    draw_legs_standing(d, p, ox, oy)


def frame_look_right(d, p, ox, oy):
    """Neutral pose, eyes shifted 1px right."""
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy, eye_state='open', eye_dx=+1)
    draw_torso(d, p, ox, oy + 6, height=4)
    draw_legs_standing(d, p, ox, oy)


FRAME_FUNCS = {
    'neutral':     frame_neutral,
    'inhale_up':   frame_inhale_up,
    'exhale_down': frame_exhale_down,
    'blink':       frame_blink,
    'look_left':   frame_look_left,
    'look_right':  frame_look_right,
}


def render_idle_strip(palette):
    img = Image.new('RGBA', (STRIP_W, STRIP_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, fname in enumerate(FRAMES):
        FRAME_FUNCS[fname](d, palette, i * SPRITE, 0)
    return img


import os
OUT = '/sessions/nice-zen-rubin/mnt/outputs/ninjas/idle_animation'
os.makedirs(OUT, exist_ok=True)

for name, palette in PALETTES.items():
    strip = render_idle_strip(palette)
    strip.save(f'{OUT}/ninja_{name}_idle_6frame_native_96x16.png')
    strip.resize((STRIP_W*4, STRIP_H*4), Image.NEAREST).save(
        f'{OUT}/ninja_{name}_idle_6frame_4x_384x64.png'
    )
    strip.resize((STRIP_W*8, STRIP_H*8), Image.NEAREST).save(
        f'{OUT}/ninja_{name}_idle_6frame_8x_768x128.png'
    )
    print(f'Wrote ninja_{name}_idle_6frame (native, 4x, 8x)')

# Combined preview: 4 ninjas stacked vertically with frame labels
LABEL_H = 14
COL_W = STRIP_W * 8 // len(FRAMES)
preview_h = (STRIP_H * 8 + 8) * 4 + LABEL_H + 14
preview = Image.new('RGBA', (STRIP_W * 8, preview_h), (24, 18, 36, 255))
pd = ImageDraw.Draw(preview)

# header
labels = ['neutral', 'inhale', 'exhale', 'blink', 'look L', 'look R']
for i, lab in enumerate(labels):
    # simple frame separators
    pd.line([(i * COL_W, 0), (i * COL_W, preview_h)], fill=(50, 40, 70, 255))

y_off = LABEL_H
for name in ['cyan', 'magenta', 'orange', 'green']:
    s = Image.open(f'{OUT}/ninja_{name}_idle_6frame_8x_768x128.png')
    preview.paste(s, (0, y_off), s)
    y_off += STRIP_H * 8 + 8

preview.save(f'{OUT}/ninjas_idle_animations_preview.png')
print('Wrote ninjas_idle_animations_preview.png')
