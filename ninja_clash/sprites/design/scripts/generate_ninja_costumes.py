"""
NINJA COSTUME GENERATOR — alternate in-game outfits for the 4 clans.

Replaces the lightweight elemental-flair skins (deprecated; see
generate_ninja_skins.py) with completely different costumes a player
can pick during character select.

Each costume gets a 16x16 sprite strip with all 5 poses
(idle/walk1/walk2/jump/attack), rendered in all four clan tints
(cyan/magenta/orange/green). The clan tint applies to a costume-
specific primary fabric region; the rest of the costume keeps its
own iconic colors so each remains recognisable.

(Detailed character-pick portraits were tried but did not look good
enough; that code has been removed. Players see the 16x16 sprite
directly when cycling costumes.)

Six costumes for v1:

    CYBER     — neon cyberpunk shinobi (visor + clan-color pauldrons)
    EDO       — traditional straw-hat old-school ninja (kasa + kimono)
    VACATION  — beach ninja (backwards cap + sunglasses + Hawaiian shirt)
    OFFICE    — corporate ninja (suit + tie + briefcase mini)
    CHEF      — kitchen ninja (toque + chef coat + checkered pants)
    PIRATE    — swashbuckler ninja (bandana + eyepatch + striped shirt)

Outputs (transparent PNGs):

    sprites/ninjas/costumes/
        sprite_<costume>_<clan>_native_80x16.png
        sprite_<costume>_<clan>_4x_320x64.png
        sprite_<costume>_<clan>_8x_640x128.png
        costumes_sprite_grid.png   — all sprites in one preview
"""

import os
from PIL import Image, ImageDraw, ImageFont


# ============================================================
#  PATHS
# ============================================================
_BASH = '/sessions/gracious-determined-hamilton/mnt/ninja_clash'
_HOST = '/Users/a88/IdeaProjects/minu-mang/ninja_clash'
ROOT = _BASH if os.path.isdir(_BASH) else _HOST

COSTUMES_DIR = f'{ROOT}/sprites/ninjas/costumes'
os.makedirs(COSTUMES_DIR, exist_ok=True)


# ============================================================
#  CONFIG
# ============================================================
SPRITE = 16
POSES = ['idle', 'walk1', 'walk2', 'jump', 'attack']
SHEET_W = SPRITE * len(POSES)   # 80
SHEET_H = SPRITE                 # 16

TRANSPARENT = (0, 0, 0, 0)


# ============================================================
#  CLAN PALETTES (matches generate_ninjas.py exactly)
# ============================================================
PALETTES = {
    'cyan':    {'main': (80,  210, 230), 'hi': (170, 240, 250), 'shadow': (40,  120, 160)},
    'magenta': {'main': (235, 80,  175), 'hi': (255, 170, 215), 'shadow': (160, 40,  110)},
    'orange':  {'main': (255, 145, 50),  'hi': (255, 195, 130), 'shadow': (180, 90,  25)},
    'green':   {'main': (140, 220, 100), 'hi': (195, 245, 165), 'shadow': (70,  140, 55)},
}


# ============================================================
#  Drawing primitives
# ============================================================
def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def px(d, x, y, c):
    d.point((x, y), fill=rgba(c))


def rect(d, x1, y1, x2, y2, c):
    if x2 < x1 or y2 < y1:
        return
    d.rectangle([x1, y1, x2, y2], fill=rgba(c))


def line(d, x1, y1, x2, y2, c):
    d.line([(x1, y1), (x2, y2)], fill=rgba(c))


# ============================================================
#  Shared colors used by costume sprites
# ============================================================
SKIN_LIGHT  = (244, 220, 188)
SKIN_MID    = (212, 178, 144)
MASK_BLACK  = (20, 16, 30)
MASK_DARK   = (40, 32, 50)
EYE_GLOW    = (255, 240, 90)
HAIR_BLACK  = (24, 20, 32)
OUTLINE     = (16, 12, 22)

# Wood / leather
WOOD_DK     = (54, 32, 18)
WOOD_MD     = (98, 60, 30)
WOOD_HI     = (140, 92, 46)
LEATHER_DK  = (60, 38, 22)
GOLD        = (220, 168, 60)

