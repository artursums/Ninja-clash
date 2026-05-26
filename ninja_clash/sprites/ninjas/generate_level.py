"""
Generate a TowerFall-inspired dark dungeon level background.
Native resolution: 320x240 (4:3, chunky pixels).
Output: upscaled 4x nearest-neighbor to 1280x960 PNG.
"""

from PIL import Image, ImageDraw
import random

# ---- canvas ----
W, H = 320, 240
TILE = 10
COLS = W // TILE   # 32
ROWS = H // TILE   # 24

# ---- palette (dark dungeon / catacomb) ----
BG_TOP        = (10, 6, 20)
BG_MID        = (28, 16, 42)
BG_BOT        = (44, 24, 58)
STONE         = (78, 68, 92)
STONE_LIGHT   = (118, 102, 138)
STONE_HI      = (148, 130, 168)
STONE_DARK    = (44, 36, 56)
STONE_VDARK   = (26, 20, 34)
MORTAR        = (18, 12, 28)
MOSS          = (74, 122, 78)
MOSS_DARK     = (44, 78, 50)
MOSS_HI       = (130, 180, 110)
TORCH_BRACKET = (60, 40, 26)
TORCH_BRACKET_HI = (96, 66, 38)
FLAME_OUT     = (200, 60, 18)
FLAME_MID     = (255, 142, 28)
FLAME_IN      = (255, 232, 88)
FLAME_CORE    = (255, 252, 200)
CHAIN_LIGHT   = (158, 158, 172)
CHAIN_DARK    = (76, 76, 92)
CHAIN_HI      = (200, 200, 214)
SKULL         = (220, 212, 188)
SKULL_SHADE   = (160, 150, 128)
SKULL_EYE     = (20, 12, 24)
CHEST_WOOD    = (118, 78, 42)
CHEST_WOOD_HI = (160, 110, 64)
CHEST_DARK    = (70, 44, 22)
CHEST_GOLD    = (220, 168, 60)
CHEST_GOLD_HI = (255, 220, 110)
RUNE          = (78, 124, 124)
FOG           = (60, 38, 72)

random.seed(1337)
img = Image.new('RGB', (W, H), BG_TOP)
d = ImageDraw.Draw(img)


# ============================================================
#  Background: vertical gradient + faint stars/dust
# ============================================================
def draw_bg():
    for y in range(H):
        if y < H * 0.55:
            t = y / (H * 0.55)
            r = int(BG_TOP[0] + (BG_MID[0]-BG_TOP[0])*t)
            g = int(BG_TOP[1] + (BG_MID[1]-BG_TOP[1])*t)
            b = int(BG_TOP[2] + (BG_MID[2]-BG_TOP[2])*t)
        else:
            t = (y - H*0.55) / (H*0.45)
            r = int(BG_MID[0] + (BG_BOT[0]-BG_MID[0])*t)
            g = int(BG_MID[1] + (BG_BOT[1]-BG_MID[1])*t)
            b = int(BG_MID[2] + (BG_BOT[2]-BG_MID[2])*t)
        d.line([(0, y), (W-1, y)], fill=(r, g, b))

    # specks of dust / faint particles
    for _ in range(80):
        x = random.randint(0, W-1)
        y = random.randint(0, H-1)
        v = random.choice([(70,55,90),(90,72,110),(50,40,70)])
        d.point((x, y), fill=v)

    # subtle horizontal fog band near bottom
    for y in range(int(H*0.78), H):
        for x in range(W):
            if random.random() < 0.06:
                d.point((x, y), fill=FOG)


