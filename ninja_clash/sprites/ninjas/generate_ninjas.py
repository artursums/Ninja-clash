"""
4 TowerFall-inspired ninja characters.
- Native sprite: 16x16 px
- Poses per character: idle, walk1, walk2, jump, attack
- Sprite strip per ninja: 80x16 native -> upscaled 8x to 640x128
- Output: one transparent PNG per ninja (+ native + 4x versions)
"""

from PIL import Image, ImageDraw

SPRITE = 16
POSES = ['idle', 'walk1', 'walk2', 'jump', 'attack']
SHEET_W = SPRITE * len(POSES)   # 80
SHEET_H = SPRITE                 # 16

# ------------------------------------------------------------------
# TowerFall-style 4 palette (main / highlight / shadow)
# ------------------------------------------------------------------
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

# Universal accent colors
MASK_BLACK   = (20, 16, 30)
EYE_GLOW     = (255, 240, 90)
SASH         = (245, 240, 225)
SASH_SHADE   = (170, 160, 145)
FOOT         = (32, 26, 42)
SWORD_GRIP   = (95, 60, 32)
SWORD_BLADE  = (210, 215, 225)
SWORD_EDGE   = (130, 135, 150)
SHURIKEN     = (180, 188, 200)
SHURIKEN_DRK = (90, 95, 110)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# ------------------------------------------------------------------
# Sword on back — small pommel + grip sticking up behind the head
# ------------------------------------------------------------------
def draw_sword_on_back(d, ox, oy):
    # diagonal hilt above right shoulder
    px(d, ox+12, oy+0, SWORD_GRIP)
    px(d, ox+13, oy+1, SWORD_GRIP)
    px(d, ox+12, oy+1, SWORD_EDGE)   # guard
    px(d, ox+13, oy+2, SWORD_EDGE)