# Metal / cyber
STEEL_HI    = (220, 222, 235)
STEEL       = (165, 168, 188)
STEEL_DK    = (90, 94, 116)
STEEL_BLK   = (38, 40, 56)
NEON_CYAN   = (110, 250, 255)
NEON_MAG    = (255, 80, 200)
EYE_WHITE   = (245, 240, 220)

# Vacation
HAWAII_LEAF  = (60, 142, 76)
HAWAII_FLOWER = (255, 110, 130)
SHADES_DK   = (28, 22, 32)
SHADES_LENS = (50, 70, 100)

# Office
SUIT_NAVY    = (38, 46, 80)
SUIT_NAVY_HI = (76, 90, 130)
SHIRT_WHITE  = (240, 238, 230)
BRIEFCASE    = (78, 50, 28)

# Chef
CHEF_WHITE   = (250, 246, 230)
CHEF_WHITE_DK = (200, 196, 180)
CHEF_PANTS   = (60, 56, 70)
CHEF_PANTS_HI = (180, 178, 196)

# Pirate
BANDANA_RED    = (188, 38, 40)
BANDANA_RED_HI = (228, 78, 70)
STRIPE_WHITE   = (242, 234, 218)
STRIPE_RED     = (190, 60, 60)
VEST_BLACK     = (32, 26, 38)
EYEPATCH_BLACK = (16, 12, 18)

# Edo
STRAW_LIGHT  = (228, 196, 132)
STRAW_MID    = (188, 154, 92)
STRAW_DK     = (130, 100, 56)
KIMONO_DK    = (40, 36, 56)
KIMONO_TRIM  = (210, 190, 140)
SCROLL_PAPER = (236, 218, 168)
SCROLL_SHAD  = (180, 156, 108)


# ============================================================
#  COSTUME 1 — CYBER (cyberpunk)
# ============================================================
def sprite_cyber(d, palette, ox, oy, pose):
    """16x16 cyber sprite — black bodysuit with clan-color pauldrons,
       full horizontal cyan visor across eyes, antenna on top."""
    M, H, S = palette['main'], palette['hi'], palette['shadow']
    head_dy = -1 if pose == 'jump' else 0
    body_y = 5 if pose == 'jump' else 6

    if oy + head_dy >= 0:
        px(d, ox + 8, oy + head_dy, STEEL)
        px(d, ox + 8, oy + 1 + head_dy, NEON_MAG)

    rect(d, ox + 4, oy + 2 + head_dy, ox + 11, oy + 2 + head_dy, STEEL_BLK)
    rect(d, ox + 3, oy + 3 + head_dy, ox + 12, oy + 5 + head_dy, STEEL_BLK)
    px(d, ox + 4, oy + 2 + head_dy, M)
    px(d, ox + 11, oy + 2 + head_dy, M)
    px(d, ox + 3, oy + 5 + head_dy, M)
    px(d, ox + 12, oy + 5 + head_dy, M)
    rect(d, ox + 4, oy + 3 + head_dy, ox + 11, oy + 4 + head_dy, NEON_CYAN)
    px(d, ox + 6, oy + 3 + head_dy, EYE_WHITE)
    px(d, ox + 9, oy + 3 + head_dy, EYE_WHITE)

    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, STEEL_BLK)
    rect(d, ox + 3, by, ox + 3, by + 1, M)
    rect(d, ox + 12, by, ox + 12, by + 1, M)
    px(d, ox + 7, by + 1, M)
    px(d, ox + 8, by + 1, NEON_CYAN)
    line(d, ox + 4, by + 2, ox + 11, by + 2, GOLD)

    if pose == 'idle':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, STEEL_BLK)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 12, STEEL_BLK)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, STEEL_DK)
        rect(d, ox + 9, oy + 13, ox + 11, oy + 13, STEEL_DK)
        px(d, ox + 5, oy + 13, NEON_CYAN)
        px(d, ox + 10, oy + 13, NEON_CYAN)
    elif pose == 'walk1':
        rect(d, ox + 3, oy + 10, ox + 5, oy + 12, STEEL_BLK)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 13, STEEL_BLK)
        rect(d, ox + 3, oy + 13, ox + 5, oy + 13, STEEL_DK)
        rect(d, ox + 9, oy + 14, ox + 11, oy + 14, STEEL_DK)
    elif pose == 'walk2':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 13, STEEL_BLK)
        rect(d, ox + 10, oy + 10, ox + 12, oy + 12, STEEL_BLK)
        rect(d, ox + 4, oy + 14, ox + 6, oy + 14, STEEL_DK)
        rect(d, ox + 10, oy + 13, ox + 12, oy + 13, STEEL_DK)
    elif pose == 'jump':
        rect(d, ox + 4, oy + 9, ox + 6, oy + 11, STEEL_BLK)
        rect(d, ox + 9, oy + 9, ox + 11, oy + 11, STEEL_BLK)
        rect(d, ox + 5, oy + 12, ox + 6, oy + 12, STEEL_DK)
        rect(d, ox + 9, oy + 12, ox + 10, oy + 12, STEEL_DK)
        rect(d, ox + 13, by, ox + 13, by + 2, NEON_CYAN)
    else:   # attack
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, STEEL_BLK)
        rect(d, ox + 8, oy + 11, ox + 11, oy + 12, STEEL_BLK)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, STEEL_DK)
        rect(d, ox + 8, oy + 13, ox + 11, oy + 13, STEEL_DK)
        rect(d, ox + 13, oy + 7, ox + 14, oy + 8, STEEL)
        px(d, ox + 15, oy + 7, NEON_CYAN)
        px(d, ox + 15, oy + 8, EYE_WHITE)