# ============================================================
#  Stone tile primitives
# ============================================================
def stone_tile(x, y, mossy_top=False, has_rune=False, variant=0):
    """A 10x10 stone block with brick pattern + edge highlight + shadow."""
    # base
    d.rectangle([x, y, x+TILE-1, y+TILE-1], fill=STONE)

    # subtle internal variation (noise)
    for _ in range(3):
        nx = x + random.randint(1, TILE-2)
        ny = y + random.randint(1, TILE-2)
        d.point((nx, ny), fill=STONE_DARK)
    for _ in range(2):
        nx = x + random.randint(1, TILE-2)
        ny = y + random.randint(1, TILE-2)
        d.point((nx, ny), fill=STONE_LIGHT)

    # brick mortar — horizontal mid line
    d.line([(x, y+5), (x+TILE-1, y+5)], fill=MORTAR)

    # vertical mortar — offset every other row
    row_idx = y // TILE
    if row_idx % 2 == 0:
        # upper half mortar at x+5
        d.line([(x+5, y), (x+5, y+4)], fill=MORTAR)
    else:
        # lower half mortar at x+5
        d.line([(x+5, y+6), (x+5, y+TILE-1)], fill=MORTAR)

    # edge highlight on top + left
    d.line([(x, y), (x+TILE-1, y)], fill=STONE_LIGHT)
    d.line([(x, y), (x, y+TILE-1)], fill=STONE_LIGHT)
    # bottom + right shadow
    d.line([(x, y+TILE-1), (x+TILE-1, y+TILE-1)], fill=STONE_VDARK)
    d.line([(x+TILE-1, y), (x+TILE-1, y+TILE-1)], fill=STONE_VDARK)

    if has_rune:
        # tiny faint green-cyan rune mark
        d.point((x+3, y+2), fill=RUNE)
        d.point((x+4, y+2), fill=RUNE)
        d.point((x+3, y+3), fill=RUNE)
        d.point((x+6, y+7), fill=RUNE)
        d.point((x+7, y+7), fill=RUNE)
        d.point((x+6, y+8), fill=RUNE)

    if mossy_top:
        # moss creeping along top edge
        pattern = [(1,0),(2,0),(3,0),(5,0),(6,0),(8,0),
                   (1,1),(3,1),(5,1),(7,1),(8,1)]
        for dx, dy in pattern:
            if random.random() < 0.85:
                d.point((x+dx, y+dy), fill=MOSS)
        for dx, dy in [(2,1),(4,1),(6,1),(7,2)]:
            if random.random() < 0.5:
                d.point((x+dx, y+dy), fill=MOSS_DARK)
        for dx, dy in [(3,0),(6,0)]:
            if random.random() < 0.5:
                d.point((x+dx, y+dy), fill=MOSS_HI)


def platform_top_tile(x, y, mossy=True):
    """Top tile of a floating platform — brighter cap on top."""
    d.rectangle([x, y, x+TILE-1, y+TILE-1], fill=STONE)
    # bright cap
    d.rectangle([x, y, x+TILE-1, y+1], fill=STONE_HI)
    # mortar
    d.line([(x, y+6), (x+TILE-1, y+6)], fill=MORTAR)
    row_idx = y // TILE
    if row_idx % 2 == 0:
        d.line([(x+5, y+2), (x+5, y+5)], fill=MORTAR)
    else:
        d.line([(x+5, y+7), (x+5, y+TILE-1)], fill=MORTAR)
    # edges
    d.line([(x, y), (x, y+TILE-1)], fill=STONE_LIGHT)
    d.line([(x+TILE-1, y), (x+TILE-1, y+TILE-1)], fill=STONE_VDARK)
    # bottom shadow
    d.line([(x, y+TILE-1), (x+TILE-1, y+TILE-1)], fill=STONE_VDARK)
    # noise
    for _ in range(2):
        nx = x + random.randint(1, TILE-2)
        ny = y + random.randint(3, TILE-3)
        d.point((nx, ny), fill=STONE_DARK)
    if mossy:
        # tiny moss tufts hanging off
        for dx, dy in [(1,2),(3,2),(6,2),(8,2)]:
            if random.random() < 0.55:
                d.point((x+dx, y+dy), fill=MOSS)


def platform_body_tile(x, y):
    """Underside of a floating platform — darker, more shadowed."""
    d.rectangle([x, y, x+TILE-1, y+TILE-1], fill=STONE_DARK)
    # mortar
    d.line([(x, y+5), (x+TILE-1, y+5)], fill=MORTAR)
    row_idx = y // TILE
    if row_idx % 2 == 0:
        d.line([(x+5, y), (x+5, y+4)], fill=MORTAR)
    else:
        d.line([(x+5, y+6), (x+5, y+TILE-1)], fill=MORTAR)
    d.line([(x, y), (x, y+TILE-1)], fill=STONE)
    d.line([(x+TILE-1, y), (x+TILE-1, y+TILE-1)], fill=STONE_VDARK)
    d.line([(x, y+TILE-1), (x+TILE-1, y+TILE-1)], fill=STONE_VDARK)