# ------------------------------------------------------------------
# Hood + face — used by all poses (origin at top-left of bounding box)
# ------------------------------------------------------------------
def draw_head(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    # hood silhouette
    rect(d, ox+5, oy+1, ox+10, oy+1, H)            # top tip
    rect(d, ox+4, oy+2, ox+11, oy+2, M)
    rect(d, ox+4, oy+3, ox+11, oy+5, M)
    # shadow edge on right of hood
    rect(d, ox+11, oy+2, ox+11, oy+5, S)
    rect(d, ox+10, oy+5, ox+11, oy+5, S)
    # highlight tuft on left of hood
    px(d, ox+4, oy+2, H)
    px(d, ox+4, oy+3, H)
    # face mask (cloth band)
    rect(d, ox+5, oy+3, ox+10, oy+5, MASK_BLACK)
    # eyes
    px(d, ox+6, oy+4, EYE_GLOW)
    px(d, ox+9, oy+4, EYE_GLOW)


# ------------------------------------------------------------------
# Body + sash (no legs — legs vary per pose)
# ------------------------------------------------------------------
def draw_torso(d, p, ox, oy, body_y=6):
    M, H, S = p['main'], p['hi'], p['shadow']
    by = oy + body_y
    # torso block
    rect(d, ox+3, by,   ox+12, by+3, M)
    # left-edge highlight
    rect(d, ox+3, by,   ox+3,  by+3, H)
    # right-edge shadow
    rect(d, ox+12, by,  ox+12, by+3, S)
    # bottom shadow row
    rect(d, ox+4, by+3, ox+11, by+3, S)
    # sash
    rect(d, ox+4, by+1, ox+11, by+1, SASH)
    px(d, ox+10, by+2, SASH_SHADE)
    px(d, ox+11, by+2, SASH_SHADE)


# ------------------------------------------------------------------
# POSE: IDLE
# ------------------------------------------------------------------
def pose_idle(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    # legs (split)
    rect(d, ox+4, oy+10, ox+6,  oy+12, M)
    rect(d, ox+9, oy+10, ox+11, oy+12, M)
    # leg shading
    rect(d, ox+6, oy+10, ox+6,  oy+12, S)
    rect(d, ox+11,oy+10, ox+11, oy+12, S)
    # feet (split-toe tabi)
    rect(d, ox+4, oy+13, ox+6,  oy+13, FOOT)
    rect(d, ox+9, oy+13, ox+11, oy+13, FOOT)


# ------------------------------------------------------------------
# POSE: WALK 1 (left leg forward)
# ------------------------------------------------------------------
def pose_walk1(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    # left leg lifted slightly forward
    rect(d, ox+3, oy+10, ox+5,  oy+12, M)
    px(d, ox+5, oy+10, S); px(d, ox+5, oy+12, S)
    # right leg planted
    rect(d, ox+9, oy+10, ox+11, oy+13, M)
    px(d, ox+11, oy+10, S); px(d, ox+11, oy+11, S); px(d, ox+11, oy+12, S); px(d, ox+11, oy+13, S)
    # feet
    rect(d, ox+3, oy+13, ox+5, oy+13, FOOT)
    rect(d, ox+9, oy+14, ox+11, oy+14, FOOT)


# ------------------------------------------------------------------
# POSE: WALK 2 (right leg forward — mirror of walk1)
# ------------------------------------------------------------------
def pose_walk2(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    # left leg planted
    rect(d, ox+4, oy+10, ox+6, oy+13, M)
    px(d, ox+6, oy+10, S); px(d, ox+6, oy+11, S); px(d, ox+6, oy+12, S); px(d, ox+6, oy+13, S)
    # right leg lifted forward
    rect(d, ox+10, oy+10, ox+12, oy+12, M)
    px(d, ox+12, oy+10, S); px(d, ox+12, oy+12, S)
    # feet
    rect(d, ox+4, oy+14, ox+6, oy+14, FOOT)
    rect(d, ox+10, oy+13, ox+12, oy+13, FOOT)


# ------------------------------------------------------------------
# POSE: JUMP (tucked, arms out)
# ------------------------------------------------------------------
def pose_jump(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    # shift figure up 1 px to feel airborne
    draw_sword_on_back(d, ox, oy-1)
    draw_head(d, p, ox, oy-1)
    # torso compressed
    by = oy + 5
    rect(d, ox+3, by, ox+12, by+3, M)
    rect(d, ox+3, by, ox+3,  by+3, H)
    rect(d, ox+12,by, ox+12, by+3, S)
    rect(d, ox+4, by+3, ox+11, by+3, S)
    rect(d, ox+4, by+1, ox+11, by+1, SASH)
    px(d, ox+10, by+2, SASH_SHADE); px(d, ox+11, by+2, SASH_SHADE)
    # arms out wide
    px(d, ox+2, by+1, M);  px(d, ox+1, by+2, M);  px(d, ox+2, by+2, S)
    px(d, ox+13, by+1, M); px(d, ox+14, by+2, M); px(d, ox+13, by+2, S)
    # legs tucked (compact)
    rect(d, ox+4, oy+9,  ox+6,  oy+11, M)
    rect(d, ox+9, oy+9,  ox+11, oy+11, M)
    rect(d, ox+6, oy+9,  ox+6,  oy+11, S)
    rect(d, ox+11,oy+9,  ox+11, oy+11, S)
    # feet pointing down/in
    rect(d, ox+5, oy+12, ox+6,  oy+12, FOOT)
    rect(d, ox+9, oy+12, ox+10, oy+12, FOOT)


# ------------------------------------------------------------------
# POSE: ATTACK (lunge forward, throwing shuriken)
# ------------------------------------------------------------------
def pose_attack(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    # extended throwing arm (right)
    px(d, ox+13, oy+7, M); px(d, ox+14, oy+7, M)
    px(d, ox+13, oy+8, S); px(d, ox+14, oy+8, S)
    # shuriken in flight just past the hand
    px(d, ox+15, oy+6, SHURIKEN)
    px(d, ox+15, oy+7, SHURIKEN)
    px(d, ox+15, oy+8, SHURIKEN)
    px(d, ox+14, oy+6, SHURIKEN_DRK)
    # legs in lunge — front leg bent, back leg extended
    rect(d, ox+4, oy+10, ox+6,  oy+12, M)
    rect(d, ox+6, oy+10, ox+6,  oy+12, S)
    rect(d, ox+8, oy+11, ox+11, oy+12, M)
    rect(d, ox+11,oy+11, ox+11, oy+12, S)
    # feet
    rect(d, ox+4, oy+13, ox+6, oy+13, FOOT)
    rect(d, ox+8, oy+13, ox+11, oy+13, FOOT)


POSE_FUNCS = {
    'idle':   pose_idle,
    'walk1':  pose_walk1,
    'walk2':  pose_walk2,
    'jump':   pose_jump,
    'attack': pose_attack,
}


# ------------------------------------------------------------------
# Render one ninja strip
# ------------------------------------------------------------------
def render_ninja(color_name, palette):
    img = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, pose in enumerate(POSES):
        ox = i * SPRITE
        oy = 0
        POSE_FUNCS[pose](d, palette, ox, oy)
    return img


OUT = '/sessions/nice-zen-rubin/mnt/outputs'

for name, palette in PALETTES.items():
    strip = render_ninja(name, palette)
    # native
    strip.save(f'{OUT}/ninja_{name}_native_80x16.png')
    # upscaled 4x (320x64) — small icon style
    strip.resize((SHEET_W*4, SHEET_H*4), Image.NEAREST).save(
        f'{OUT}/ninja_{name}_4x_320x64.png'
    )
    # upscaled 8x (640x128) — preview/showcase
    strip.resize((SHEET_W*8, SHEET_H*8), Image.NEAREST).save(
        f'{OUT}/ninja_{name}_8x_640x128.png'
    )
    print(f'Wrote ninja_{name} (native, 4x, 8x)')

# Also build a combined preview sheet (all 4 ninjas stacked) — handy for review
preview = Image.new('RGBA', (SHEET_W*8, SHEET_H*8 * 4 + 30), (24, 18, 36, 255))
y_off = 0
for name in ['cyan', 'magenta', 'orange', 'green']:
    s = Image.open(f'{OUT}/ninja_{name}_8x_640x128.png')
    preview.paste(s, (0, y_off), s)
    y_off += SHEET_H * 8
preview.save(f'{OUT}/ninjas_preview_all.png')
print('Wrote ninjas_preview_all.png')