# ============================================================
#  COSTUME 2 — EDO (traditional)
# ============================================================
def sprite_edo(d, palette, ox, oy, pose):
    """16x16 edo sprite — wide kasa straw hat, dark kimono, clan obi."""
    M, H, S = palette['main'], palette['hi'], palette['shadow']
    head_dy = -1 if pose == 'jump' else 0
    body_y = 5 if pose == 'jump' else 6

    hat_top = oy + 1 + head_dy
    if hat_top >= 0:
        rect(d, ox + 5, hat_top, ox + 10, hat_top + 1, STRAW_LIGHT)
        rect(d, ox + 2, hat_top + 2, ox + 13, hat_top + 2, STRAW_MID)
        rect(d, ox + 1, hat_top + 3, ox + 14, hat_top + 3, STRAW_DK)
        px(d, ox + 7, hat_top, STRAW_LIGHT)
        px(d, ox + 8, hat_top, STRAW_LIGHT)
    rect(d, ox + 5, oy + 4 + head_dy, ox + 10, oy + 5 + head_dy, MASK_BLACK)
    px(d, ox + 6, oy + 4 + head_dy, EYE_GLOW)
    px(d, ox + 9, oy + 4 + head_dy, EYE_GLOW)

    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, KIMONO_DK)
    rect(d, ox + 3, by, ox + 3, by + 3, KIMONO_TRIM)
    rect(d, ox + 4, by + 2, ox + 11, by + 2, M)
    px(d, ox + 7, by + 2, S)

    if pose == 'idle':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, KIMONO_DK)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 12, KIMONO_DK)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, WOOD_DK)
        rect(d, ox + 9, oy + 13, ox + 11, oy + 13, WOOD_DK)
    elif pose == 'walk1':
        rect(d, ox + 3, oy + 10, ox + 5, oy + 12, KIMONO_DK)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 13, KIMONO_DK)
        rect(d, ox + 3, oy + 13, ox + 5, oy + 13, WOOD_DK)
        rect(d, ox + 9, oy + 14, ox + 11, oy + 14, WOOD_DK)
    elif pose == 'walk2':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 13, KIMONO_DK)
        rect(d, ox + 10, oy + 10, ox + 12, oy + 12, KIMONO_DK)
        rect(d, ox + 4, oy + 14, ox + 6, oy + 14, WOOD_DK)
        rect(d, ox + 10, oy + 13, ox + 12, oy + 13, WOOD_DK)
    elif pose == 'jump':
        rect(d, ox + 4, oy + 9, ox + 6, oy + 11, KIMONO_DK)
        rect(d, ox + 9, oy + 9, ox + 11, oy + 11, KIMONO_DK)
        rect(d, ox + 5, oy + 12, ox + 6, oy + 12, WOOD_DK)
        rect(d, ox + 9, oy + 12, ox + 10, oy + 12, WOOD_DK)
    else:
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, KIMONO_DK)
        rect(d, ox + 8, oy + 11, ox + 11, oy + 12, KIMONO_DK)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, WOOD_DK)
        rect(d, ox + 8, oy + 13, ox + 11, oy + 13, WOOD_DK)
        rect(d, ox + 13, oy + 7, ox + 14, oy + 8, SCROLL_PAPER)
        px(d, ox + 15, oy + 7, SCROLL_SHAD)


