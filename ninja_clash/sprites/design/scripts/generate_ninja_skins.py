"""
NINJA SKIN GENERATOR — Elemental alt-skins for the 4 clans.

Reuses the same 16x16 sprite system as generate_ninjas.py:
  * 5 poses: idle, walk1, walk2, jump, attack
  * 80x16 native strip per skin
  * 4x (320x64) + 8x (640x128) upscaled variants

Per-clan elemental skin:
  SHADOW (magenta) -> WRAITH    smoke wisps + hollow white eyes + dark sash
  STORM  (cyan)    -> TEMPEST   lightning bolt on chest + spark eyes
  FROST  (green)   -> GLACIER   ice crystals on shoulders + frosty rim
  FIRE   (orange)  -> INFERNO   flame tongue on hood + ember eyes + red sash

Outputs (sprites/ninjas/):
  ninja_<clan>_<element>_native_80x16.png
  ninja_<clan>_<element>_4x_320x64.png
  ninja_<clan>_<element>_8x_640x128.png
  ninja_skins_preview.png — side-by-side comparison vs original
"""

import os
from PIL import Image, ImageDraw, ImageFont


# ============================================================
#  CONFIG
# ============================================================
SPRITE = 16
POSES = ['idle', 'walk1', 'walk2', 'jump', 'attack']
SHEET_W = SPRITE * len(POSES)   # 80
SHEET_H = SPRITE                 # 16

_BASH = '/sessions/gracious-determined-hamilton/mnt/ninja_clash/sprites/ninjas'
_HOST = '/Users/a88/IdeaProjects/minu-mang/ninja_clash/sprites/ninjas'
OUT_DIR = _BASH if os.path.isdir(_BASH) else _HOST
os.makedirs(OUT_DIR, exist_ok=True)


# ============================================================
#  Palettes (matches generate_ninjas.py exactly so clan colors stay)
# ============================================================
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}

# Map clan-color → elemental skin name
CLAN_TO_SKIN = {
    'magenta': 'wraith',
    'cyan':    'tempest',
    'green':   'glacier',
    'orange':  'inferno',
}

# Universal accents (mirror generate_ninjas.py)
MASK_BLACK   = (20, 16, 30)
EYE_GLOW     = (255, 240, 90)
SASH         = (245, 240, 225)
SASH_SHADE   = (170, 160, 145)
FOOT         = (32, 26, 42)
SWORD_GRIP   = (95, 60, 32)
SWORD_EDGE   = (130, 135, 150)
SHURIKEN     = (180, 188, 200)
SHURIKEN_DRK = (90, 95, 110)

# Skin-specific accent colors
WRAITH_EYE     = (240, 232, 255)   # hollow ghost-white
WRAITH_SMOKE_LT = (190, 168, 210)
WRAITH_SMOKE_DK = (90, 70, 110)
WRAITH_SASH    = (60, 32, 78)

TEMPEST_EYE    = (200, 240, 255)   # spark-white
TEMPEST_BOLT   = (255, 232, 80)
TEMPEST_BOLT_HI = (255, 250, 200)
TEMPEST_SASH   = (140, 200, 230)
TEMPEST_SPARK  = (255, 244, 130)

GLACIER_EYE    = (215, 240, 255)
GLACIER_ICE    = (228, 244, 255)
GLACIER_ICE_HI = (255, 255, 255)
GLACIER_SASH   = (188, 224, 240)
GLACIER_FROST  = (210, 232, 248)

INFERNO_EYE    = (255, 200, 90)
INFERNO_FLAME_HOT = (255, 240, 140)
INFERNO_FLAME    = (255, 165, 50)
INFERNO_FLAME_DK = (200, 70, 30)
INFERNO_SASH   = (230, 80, 40)
INFERNO_EMBER  = (255, 200, 80)

TRANSPARENT = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


# ============================================================
#  Base ninja drawing (extracted from generate_ninjas.py)
# ============================================================
def draw_sword_on_back(d, ox, oy):
    px(d, ox+12, oy+0, SWORD_GRIP)
    px(d, ox+13, oy+1, SWORD_GRIP)
    px(d, ox+12, oy+1, SWORD_EDGE)
    px(d, ox+13, oy+2, SWORD_EDGE)