# ============================================================
#  Decorative sprites — drawn over tile grid
# ============================================================
def draw_chain(top_x, top_y, length_px):
    """Vertical hanging chain ending in a small weight/lantern."""
    # links: every 3 px alternate horizontal and vertical oval
    for i in range(length_px // 3):
        cy = top_y + i*3
        if cy >= top_y + length_px:
            break
        if i % 2 == 0:
            # horizontal link
            d.point((top_x, cy), fill=CHAIN_DARK)
            d.point((top_x-1, cy), fill=CHAIN_LIGHT)
            d.point((top_x+1, cy), fill=CHAIN_LIGHT)
            d.point((top_x, cy+1), fill=CHAIN_DARK)
        else:
            # vertical link
            d.point((top_x, cy), fill=CHAIN_LIGHT)
            d.point((top_x, cy+1), fill=CHAIN_HI)
            d.point((top_x, cy+2), fill=CHAIN_DARK)

    # weight at the bottom
    bx, by = top_x, top_y + length_px
    d.rectangle([bx-2, by, bx+2, by+3], fill=CHAIN_DARK)
    d.line([(bx-2, by), (bx+2, by)], fill=CHAIN_LIGHT)
    d.point((bx-1, by+1), fill=CHAIN_HI)
    d.line([(bx-2, by+3), (bx+2, by+3)], fill=STONE_VDARK)


def draw_torch(cx, cy, flame_size=5):
    """Wall torch: small bracket + flickering flame above it.
       cx, cy = top center pixel where the bracket sits."""
    # bracket
    d.rectangle([cx-1, cy, cx+1, cy+2], fill=TORCH_BRACKET)
    d.point((cx-1, cy), fill=TORCH_BRACKET_HI)
    d.point((cx+1, cy+2), fill=(30, 18, 10))
    # cup
    d.line([(cx-2, cy-1), (cx+2, cy-1)], fill=TORCH_BRACKET_HI)
    d.point((cx-2, cy), fill=TORCH_BRACKET)
    d.point((cx+2, cy), fill=TORCH_BRACKET)

    # flame (teardrop shape)
    fx, fy = cx, cy-2
    # outer
    d.line([(fx-1, fy), (fx+1, fy)], fill=FLAME_OUT)
    d.line([(fx-2, fy-1), (fx+2, fy-1)], fill=FLAME_OUT)
    d.line([(fx-2, fy-2), (fx+2, fy-2)], fill=FLAME_OUT)
    d.line([(fx-1, fy-3), (fx+1, fy-3)], fill=FLAME_OUT)
    if flame_size >= 5:
        d.point((fx, fy-4), fill=FLAME_OUT)
    # mid
    d.line([(fx-1, fy-1), (fx+1, fy-1)], fill=FLAME_MID)
    d.line([(fx-1, fy-2), (fx+1, fy-2)], fill=FLAME_MID)
    d.point((fx, fy-3), fill=FLAME_MID)
    # inner / core
    d.point((fx, fy-1), fill=FLAME_IN)
    d.point((fx, fy-2), fill=FLAME_CORE)

    # warm glow halo on surrounding pixels (sparse, transparent-feeling)
    glow_pixels = [(fx-3, fy-2),(fx+3, fy-2),(fx-3, fy-1),(fx+3, fy-1),
                   (fx-2, fy-3),(fx+2, fy-3),(fx, fy+1)]
    for gx, gy in glow_pixels:
        if 0 <= gx < W and 0 <= gy < H:
            cur = img.getpixel((gx, gy))
            blended = (
                min(255, cur[0] + 60),
                min(255, cur[1] + 35),
                min(255, cur[2] + 10),
            )
            d.point((gx, gy), fill=blended)


def draw_skull(cx, cy):
    """Tiny 6x6 skull decoration."""
    # cranium
    d.rectangle([cx-2, cy-2, cx+2, cy+1], fill=SKULL)
    # jaw
    d.rectangle([cx-1, cy+2, cx+1, cy+3], fill=SKULL)
    d.point((cx-2, cy+2), fill=SKULL_SHADE)
    d.point((cx+2, cy+2), fill=SKULL_SHADE)
    # eyes
    d.point((cx-1, cy), fill=SKULL_EYE)
    d.point((cx+1, cy), fill=SKULL_EYE)
    # nose
    d.point((cx, cy+1), fill=SKULL_EYE)
    # tooth gap
    d.point((cx, cy+3), fill=SKULL_EYE)
    # cranium shading
    d.point((cx-2, cy-2), fill=SKULL_SHADE)
    d.point((cx+2, cy-2), fill=SKULL_SHADE)
    d.point((cx-2, cy+1), fill=SKULL_SHADE)
    d.point((cx+2, cy+1), fill=SKULL_SHADE)


def draw_chest(cx, cy):
    """Treasure chest, ~12x9 px, cx,cy = top center."""
    # lid
    d.rectangle([cx-5, cy, cx+5, cy+2], fill=CHEST_WOOD)
    d.line([(cx-5, cy), (cx+5, cy)], fill=CHEST_WOOD_HI)
    # body
    d.rectangle([cx-5, cy+3, cx+5, cy+8], fill=CHEST_WOOD)
    # wood planks
    d.line([(cx-5, cy+5), (cx+5, cy+5)], fill=CHEST_DARK)
    # gold trim top + bottom
    d.line([(cx-5, cy+2), (cx+5, cy+2)], fill=CHEST_GOLD)
    d.line([(cx-5, cy+8), (cx+5, cy+8)], fill=CHEST_GOLD)
    # corners
    d.point((cx-5, cy), fill=CHEST_GOLD)
    d.point((cx+5, cy), fill=CHEST_GOLD)
    d.point((cx-5, cy+8), fill=CHEST_GOLD_HI)
    d.point((cx+5, cy+8), fill=CHEST_GOLD_HI)
    # lock
    d.rectangle([cx-1, cy+3, cx+1, cy+5], fill=CHEST_GOLD)
    d.point((cx, cy+4), fill=CHEST_DARK)
    d.point((cx-1, cy+3), fill=CHEST_GOLD_HI)
    # side shadow
    d.line([(cx+5, cy+3), (cx+5, cy+7)], fill=CHEST_DARK)


def draw_vines(x, y, length):
    """Hanging vine."""
    cx = x
    for i in range(length):
        c = MOSS if i % 2 == 0 else MOSS_DARK
        d.point((cx, y+i), fill=c)
        if i % 3 == 0:
            d.point((cx+1, y+i), fill=MOSS_HI)
        if i % 4 == 0 and i > 0:
            d.point((cx-1, y+i), fill=MOSS)


# ============================================================
#  Layout grid — 32 cols x 24 rows. '#' = wall, '=' = platform top,
#  'o' = platform body, '.' = empty.
# ============================================================
layout = [
    "################################",  # 0  top wall
    "################################",  # 1  top wall (2-thick ceiling)
    "#..............................#",  # 2
    "#..............................#",  # 3
    "#..............................#",  # 4
    "#..............................#",  # 5
    "#......===.............===.....#",  # 6  upper platforms
    "#......ooo.............ooo.....#",  # 7
    "#..............................#",  # 8
    "#..............................#",  # 9
    "#............======............#",  # 10 center platform
    "#............oooooo............#",  # 11
    "#..............................#",  # 12
    "#..............................#",  # 13
    "#...====...........====........#",  # 14 lower-mid platforms
    "#...oooo...........oooo........#",  # 15
    "#..............................#",  # 16
    "#..............................#",  # 17
    "#..............................#",  # 18
    "#..............................#",  # 19
    "#..............................#",  # 20
    "#..............................#",  # 21
    "################################",  # 22 floor
    "################################",  # 23 floor
]

assert len(layout) == ROWS, f"got {len(layout)} rows"
for i, r in enumerate(layout):
    assert len(r) == COLS, f"row {i} has {len(r)} cols"


# ============================================================
#  Draw everything
# ============================================================
def render():
    draw_bg()

    # First pass — solid stone tiles & platforms
    for row in range(ROWS):
        for col in range(COLS):
            ch = layout[row][col]
            x, y = col*TILE, row*TILE

            if ch == '#':
                # decide mossy-top: only if tile above is empty bg
                above = layout[row-1][col] if row > 0 else '#'
                mossy = (above == '.' and random.random() < 0.7)
                # runes occasionally on bigger walls
                rune = (random.random() < 0.04 and row > 2 and row < ROWS-2)
                stone_tile(x, y, mossy_top=mossy, has_rune=rune)
            elif ch == '=':
                platform_top_tile(x, y, mossy=True)
            elif ch == 'o':
                platform_body_tile(x, y)

    # Hanging chains from ceiling — pick a few columns over open space
    for col, length in [(4, 38), (9, 22), (16, 18), (22, 30), (27, 26)]:
        cx = col*TILE + 5
        cy = 2*TILE  # just under the ceiling
        draw_chain(cx, cy, length)

    # Vines hanging from platform undersides
    draw_vines(7*TILE+2, 8*TILE,  10)
    draw_vines(22*TILE+8, 8*TILE,  9)
    draw_vines(13*TILE+1, 12*TILE, 12)
    draw_vines(18*TILE+8, 12*TILE, 11)
    draw_vines(4*TILE+3,  16*TILE,  8)
    draw_vines(25*TILE+5, 16*TILE,  9)

    # Torches — placed on platform tops and on side walls
    # platform-mounted (sit on top of a platform tile)
    draw_torch(7*TILE+1,  6*TILE-1)   # left upper platform
    draw_torch(8*TILE+8,  6*TILE-1)
    draw_torch(23*TILE+1, 6*TILE-1)   # right upper platform
    draw_torch(24*TILE+8, 6*TILE-1)
    draw_torch(14*TILE+2, 10*TILE-1)  # center platform
    draw_torch(17*TILE+7, 10*TILE-1)
    draw_torch(4*TILE+1,  14*TILE-1)  # lower-mid left
    draw_torch(6*TILE+8,  14*TILE-1)
    draw_torch(18*TILE+1, 14*TILE-1)  # lower-mid right
    draw_torch(20*TILE+8, 14*TILE-1)

    # wall torches mounted on side walls — point inward
    draw_torch(1*TILE+5, 9*TILE)
    draw_torch(30*TILE+4, 9*TILE)
    draw_torch(1*TILE+5, 18*TILE)
    draw_torch(30*TILE+4, 18*TILE)

    # Skulls scattered on the floor / shelves
    draw_skull(10*TILE+4, 22*TILE-2)
    draw_skull(13*TILE+6, 22*TILE-2)
    draw_skull(20*TILE+4, 22*TILE-2)
    # one on the center platform
    draw_skull(16*TILE+2, 10*TILE-4)

    # Treasure chests at the corners of the floor
    draw_chest(4*TILE+5,  22*TILE-9)
    draw_chest(27*TILE+5, 22*TILE-9)

    # subtle vignette darkening at corners
    for y in range(H):
        for x in range(W):
            dx = abs(x - W/2) / (W/2)
            dy = abs(y - H/2) / (H/2)
            dist = (dx*dx + dy*dy) ** 0.5
            if dist > 0.85:
                amt = min(0.45, (dist - 0.85) * 1.8)
                cur = img.getpixel((x, y))
                d.point((x, y), fill=(
                    int(cur[0]*(1-amt)),
                    int(cur[1]*(1-amt)),
                    int(cur[2]*(1-amt)),
                ))


render()

# Save native resolution
native_path = '/sessions/nice-zen-rubin/mnt/outputs/dungeon_level_320x240.png'
img.save(native_path)

# Upscale 4x with nearest-neighbor for crisp pixels
upscaled = img.resize((W*4, H*4), Image.NEAREST)
upscaled_path = '/sessions/nice-zen-rubin/mnt/outputs/dungeon_level_1280x960.png'
upscaled.save(upscaled_path)

# Also a 2x version for in-engine flexibility
img.resize((W*2, H*2), Image.NEAREST).save('/sessions/nice-zen-rubin/mnt/outputs/dungeon_level_640x480.png')

print(f"Saved {native_path}")
print(f"Saved {upscaled_path}")
print(f"Saved 640x480 version too")