# ============================================================
#  COSTUME 3 — VACATION (beach)
# ============================================================
def sprite_vacation(d, palette, ox, oy, pose):
    """16x16 vacation sprite — backwards cap, sunglasses, Hawaiian shirt."""
    M, H, S = palette['main'], palette['hi'], palette['shadow']
    head_dy = -1 if pose == 'jump' else 0
    body_y = 5 if pose == 'jump' else 6

    rect(d, ox + 4, oy + 1 + head_dy, ox + 11, oy + 2 + head_dy, M)
    px(d, ox + 4, oy + 2 + head_dy, H)
    px(d, ox + 12, oy + 2 + head_dy, M)
    px(d, ox + 13, oy + 2 + head_dy, S)
    rect(d, ox + 5, oy + 3 + head_dy, ox + 10, oy + 5 + head_dy, SKIN_LIGHT)
    rect(d, ox + 5, oy + 3 + head_dy, ox + 10, oy + 4 + head_dy, SHADES_DK)
    px(d, ox + 6, oy + 4 + head_dy, SHADES_LENS)
    px(d, ox + 9, oy + 4 + head_dy, SHADES_LENS)
    px(d, ox + 7, oy + 5 + head_dy, MASK_DARK)
    px(d, ox + 8, oy + 5 + head_dy, MASK_DARK)

    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, M)
    rect(d, ox + 3, by, ox + 3, by + 3, H)
    rect(d, ox + 12, by, ox + 12, by + 3, S)
    px(d, ox + 7, by, SKIN_MID)
    px(d, ox + 8, by, SKIN_MID)
    px(d, ox + 7, by + 1, SKIN_MID)
    px(d, ox + 8, by + 1, SKIN_MID)
    px(d, ox + 5, by + 2, HAWAII_LEAF)
    px(d, ox + 10, by + 2, HAWAII_LEAF)
    px(d, ox + 11, by, HAWAII_FLOWER)

    SHORT_RED = (220, 60, 60)
    if pose == 'idle':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 11, SHORT_RED)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 11, SHORT_RED)
        rect(d, ox + 4, oy + 12, ox + 6, oy + 13, SKIN_MID)
        rect(d, ox + 9, oy + 12, ox + 11, oy + 13, SKIN_MID)
    elif pose == 'walk1':
        rect(d, ox + 3, oy + 10, ox + 5, oy + 11, SHORT_RED)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 11, SHORT_RED)
        rect(d, ox + 3, oy + 12, ox + 5, oy + 13, SKIN_MID)
        rect(d, ox + 9, oy + 12, ox + 11, oy + 14, SKIN_MID)
    elif pose == 'walk2':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 11, SHORT_RED)
        rect(d, ox + 10, oy + 10, ox + 12, oy + 11, SHORT_RED)
        rect(d, ox + 4, oy + 12, ox + 6, oy + 14, SKIN_MID)
        rect(d, ox + 10, oy + 12, ox + 12, oy + 13, SKIN_MID)
    elif pose == 'jump':
        rect(d, ox + 4, oy + 9, ox + 6, oy + 10, SHORT_RED)
        rect(d, ox + 9, oy + 9, ox + 11, oy + 10, SHORT_RED)
        rect(d, ox + 5, oy + 11, ox + 6, oy + 12, SKIN_MID)
        rect(d, ox + 9, oy + 11, ox + 10, oy + 12, SKIN_MID)
    else:   # attack — coconut throw!
        rect(d, ox + 4, oy + 10, ox + 6, oy + 11, SHORT_RED)
        rect(d, ox + 8, oy + 11, ox + 11, oy + 11, SHORT_RED)
        rect(d, ox + 4, oy + 12, ox + 6, oy + 13, SKIN_MID)
        rect(d, ox + 8, oy + 12, ox + 11, oy + 13, SKIN_MID)
        px(d, ox + 14, oy + 7, (110, 70, 38))
        px(d, ox + 15, oy + 7, (110, 70, 38))
        px(d, ox + 14, oy + 8, (60, 36, 18))