def draw_head(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    rect(d, ox+5, oy+1, ox+10, oy+1, H)
    rect(d, ox+4, oy+2, ox+11, oy+2, M)
    rect(d, ox+4, oy+3, ox+11, oy+5, M)
    rect(d, ox+11, oy+2, ox+11, oy+5, S)
    rect(d, ox+10, oy+5, ox+11, oy+5, S)
    px(d, ox+4, oy+2, H)
    px(d, ox+4, oy+3, H)
    rect(d, ox+5, oy+3, ox+10, oy+5, MASK_BLACK)
    px(d, ox+6, oy+4, EYE_GLOW)
    px(d, ox+9, oy+4, EYE_GLOW)


def draw_torso(d, p, ox, oy, body_y=6):
    M, H, S = p['main'], p['hi'], p['shadow']
    by = oy + body_y
    rect(d, ox+3, by, ox+12, by+3, M)
    rect(d, ox+3, by, ox+3, by+3, H)
    rect(d, ox+12, by, ox+12, by+3, S)
    rect(d, ox+4, by+3, ox+11, by+3, S)
    rect(d, ox+4, by+1, ox+11, by+1, SASH)
    px(d, ox+10, by+2, SASH_SHADE)
    px(d, ox+11, by+2, SASH_SHADE)


def pose_idle(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    rect(d, ox+4, oy+10, ox+6, oy+12, M)
    rect(d, ox+9, oy+10, ox+11, oy+12, M)
    rect(d, ox+6, oy+10, ox+6, oy+12, S)
    rect(d, ox+11, oy+10, ox+11, oy+12, S)
    rect(d, ox+4, oy+13, ox+6, oy+13, FOOT)
    rect(d, ox+9, oy+13, ox+11, oy+13, FOOT)


def pose_walk1(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    rect(d, ox+3, oy+10, ox+5, oy+12, M)
    px(d, ox+5, oy+10, S); px(d, ox+5, oy+12, S)
    rect(d, ox+9, oy+10, ox+11, oy+13, M)
    px(d, ox+11, oy+10, S); px(d, ox+11, oy+11, S)
    px(d, ox+11, oy+12, S); px(d, ox+11, oy+13, S)
    rect(d, ox+3, oy+13, ox+5, oy+13, FOOT)
    rect(d, ox+9, oy+14, ox+11, oy+14, FOOT)


def pose_walk2(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    rect(d, ox+4, oy+10, ox+6, oy+13, M)
    px(d, ox+6, oy+10, S); px(d, ox+6, oy+11, S)
    px(d, ox+6, oy+12, S); px(d, ox+6, oy+13, S)
    rect(d, ox+10, oy+10, ox+12, oy+12, M)
    px(d, ox+12, oy+10, S); px(d, ox+12, oy+12, S)
    rect(d, ox+4, oy+14, ox+6, oy+14, FOOT)
    rect(d, ox+10, oy+13, ox+12, oy+13, FOOT)


def pose_jump(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy-1)
    draw_head(d, p, ox, oy-1)
    by = oy + 5
    rect(d, ox+3, by, ox+12, by+3, M)
    rect(d, ox+3, by, ox+3, by+3, H)
    rect(d, ox+12, by, ox+12, by+3, S)
    rect(d, ox+4, by+3, ox+11, by+3, S)
    rect(d, ox+4, by+1, ox+11, by+1, SASH)
    px(d, ox+10, by+2, SASH_SHADE); px(d, ox+11, by+2, SASH_SHADE)
    px(d, ox+2, by+1, M); px(d, ox+1, by+2, M); px(d, ox+2, by+2, S)
    px(d, ox+13, by+1, M); px(d, ox+14, by+2, M); px(d, ox+13, by+2, S)
    rect(d, ox+4, oy+9, ox+6, oy+11, M)
    rect(d, ox+9, oy+9, ox+11, oy+11, M)
    rect(d, ox+6, oy+9, ox+6, oy+11, S)
    rect(d, ox+11, oy+9, ox+11, oy+11, S)
    rect(d, ox+5, oy+12, ox+6, oy+12, FOOT)
    rect(d, ox+9, oy+12, ox+10, oy+12, FOOT)


def pose_attack(d, p, ox, oy):
    M, H, S = p['main'], p['hi'], p['shadow']
    draw_sword_on_back(d, ox, oy)
    draw_head(d, p, ox, oy)
    draw_torso(d, p, ox, oy, body_y=6)
    px(d, ox+13, oy+7, M); px(d, ox+14, oy+7, M)
    px(d, ox+13, oy+8, S); px(d, ox+14, oy+8, S)
    px(d, ox+15, oy+6, SHURIKEN)
    px(d, ox+15, oy+7, SHURIKEN)
    px(d, ox+15, oy+8, SHURIKEN)
    px(d, ox+14, oy+6, SHURIKEN_DRK)
    rect(d, ox+4, oy+10, ox+6, oy+12, M)
    rect(d, ox+6, oy+10, ox+6, oy+12, S)
    rect(d, ox+8, oy+11, ox+11, oy+12, M)
    rect(d, ox+11, oy+11, ox+11, oy+12, S)
    rect(d, ox+4, oy+13, ox+6, oy+13, FOOT)
    rect(d, ox+8, oy+13, ox+11, oy+13, FOOT)


POSE_FUNCS = {
    'idle': pose_idle, 'walk1': pose_walk1,
    'walk2': pose_walk2, 'jump': pose_jump, 'attack': pose_attack,
}


# ============================================================
#  ELEMENTAL OVERLAYS — applied AFTER the base ninja is drawn.
#  Each takes the current `pose` so it can pick the right Y offsets
#  (jump uses oy-1 head + body_y=5; others use body_y=6).
# ============================================================
def _pose_offsets(pose):
    """Returns (head_oy_offset, body_y) for the given pose."""
    if pose == 'jump':
        return -1, 5
    return 0, 6


def apply_wraith(d, ox, oy, pose):
    """Smoke ghost: white eyes, dark sash, smoke wisps on shoulders + above hood."""
    head_off, body_y = _pose_offsets(pose)
    eye_y = oy + 4 + head_off
    by = oy + body_y

    # Hollow white eyes
    px(d, ox+6, eye_y, WRAITH_EYE)
    px(d, ox+9, eye_y, WRAITH_EYE)

    # Dark purple sash replaces white
    rect(d, ox+4, by+1, ox+11, by+1, WRAITH_SASH)
    px(d, ox+10, by+2, WRAITH_SASH)
    px(d, ox+11, by+2, WRAITH_SASH)

    # Smoke wisp trailing from left shoulder (semi-transparent feel via two-tone)
    if pose != 'attack':   # attack arm extends right, leave that side clean
        px(d, ox+2, by, WRAITH_SMOKE_LT)
        px(d, ox+1, by+1, WRAITH_SMOKE_DK)
    # Smoke wisp curling above hood (small)
    hood_top_y = oy + head_off
    if hood_top_y >= 0:
        px(d, ox+7, hood_top_y, WRAITH_SMOKE_LT)
    # tiny smoke tail behind right shoulder when not attacking
    if pose == 'idle' or pose == 'walk1' or pose == 'walk2':
        px(d, ox+13, by + 2, WRAITH_SMOKE_DK)


def apply_tempest(d, ox, oy, pose):
    """Lightning bolt on chest, spark eyes, electric sash."""
    head_off, body_y = _pose_offsets(pose)
    eye_y = oy + 4 + head_off
    by = oy + body_y

    # Spark-white eyes
    px(d, ox+6, eye_y, TEMPEST_EYE)
    px(d, ox+9, eye_y, TEMPEST_EYE)

    # Replace sash with electric cyan-yellow
    rect(d, ox+4, by+1, ox+11, by+1, TEMPEST_SASH)

    # Lightning Z bolt on chest center (2px wide, 3 rows zigzag)
    # We carefully place inside body (which is by..by+3) — using yellow
    # against the clan-cyan body.
    # Lightning shape:  ##.
    #                   .#.
    #                   .##
    if pose != 'jump':
        px(d, ox+7, by,   TEMPEST_BOLT)
        px(d, ox+8, by,   TEMPEST_BOLT)
        px(d, ox+8, by+1, TEMPEST_BOLT_HI)
        px(d, ox+8, by+2, TEMPEST_BOLT)
        px(d, ox+9, by+2, TEMPEST_BOLT)
    else:
        # jump pose: shift bolt up 1 to match compressed torso
        px(d, ox+7, by,   TEMPEST_BOLT)
        px(d, ox+8, by,   TEMPEST_BOLT)
        px(d, ox+8, by+1, TEMPEST_BOLT_HI)
        px(d, ox+8, by+2, TEMPEST_BOLT)

    # Spark dots above each shoulder (just one or two)
    if pose != 'attack':
        px(d, ox+3, by - 1, TEMPEST_SPARK)
        px(d, ox+12, by - 1, TEMPEST_SPARK)


def apply_glacier(d, ox, oy, pose):
    """Ice crystals on shoulders, pale eyes, frosty hood rim."""
    head_off, body_y = _pose_offsets(pose)
    eye_y = oy + 4 + head_off
    by = oy + body_y

    # Pale ice eyes
    px(d, ox+6, eye_y, GLACIER_EYE)
    px(d, ox+9, eye_y, GLACIER_EYE)

    # Icy white sash
    rect(d, ox+4, by+1, ox+11, by+1, GLACIER_SASH)

    # Frost rim along the top of the hood (replace highlight pixels)
    hood_top_y = oy + 1 + head_off
    if hood_top_y >= 0:
        px(d, ox+5, hood_top_y, GLACIER_FROST)
        px(d, ox+6, hood_top_y, GLACIER_ICE_HI)
        px(d, ox+9, hood_top_y, GLACIER_ICE_HI)
        px(d, ox+10, hood_top_y, GLACIER_FROST)

    # Ice crystal spike at left shoulder (2-pixel triangle)
    if pose != 'attack':
        px(d, ox+2, by, GLACIER_ICE)
        px(d, ox+2, by + 1, GLACIER_ICE_HI)
    # Right shoulder crystal — skip for attack (arm extended right)
    if pose != 'attack':
        px(d, ox+13, by, GLACIER_ICE)
        px(d, ox+13, by + 1, GLACIER_ICE_HI)

    # Frost breath puff in front of mouth (small)
    mouth_y = oy + 5 + head_off
    if mouth_y >= 0 and pose != 'jump':
        px(d, ox+11, mouth_y, GLACIER_FROST)


def apply_inferno(d, ox, oy, pose):
    """Flame tongue on hood top, ember eyes, glowing red sash."""
    head_off, body_y = _pose_offsets(pose)
    eye_y = oy + 4 + head_off
    by = oy + body_y
    hood_top_y = oy + 1 + head_off

    # Ember eyes
    px(d, ox+6, eye_y, INFERNO_EYE)
    px(d, ox+9, eye_y, INFERNO_EYE)

    # Glowing red sash
    rect(d, ox+4, by+1, ox+11, by+1, INFERNO_SASH)
    px(d, ox+10, by+2, INFERNO_FLAME_DK)
    px(d, ox+11, by+2, INFERNO_FLAME_DK)

    # Flame on top of hood — replace highlight with flame colors.
    # The hood tip row is at hood_top_y (oy+1 or oy+0 for jump).
    if hood_top_y >= 0:
        # Base of flame (red)
        px(d, ox+6, hood_top_y, INFERNO_FLAME_DK)
        px(d, ox+7, hood_top_y, INFERNO_FLAME)
        px(d, ox+8, hood_top_y, INFERNO_FLAME_HOT)
        px(d, ox+9, hood_top_y, INFERNO_FLAME)
        px(d, ox+10, hood_top_y, INFERNO_FLAME_DK)
    # Optional flame tip rising above the hood (only when there's room)
    tip_y = hood_top_y - 1
    if tip_y >= 0:
        px(d, ox+7, tip_y, INFERNO_FLAME)
        px(d, ox+8, tip_y, INFERNO_FLAME_HOT)
        px(d, ox+9, tip_y, INFERNO_FLAME)

    # Ember spark on left shoulder (skip for attack since arm is at right)
    if pose != 'attack':
        px(d, ox+2, by + 1, INFERNO_EMBER)


SKIN_APPLY = {
    'wraith':  apply_wraith,
    'tempest': apply_tempest,
    'glacier': apply_glacier,
    'inferno': apply_inferno,
}


# ============================================================
#  Build a full strip for one clan+skin
# ============================================================
def render_skin_strip(clan, skin):
    palette = PALETTES[clan]
    img = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, pose in enumerate(POSES):
        ox = i * SPRITE
        oy = 0
        # Base ninja first
        POSE_FUNCS[pose](d, palette, ox, oy)
        # Then elemental overlay
        SKIN_APPLY[skin](d, ox, oy, pose)
    return img


def render_base_strip(clan):
    """Render the unmodified base ninja strip — used in the
       preview composition so we can show original vs alt skin."""
    palette = PALETTES[clan]
    img = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, pose in enumerate(POSES):
        POSE_FUNCS[pose](d, palette, i * SPRITE, 0)
    return img


# ============================================================
#  Main: write all 4 skins + comparison preview
# ============================================================
def main():
    print('=== ELEMENTAL NINJA SKINS ===')
    for clan, skin in CLAN_TO_SKIN.items():
        strip = render_skin_strip(clan, skin)
        strip.save(f'{OUT_DIR}/ninja_{clan}_{skin}_native_80x16.png')
        strip.resize((SHEET_W * 4, SHEET_H * 4),
                     Image.NEAREST).save(
            f'{OUT_DIR}/ninja_{clan}_{skin}_4x_320x64.png')
        strip.resize((SHEET_W * 8, SHEET_H * 8),
                     Image.NEAREST).save(
            f'{OUT_DIR}/ninja_{clan}_{skin}_8x_640x128.png')
        print(f'  ninja_{clan}_{skin}  (5 poses, native+4x+8x)')

    # Comparison preview — original vs new skin, per clan
    print('\nBuilding comparison preview...')
    SCALE = 8
    sw = SHEET_W * SCALE
    sh = SHEET_H * SCALE
    pad = 16
    label_h = 28
    header_h = 40
    rows_per_clan = 2     # original, alt-skin
    n_clans = len(CLAN_TO_SKIN)
    total_w = sw + pad * 2 + 200
    total_h = (sh + label_h + pad) * rows_per_clan * n_clans + \
              pad * n_clans + header_h + pad

    bg = Image.new('RGBA', (total_w, total_h), (24, 18, 36, 255))
    d = ImageDraw.Draw(bg)

    # Tile checker
    for y in range(0, total_h, 16):
        for x in range(0, total_w, 16):
            if ((x // 16) + (y // 16)) % 2 == 1:
                d.rectangle([x, y, x + 15, y + 15],
                            fill=(34, 26, 50, 255))

    # Headline
    try:
        font_h = ImageFont.truetype(
            '/usr/share/fonts/truetype/lato/Lato-Black.ttf', 22)
        font = ImageFont.truetype(
            '/usr/share/fonts/truetype/lato/Lato-Bold.ttf', 14)
    except OSError:
        font_h = ImageFont.load_default()
        font = ImageFont.load_default()
    d.text((pad, pad),
           'ELEMENTAL SKINS — original (top) vs alt (bottom)',
           font=font_h, fill=(245, 232, 196, 255))

    y_cursor = header_h + pad
    for clan in ['magenta', 'cyan', 'green', 'orange']:
        skin = CLAN_TO_SKIN[clan]
        # Original
        base = render_base_strip(clan)
        base_up = base.resize((sw, sh), Image.NEAREST)
        d.text((pad, y_cursor),
               f'{clan.upper()} — base', font=font,
               fill=(220, 220, 220, 255))
        bg.paste(base_up, (pad + 200, y_cursor), base_up)
        y_cursor += sh + pad // 2

        # Alt
        alt = render_skin_strip(clan, skin)
        alt_up = alt.resize((sw, sh), Image.NEAREST)
        d.text((pad, y_cursor),
               f'{clan.upper()} — {skin}', font=font,
               fill=(255, 232, 132, 255))
        bg.paste(alt_up, (pad + 200, y_cursor), alt_up)
        y_cursor += sh + pad * 2

    bg.save(f'{OUT_DIR}/ninja_skins_preview.png')
    print(f'Wrote ninja_skins_preview.png ({bg.size})')


if __name__ == '__main__':
    main()
    print(f'\nDone. Outputs in: {OUT_DIR}')