# ============================================================
#  COSTUME 4 — OFFICE (corporate)
# ============================================================
def sprite_office(d, palette, ox, oy, pose):
    """16x16 office sprite — navy suit, white shirt V, clan-color tie."""
    M, H, S = palette['main'], palette['hi'], palette['shadow']
    head_dy = -1 if pose == 'jump' else 0
    body_y = 5 if pose == 'jump' else 6

    rect(d, ox + 5, oy + 1 + head_dy, ox + 10, oy + 1 + head_dy, HAIR_BLACK)
    rect(d, ox + 4, oy + 2 + head_dy, ox + 11, oy + 2 + head_dy, HAIR_BLACK)
    rect(d, ox + 5, oy + 3 + head_dy, ox + 10, oy + 5 + head_dy, SKIN_LIGHT)
    px(d, ox + 6, oy + 4 + head_dy, OUTLINE)
    px(d, ox + 9, oy + 4 + head_dy, OUTLINE)
    px(d, ox + 7, oy + 5 + head_dy, MASK_DARK)
    px(d, ox + 8, oy + 5 + head_dy, MASK_DARK)

    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, SUIT_NAVY)
    rect(d, ox + 3, by, ox + 3, by + 3, SUIT_NAVY_HI)
    px(d, ox + 7, by, SHIRT_WHITE)
    px(d, ox + 8, by, SHIRT_WHITE)
    px(d, ox + 7, by + 1, M)
    px(d, ox + 8, by + 1, M)
    px(d, ox + 8, by + 2, M)
    px(d, ox + 7, by + 2, S)

    if pose == 'idle':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, SUIT_NAVY)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 12, SUIT_NAVY)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, OUTLINE)
        rect(d, ox + 9, oy + 13, ox + 11, oy + 13, OUTLINE)
    elif pose == 'walk1':
        rect(d, ox + 3, oy + 10, ox + 5, oy + 12, SUIT_NAVY)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 13, SUIT_NAVY)
        rect(d, ox + 3, oy + 13, ox + 5, oy + 13, OUTLINE)
        rect(d, ox + 9, oy + 14, ox + 11, oy + 14, OUTLINE)
    elif pose == 'walk2':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 13, SUIT_NAVY)
        rect(d, ox + 10, oy + 10, ox + 12, oy + 12, SUIT_NAVY)
        rect(d, ox + 4, oy + 14, ox + 6, oy + 14, OUTLINE)
        rect(d, ox + 10, oy + 13, ox + 12, oy + 13, OUTLINE)
    elif pose == 'jump':
        rect(d, ox + 4, oy + 9, ox + 6, oy + 11, SUIT_NAVY)
        rect(d, ox + 9, oy + 9, ox + 11, oy + 11, SUIT_NAVY)
        rect(d, ox + 5, oy + 12, ox + 6, oy + 12, OUTLINE)
        rect(d, ox + 9, oy + 12, ox + 10, oy + 12, OUTLINE)
    else:
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, SUIT_NAVY)
        rect(d, ox + 8, oy + 11, ox + 11, oy + 12, SUIT_NAVY)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, OUTLINE)
        rect(d, ox + 8, oy + 13, ox + 11, oy + 13, OUTLINE)
        rect(d, ox + 13, oy + 7, ox + 14, oy + 8, BRIEFCASE)
        px(d, ox + 15, oy + 7, GOLD)


# ============================================================
#  COSTUME 5 — CHEF
# ============================================================
def sprite_chef(d, palette, ox, oy, pose):
    """16x16 chef sprite — tall white toque, chef coat, clan scarf."""
    M, H, S = palette['main'], palette['hi'], palette['shadow']
    head_dy = -1 if pose == 'jump' else 0
    body_y = 5 if pose == 'jump' else 6

    if oy + head_dy >= 0:
        rect(d, ox + 5, oy + head_dy, ox + 10, oy + head_dy, CHEF_WHITE)
    rect(d, ox + 4, oy + 1 + head_dy, ox + 11, oy + 2 + head_dy, CHEF_WHITE)
    line(d, ox + 4, oy + 2 + head_dy, ox + 11, oy + 2 + head_dy, CHEF_WHITE_DK)
    rect(d, ox + 5, oy + 3 + head_dy, ox + 10, oy + 5 + head_dy, SKIN_LIGHT)
    px(d, ox + 6, oy + 4 + head_dy, OUTLINE)
    px(d, ox + 9, oy + 4 + head_dy, OUTLINE)
    rect(d, ox + 5, oy + 5 + head_dy, ox + 10, oy + 5 + head_dy, HAIR_BLACK)

    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, CHEF_WHITE)
    rect(d, ox + 3, by, ox + 3, by + 3, CHEF_WHITE_DK)
    rect(d, ox + 4, by, ox + 11, by, M)
    px(d, ox + 7, by, S)
    px(d, ox + 6, by + 1, CHEF_WHITE_DK)
    px(d, ox + 9, by + 1, CHEF_WHITE_DK)
    px(d, ox + 6, by + 2, CHEF_WHITE_DK)
    px(d, ox + 9, by + 2, CHEF_WHITE_DK)

    def checker_legs(x_range, y_range):
        for lx in x_range:
            for ly in y_range:
                color = CHEF_PANTS if (lx + ly) % 2 == 0 else CHEF_PANTS_HI
                px(d, ox + lx, oy + ly, color)

    if pose == 'idle':
        checker_legs(range(4, 7), range(10, 13))
        checker_legs(range(9, 12), range(10, 13))
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, OUTLINE)
        rect(d, ox + 9, oy + 13, ox + 11, oy + 13, OUTLINE)
    elif pose == 'walk1':
        checker_legs(range(3, 6), range(10, 13))
        checker_legs(range(9, 12), range(10, 14))
        rect(d, ox + 3, oy + 13, ox + 5, oy + 13, OUTLINE)
        rect(d, ox + 9, oy + 14, ox + 11, oy + 14, OUTLINE)
    elif pose == 'walk2':
        checker_legs(range(4, 7), range(10, 14))
        checker_legs(range(10, 13), range(10, 13))
        rect(d, ox + 4, oy + 14, ox + 6, oy + 14, OUTLINE)
        rect(d, ox + 10, oy + 13, ox + 12, oy + 13, OUTLINE)
    elif pose == 'jump':
        checker_legs(range(4, 7), range(9, 12))
        checker_legs(range(9, 12), range(9, 12))
        rect(d, ox + 5, oy + 12, ox + 6, oy + 12, OUTLINE)
        rect(d, ox + 9, oy + 12, ox + 10, oy + 12, OUTLINE)
    else:
        checker_legs(range(4, 7), range(10, 13))
        checker_legs(range(8, 12), range(11, 13))
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, OUTLINE)
        rect(d, ox + 8, oy + 13, ox + 11, oy + 13, OUTLINE)
        px(d, ox + 13, oy + 7, STEEL_HI)
        px(d, ox + 14, oy + 7, STEEL)
        px(d, ox + 15, oy + 7, STEEL_HI)


# ============================================================
#  COSTUME 6 — PIRATE
# ============================================================
def sprite_pirate(d, palette, ox, oy, pose):
    """16x16 pirate sprite — red bandana with clan knot, eyepatch,
       striped shirt under black vest."""
    M, H, S = palette['main'], palette['hi'], palette['shadow']
    head_dy = -1 if pose == 'jump' else 0
    body_y = 5 if pose == 'jump' else 6

    rect(d, ox + 4, oy + 1 + head_dy, ox + 11, oy + 2 + head_dy, BANDANA_RED)
    px(d, ox + 4, oy + 1 + head_dy, BANDANA_RED_HI)
    px(d, ox + 11, oy + 2 + head_dy, M)
    px(d, ox + 7, oy + 1 + head_dy, STRIPE_WHITE)
    px(d, ox + 8, oy + 1 + head_dy, STRIPE_WHITE)
    rect(d, ox + 5, oy + 3 + head_dy, ox + 10, oy + 5 + head_dy, SKIN_LIGHT)
    px(d, ox + 6, oy + 3 + head_dy, EYEPATCH_BLACK)
    px(d, ox + 6, oy + 4 + head_dy, EYEPATCH_BLACK)
    px(d, ox + 9, oy + 4 + head_dy, OUTLINE)
    px(d, ox + 7, oy + 5 + head_dy, HAIR_BLACK)
    px(d, ox + 8, oy + 5 + head_dy, HAIR_BLACK)

    by = oy + body_y
    rect(d, ox + 3, by, ox + 12, by + 3, STRIPE_WHITE)
    rect(d, ox + 3, by, ox + 12, by, STRIPE_RED)
    rect(d, ox + 3, by + 2, ox + 12, by + 2, STRIPE_RED)
    rect(d, ox + 3, by, ox + 4, by + 3, VEST_BLACK)
    rect(d, ox + 11, by, ox + 12, by + 3, VEST_BLACK)
    px(d, ox + 7, by + 3, GOLD)
    px(d, ox + 8, by + 3, GOLD)

    if pose == 'idle':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, VEST_BLACK)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 12, VEST_BLACK)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, LEATHER_DK)
        rect(d, ox + 9, oy + 13, ox + 11, oy + 13, LEATHER_DK)
    elif pose == 'walk1':
        rect(d, ox + 3, oy + 10, ox + 5, oy + 12, VEST_BLACK)
        rect(d, ox + 9, oy + 10, ox + 11, oy + 13, VEST_BLACK)
        rect(d, ox + 3, oy + 13, ox + 5, oy + 13, LEATHER_DK)
        rect(d, ox + 9, oy + 14, ox + 11, oy + 14, LEATHER_DK)
    elif pose == 'walk2':
        rect(d, ox + 4, oy + 10, ox + 6, oy + 13, VEST_BLACK)
        rect(d, ox + 10, oy + 10, ox + 12, oy + 12, VEST_BLACK)
        rect(d, ox + 4, oy + 14, ox + 6, oy + 14, LEATHER_DK)
        rect(d, ox + 10, oy + 13, ox + 12, oy + 13, LEATHER_DK)
    elif pose == 'jump':
        rect(d, ox + 4, oy + 9, ox + 6, oy + 11, VEST_BLACK)
        rect(d, ox + 9, oy + 9, ox + 11, oy + 11, VEST_BLACK)
        rect(d, ox + 5, oy + 12, ox + 6, oy + 12, LEATHER_DK)
        rect(d, ox + 9, oy + 12, ox + 10, oy + 12, LEATHER_DK)
    else:
        rect(d, ox + 4, oy + 10, ox + 6, oy + 12, VEST_BLACK)
        rect(d, ox + 8, oy + 11, ox + 11, oy + 12, VEST_BLACK)
        rect(d, ox + 4, oy + 13, ox + 6, oy + 13, LEATHER_DK)
        rect(d, ox + 8, oy + 13, ox + 11, oy + 13, LEATHER_DK)
        rect(d, ox + 13, oy + 6, ox + 15, oy + 6, STEEL_HI)
        rect(d, ox + 14, oy + 7, ox + 15, oy + 7, STEEL)
        px(d, ox + 13, oy + 7, GOLD)


# ============================================================
#  COSTUME REGISTRY
# ============================================================
COSTUMES = {
    'cyber':    {'sprite': sprite_cyber,    'label': 'CYBER'},
    'edo':      {'sprite': sprite_edo,      'label': 'EDO'},
    'vacation': {'sprite': sprite_vacation, 'label': 'VACATION'},
    'office':   {'sprite': sprite_office,   'label': 'OFFICE'},
    'chef':     {'sprite': sprite_chef,     'label': 'CHEF'},
    'pirate':   {'sprite': sprite_pirate,   'label': 'PIRATE'},
}


# ============================================================
#  Render
# ============================================================
def render_sprite_strip(costume_id, clan):
    palette = PALETTES[clan]
    img = Image.new('RGBA', (SHEET_W, SHEET_H), TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, pose in enumerate(POSES):
        COSTUMES[costume_id]['sprite'](d, palette, i * SPRITE, 0, pose)
    return img


# ============================================================
#  Main
# ============================================================
def main():
    print('=== NINJA COSTUMES (sprite strips only) ===')
    for cid in COSTUMES:
        for clan in PALETTES:
            strip = render_sprite_strip(cid, clan)
            strip.save(
                f'{COSTUMES_DIR}/sprite_{cid}_{clan}_native_80x16.png')
            strip.resize((SHEET_W * 4, SHEET_H * 4),
                         Image.NEAREST).save(
                f'{COSTUMES_DIR}/sprite_{cid}_{clan}_4x_320x64.png')
            strip.resize((SHEET_W * 8, SHEET_H * 8),
                         Image.NEAREST).save(
                f'{COSTUMES_DIR}/sprite_{cid}_{clan}_8x_640x128.png')
        print(f'  {cid:<10} × 4 clans  (sprite strip native+4x+8x)')

    print('\nBuilding preview grid...')
    _build_sprite_grid()
    print('Done.')


def _build_sprite_grid():
    """All 6 costumes × 4 clans, sprite strips at 8x."""
    pad = 24
    scale = 8
    sw = SHEET_W * scale
    sh = SHEET_H * scale
    cols = len(PALETTES)
    rows = len(COSTUMES)
    label_w = 200
    col_pad = 24
    row_pad = 18
    W = pad * 2 + label_w + sw * cols + col_pad * (cols - 1)
    H = pad * 2 + 60 + (sh + row_pad) * rows + row_pad

    bg = Image.new('RGBA', (W, H), (20, 16, 32, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, H, 16):
        for x in range(0, W, 16):
            if ((x // 16) + (y // 16)) % 2 == 1:
                d.rectangle([x, y, x + 15, y + 15], fill=(30, 24, 44, 255))
    try:
        f_title = ImageFont.truetype(
            '/usr/share/fonts/truetype/lato/Lato-Black.ttf', 26)
        f_label = ImageFont.truetype(
            '/usr/share/fonts/truetype/lato/Lato-Black.ttf', 16)
        f_clan = ImageFont.truetype(
            '/usr/share/fonts/truetype/lato/Lato-Black.ttf', 14)
    except OSError:
        f_title = f_label = f_clan = ImageFont.load_default()
    d.text((pad, pad),
           'NINJA COSTUMES — in-game 16x16 sprite strips  (8× preview, 5 poses each)',
           font=f_title, fill=(245, 232, 196, 255))
    clan_labels = {'cyan': 'STORM', 'magenta': 'SHADOW',
                   'green': 'FROST', 'orange': 'FIRE'}
    clan_colors_disp = {'cyan': (80, 210, 230), 'magenta': (235, 80, 175),
                        'green': (140, 220, 100), 'orange': (255, 145, 50)}
    header_y = pad + 36
    for i, clan in enumerate(PALETTES):
        cx = pad + label_w + i * (sw + col_pad) + sw // 2
        text = clan_labels[clan]
        bb = f_clan.getbbox(text)
        d.text((cx - (bb[2] - bb[0]) // 2, header_y),
               text, font=f_clan, fill=clan_colors_disp[clan] + (255,))
    y_cursor = pad + 60
    for cid, cdata in COSTUMES.items():
        d.text((pad, y_cursor + sh // 2 - 6),
               cdata['label'], font=f_label,
               fill=(255, 232, 132, 255))
        for i, clan in enumerate(PALETTES):
            x = pad + label_w + i * (sw + col_pad)
            strip = render_sprite_strip(cid, clan)
            up = strip.resize((sw, sh), Image.NEAREST)
            bg.paste(up, (x, y_cursor), up)
        y_cursor += sh + row_pad

    bg.save(f'{COSTUMES_DIR}/costumes_sprite_grid.png')
    print(f'  costumes_sprite_grid.png ({W}x{H})')


if __name__ == '__main__':
    main()
    print(f'\nOutputs: {COSTUMES_DIR}')
