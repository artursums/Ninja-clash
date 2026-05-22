"""
Neo-Tokyo rooftop arena — TowerFall-style level background.
Native: 320x240 (4:3, chunky pixels)
Output: upscaled 4x (1280x960) and 2x (640x480)
"""

from PIL import Image, ImageDraw
import random

W, H = 320, 240
TILE = 10
COLS = W // TILE   # 32
ROWS = H // TILE   # 24

# ============================================================
# Palette — cyberpunk neon night
# ============================================================
SKY_TOP    = (10,  4,  32)
SKY_MID    = (38, 12,  62)
SKY_HORIZ  = (148, 30, 108)
SKY_LOWER  = (88,  18, 78)
FAR_BLDG   = (22, 16,  44)
MID_BLDG   = (14, 10,  32)
NEAR_BLDG  = (8,   6,  22)

WIN_WARM   = (255, 210, 110)
WIN_COOL   = (110, 200, 255)
WIN_PINK   = (255, 120, 200)

NEON_CYAN     = (90,  240, 255)
NEON_CYAN_HI  = (200, 250, 255)
NEON_MAG      = (255, 80,  200)
NEON_MAG_HI   = (255, 200, 240)
NEON_PINK     = (255, 60,  150)
NEON_YEL      = (255, 224, 90)
NEON_GREEN    = (130, 255, 160)

PANEL_DARK    = (28,  24,  44)
PANEL_MID     = (50,  46,  74)
PANEL_HI      = (88,  84,  120)
PANEL_VDARK   = (10,  8,   18)
RIVET         = (170, 168, 195)

LANT_RED      = (240, 60,  60)
LANT_RED_HI   = (255, 160, 130)
LANT_RED_DARK = (140, 28,  28)
LANT_CORD     = (90,  60,  40)
LANT_TASSEL   = (255, 200, 100)

RAIN          = (170, 200, 255)
RAIN_BRIGHT   = (220, 235, 255)

random.seed(2025)
img = Image.new('RGB', (W, H), SKY_TOP)
d = ImageDraw.Draw(img)


# ============================================================
# Background painting (sky + skyline + pagodas + rain)
# ============================================================
def paint_sky():
    # 3-stop vertical gradient
    for y in range(H):
        if y < H * 0.40:
            t = y / (H * 0.40)
            r = int(SKY_TOP[0]  + (SKY_MID[0]  - SKY_TOP[0])  * t)
            g = int(SKY_TOP[1]  + (SKY_MID[1]  - SKY_TOP[1])  * t)
            b = int(SKY_TOP[2]  + (SKY_MID[2]  - SKY_TOP[2])  * t)
        elif y < H * 0.72:
            t = (y - H*0.40) / (H*0.32)
            r = int(SKY_MID[0]  + (SKY_HORIZ[0] - SKY_MID[0]) * t)
            g = int(SKY_MID[1]  + (SKY_HORIZ[1] - SKY_MID[1]) * t)
            b = int(SKY_MID[2]  + (SKY_HORIZ[2] - SKY_MID[2]) * t)
        else:
            t = (y - H*0.72) / (H*0.28)
            r = int(SKY_HORIZ[0] + (SKY_LOWER[0] - SKY_HORIZ[0]) * t)
            g = int(SKY_HORIZ[1] + (SKY_LOWER[1] - SKY_HORIZ[1]) * t)
            b = int(SKY_HORIZ[2] + (SKY_LOWER[2] - SKY_HORIZ[2]) * t)
        d.line([(0, y), (W-1, y)], fill=(r, g, b))


def paint_stars():
    for _ in range(45):
        x = random.randint(0, W-1)
        y = random.randint(0, int(H * 0.35))
        c = random.choice([(220,220,255),(255,200,230),(180,200,255)])
        d.point((x, y), fill=c)


def paint_moon():
    # crescent moon top-right area
    cx, cy, r = 248, 38, 14
    # full disc
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255, 230, 200))
    # cutout to make crescent
    d.ellipse([cx-r+6, cy-r-1, cx+r+6, cy+r-1], fill=img.getpixel((cx, cy-r-3)))
    # halo
    for ring, col in [(r+2,(255,200,160)), (r+4,(255,170,140))]:
        for ang in range(0, 360, 22):
            import math
            ax = int(cx + ring * math.cos(math.radians(ang)))
            ay = int(cy + ring * math.sin(math.radians(ang)))
            cur = img.getpixel((ax, ay))
            mix = ((cur[0]+col[0])//2, (cur[1]+col[1])//2, (cur[2]+col[2])//2)
            d.point((ax, ay), fill=mix)


def paint_far_skyline():
    """Far-distance city silhouette with tiny window lights."""
    skyline = []  # list of (x_start, x_end, height_px) building rects
    x = 0
    while x < W:
        w = random.randint(8, 22)
        h = random.randint(20, 50)
        skyline.append((x, x+w, h))
        x += w + random.randint(0, 2)
    # baseline of distant skyline
    base_y = int(H * 0.68)
    for x1, x2, h in skyline:
        top_y = base_y - h
        d.rectangle([x1, top_y, x2, base_y], fill=FAR_BLDG)
        # window lights
        for wy in range(top_y + 3, base_y - 1, 4):
            for wx in range(x1 + 1, x2 - 1, 3):
                if random.random() < 0.35:
                    c = random.choice([WIN_WARM, WIN_COOL, WIN_PINK,
                                       WIN_WARM, WIN_COOL])
                    d.point((wx, wy), fill=c)
        # rooftop antenna sometimes
        if random.random() < 0.25 and (x2 - x1) > 12:
            tx = (x1 + x2) // 2
            d.line([(tx, top_y), (tx, top_y - random.randint(3, 8))],
                   fill=(50, 40, 70))
            d.point((tx, top_y - 5), fill=NEON_PINK)


def paint_mid_skyline():
    """Closer/taller buildings + pagoda silhouettes."""
    base_y = int(H * 0.74)

    # A big skyscraper with a vertical neon strip (faux kanji billboard)
    bx1, bx2, bt = 70, 92, int(H * 0.20)
    d.rectangle([bx1, bt, bx2, base_y], fill=MID_BLDG)
    # window grid
    for wy in range(bt + 3, base_y - 1, 4):
        for wx in range(bx1 + 2, bx2 - 1, 4):
            if random.random() < 0.55:
                c = random.choice([WIN_WARM, WIN_COOL, WIN_WARM])
                d.point((wx, wy), fill=c)
    # neon vertical signboard panel
    sx1, sx2 = bx1 + 14, bx1 + 18
    d.rectangle([sx1, bt + 6, sx2, bt + 60], fill=(60, 12, 50))
    # faux kanji glyphs (3 stacked)
    glyphs = [
        # 月-like
        [(0,0,1),(1,0,1),(2,0,1),(3,0,1),
         (0,1,1),(3,1,1),
         (0,2,1),(1,2,1),(2,2,1),(3,2,1),
         (0,3,1),(3,3,1),
         (0,4,1),(1,4,1),(2,4,1),(3,4,1)],
        # 刀-like
        [(2,0,1),(3,0,1),
         (1,1,1),(2,1,1),(3,1,1),
         (0,2,1),(2,2,1),
         (0,3,1),(2,3,1),
         (1,4,1),(2,4,1)],
        # 王-like
        [(0,0,1),(1,0,1),(2,0,1),(3,0,1),
         (1,1,1),(2,1,1),
         (0,2,1),(1,2,1),(2,2,1),(3,2,1),
         (1,3,1),(2,3,1),
         (0,4,1),(1,4,1),(2,4,1),(3,4,1)],
    ]
    for i, g in enumerate(glyphs):
        gy_off = bt + 10 + i * 16
        for gx, gy, _ in g:
            d.point((sx1 + gx, gy_off + gy), fill=NEON_PINK)
        # glow around glyph
        for gx, gy, _ in g:
            for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                ax, ay = sx1 + gx + dx, gy_off + gy + dy
                if 0 <= ax < W and 0 <= ay < H:
                    cur = img.getpixel((ax, ay))
                    mix = (min(255, cur[0]+90), min(255, cur[1]+25),
                           min(255, cur[2]+60))
                    d.point((ax, ay), fill=mix)

    # Pagoda silhouette
    px_, py_ = 195, int(H * 0.55)
    # base
    d.rectangle([px_-1, py_+30, px_+11, base_y], fill=MID_BLDG)
    # tiered roofs (3 tiers, each wider on top)
    tiers = [(0, 12, 6), (-2, 14, 11), (-4, 16, 16)]
    for off_x, w, top_off in tiers:
        d.polygon([
            (px_ + off_x, py_ + top_off + 5),
            (px_ + 5,     py_ + top_off - 1),
            (px_ + off_x + w, py_ + top_off + 5),
        ], fill=MID_BLDG)
        # roof underline (curved up at edges)
        d.line([(px_ + off_x, py_ + top_off + 5),
                (px_ + off_x + w, py_ + top_off + 5)], fill=NEAR_BLDG)
        d.point((px_ + off_x - 1, py_ + top_off + 4), fill=MID_BLDG)
        d.point((px_ + off_x + w + 1, py_ + top_off + 4), fill=MID_BLDG)
    # spire
    d.line([(px_ + 5, py_ - 2), (px_ + 5, py_ + 5)], fill=MID_BLDG)
    d.point((px_ + 5, py_ - 3), fill=NEON_YEL)
    # a couple of windows on tiers
    d.point((px_+4, py_+15), fill=WIN_WARM)
    d.point((px_+6, py_+15), fill=WIN_WARM)
    d.point((px_+4, py_+25), fill=WIN_WARM)
    d.point((px_+6, py_+25), fill=WIN_WARM)

    # Another tall building right of pagoda
    bx1, bx2, bt = 230, 250, int(H * 0.30)
    d.rectangle([bx1, bt, bx2, base_y], fill=MID_BLDG)
    for wy in range(bt + 3, base_y - 1, 4):
        for wx in range(bx1 + 2, bx2 - 1, 4):
            if random.random() < 0.5:
                d.point((wx, wy), fill=random.choice([WIN_COOL, WIN_WARM]))
    # horizontal neon band near top
    d.line([(bx1, bt+4), (bx2, bt+4)], fill=NEON_CYAN)
    # antenna
    d.line([(240, bt), (240, bt-12)], fill=NEAR_BLDG)
    d.point((240, bt-13), fill=NEON_CYAN_HI)

    # near foreground rooftop silhouette band — behind the arena floor
    d.rectangle([0, base_y, W, base_y + 18], fill=NEAR_BLDG)
    # add some near-foreground window dots
    for _ in range(30):
        wx = random.randint(0, W-1)
        wy = random.randint(base_y + 2, base_y + 16)
        d.point((wx, wy), fill=random.choice([WIN_WARM, WIN_COOL]))


def paint_rain():
    """Diagonal rain streaks."""
    for _ in range(140):
        x = random.randint(0, W-1)
        y = random.randint(0, int(H*0.78))
        length = random.randint(2, 5)
        bright = random.random() < 0.2
        c = RAIN_BRIGHT if bright else RAIN
        for i in range(length):
            xx, yy = x - i, y + i
            if 0 <= xx < W and 0 <= yy < H:
                d.point((xx, yy), fill=c)


def paint_drone():
    """A tiny drone with blinking red light flying mid-air."""
    dx, dy = 60, 90
    d.rectangle([dx, dy, dx+4, dy+1], fill=(40, 40, 60))
    d.point((dx-1, dy), fill=NEON_PINK)
    d.point((dx+5, dy), fill=NEON_PINK)
    d.point((dx+2, dy+2), fill=NEON_YEL)


# ============================================================
# Tile / structure drawing (foreground arena)
# ============================================================
def panel_tile(x, y, top_neon=None, left_neon=None, right_neon=None):
    """Steel grate floor/wall tile with optional glowing neon edges."""
    d.rectangle([x, y, x+TILE-1, y+TILE-1], fill=PANEL_DARK)
    # internal grate
    d.line([(x+1, y+5), (x+TILE-2, y+5)], fill=PANEL_MID)
    d.line([(x+5, y+1), (x+5, y+TILE-2)], fill=PANEL_MID)
    # rivets corners
    d.point((x+1, y+1), fill=RIVET)
    d.point((x+TILE-2, y+1), fill=RIVET)
    d.point((x+1, y+TILE-2), fill=RIVET)
    d.point((x+TILE-2, y+TILE-2), fill=RIVET)
    # base edges
    d.line([(x, y),         (x+TILE-1, y)],         fill=PANEL_HI)
    d.line([(x, y),         (x, y+TILE-1)],         fill=PANEL_HI)
    d.line([(x, y+TILE-1),  (x+TILE-1, y+TILE-1)],  fill=PANEL_VDARK)
    d.line([(x+TILE-1, y),  (x+TILE-1, y+TILE-1)],  fill=PANEL_VDARK)

    # neon glow edges
    if top_neon:
        d.line([(x, y), (x+TILE-1, y)], fill=top_neon)
        # bleed glow into row below
        for gx in range(x, x+TILE):
            cur = img.getpixel((gx, y+1))
            d.point((gx, y+1), fill=(
                min(255, cur[0]+40), min(255, cur[1]+60), min(255, cur[2]+50)))
    if left_neon:
        d.line([(x, y), (x, y+TILE-1)], fill=left_neon)
        for gy in range(y, y+TILE):
            cur = img.getpixel((x+1, gy))
            d.point((x+1, gy), fill=(
                min(255, cur[0]+40), min(255, cur[1]+30), min(255, cur[2]+60)))
    if right_neon:
        d.line([(x+TILE-1, y), (x+TILE-1, y+TILE-1)], fill=right_neon)
        for gy in range(y, y+TILE):
            cur = img.getpixel((x+TILE-2, gy))
            d.point((x+TILE-2, gy), fill=(
                min(255, cur[0]+40), min(255, cur[1]+30), min(255, cur[2]+60)))


def platform_top(x, y, neon=NEON_MAG):
    """Floating platform top — glowing neon trim on top."""
    d.rectangle([x, y, x+TILE-1, y+TILE-1], fill=PANEL_DARK)
    # grate detail
    d.line([(x, y+6), (x+TILE-1, y+6)], fill=PANEL_MID)
    d.line([(x+5, y+2), (x+5, y+5)], fill=PANEL_MID)
    d.line([(x+5, y+7), (x+5, y+TILE-2)], fill=PANEL_MID)
    # edges
    d.line([(x, y+1), (x+TILE-1, y+1)], fill=PANEL_HI)
    d.line([(x, y), (x+TILE-1, y)], fill=neon)
    d.line([(x, y+TILE-1), (x+TILE-1, y+TILE-1)], fill=PANEL_VDARK)
    d.line([(x, y), (x, y+TILE-1)], fill=PANEL_HI)
    d.line([(x+TILE-1, y), (x+TILE-1, y+TILE-1)], fill=PANEL_VDARK)
    # rivets
    d.point((x+1, y+2), fill=RIVET)
    d.point((x+TILE-2, y+2), fill=RIVET)
    # neon glow bleed downward
    for gx in range(x, x+TILE):
        cur = img.getpixel((gx, y+1))
        mix = ((cur[0]+neon[0])//2, (cur[1]+neon[1])//2, (cur[2]+neon[2])//2)
        d.point((gx, y+1), fill=mix)


def platform_body(x, y, side_neon=NEON_MAG):
    """Underside of platform — darker with side neon strip."""
    d.rectangle([x, y, x+TILE-1, y+TILE-1], fill=PANEL_VDARK)
    d.line([(x, y+5), (x+TILE-1, y+5)], fill=PANEL_MID)
    d.line([(x+5, y), (x+5, y+TILE-1)], fill=PANEL_MID)
    d.line([(x, y), (x, y+TILE-1)], fill=PANEL_DARK)
    d.line([(x+TILE-1, y), (x+TILE-1, y+TILE-1)], fill=PANEL_DARK)
    d.line([(x, y+TILE-1), (x+TILE-1, y+TILE-1)], fill=PANEL_VDARK)


# ============================================================
# Decoration sprites
# ============================================================
def draw_lantern(cx, top_y, cord_len=14):
    """Round paper lantern hanging from above."""
    # cord
    for i in range(cord_len):
        d.point((cx, top_y + i), fill=LANT_CORD)
    # top cap
    by = top_y + cord_len
    d.line([(cx-2, by), (cx+2, by)], fill=(40, 30, 20))
    d.line([(cx-1, by-1), (cx+1, by-1)], fill=(60, 45, 30))
    # body (roundish)
    body_rows = [
        (by+1,  -3, 3),
        (by+2,  -4, 4),
        (by+3,  -4, 4),
        (by+4,  -4, 4),
        (by+5,  -4, 4),
        (by+6,  -3, 3),
        (by+7,  -2, 2),
    ]
    for ry, x1, x2 in body_rows:
        d.line([(cx+x1, ry), (cx+x2, ry)], fill=LANT_RED)
    # highlight
    d.line([(cx-3, by+2), (cx-3, by+4)], fill=LANT_RED_HI)
    d.point((cx-2, by+1), fill=LANT_RED_HI)
    # shadow on right
    d.line([(cx+3, by+3), (cx+3, by+5)], fill=LANT_RED_DARK)
    # horizontal bands
    d.line([(cx-3, by+3), (cx+3, by+3)], fill=LANT_RED_DARK)
    d.line([(cx-3, by+5), (cx+3, by+5)], fill=LANT_RED_DARK)
    # bottom cap
    d.line([(cx-2, by+8), (cx+2, by+8)], fill=(40, 30, 20))
    d.point((cx, by+9), fill=LANT_TASSEL)
    d.point((cx, by+10), fill=LANT_TASSEL)
    # warm glow halo
    for dx in range(-6, 7):
        for dy in range(-1, 9):
            if abs(dx) + abs(dy) > 8: continue
            gx, gy = cx + dx, by + dy
            if 0 <= gx < W and 0 <= gy < H and abs(dx) > 4:
                cur = img.getpixel((gx, gy))
                d.point((gx, gy), fill=(
                    min(255, cur[0]+30), min(255, cur[1]+10), min(255, cur[2]+5)))


def draw_holo_billboard(cx, cy, w=22, h=14):
    """Holographic billboard floating mid-air with neon glyphs."""
    # frame
    x1, y1, x2, y2 = cx - w//2, cy - h//2, cx + w//2, cy + h//2
    # back glow
    for dy in range(-2, h+2):
        for dx in range(-2, w+2):
            xx, yy = x1+dx, y1+dy
            if 0 <= xx < W and 0 <= yy < H:
                cur = img.getpixel((xx, yy))
                d.point((xx, yy), fill=(
                    min(255, cur[0]+10),
                    min(255, cur[1]+25),
                    min(255, cur[2]+35)))
    # panel
    d.rectangle([x1, y1, x2, y2], fill=(20, 30, 60))
    d.line([(x1, y1), (x2, y1)], fill=NEON_CYAN)
    d.line([(x1, y2), (x2, y2)], fill=NEON_CYAN)
    d.line([(x1, y1), (x1, y2)], fill=NEON_CYAN_HI)
    d.line([(x2, y1), (x2, y2)], fill=NEON_CYAN_HI)
    # faux glyphs
    cx_inner = x1 + 3
    # glyph 1 (4 wide)
    g1 = [(0,1),(1,1),(2,1),(3,1),(1,2),(2,2),(0,3),(3,3),(0,4),(1,4),(2,4),(3,4)]
    for gx, gy in g1:
        d.point((cx_inner+gx, y1+2+gy), fill=NEON_CYAN_HI)
    # glyph 2
    g2 = [(0,1),(1,1),(2,1),(3,1),(1,2),(2,2),(1,3),(2,3),(0,4),(1,4),(2,4),(3,4)]
    for gx, gy in g2:
        d.point((cx_inner+7+gx, y1+2+gy), fill=NEON_CYAN_HI)
    # glyph 3
    g3 = [(0,1),(3,1),(0,2),(1,2),(2,2),(3,2),(0,3),(3,3),(1,4),(2,4)]
    for gx, gy in g3:
        d.point((cx_inner+14+gx, y1+2+gy), fill=NEON_CYAN_HI)
    # scan line shimmer
    for sx in range(x1+1, x2):
        if random.random() < 0.25:
            d.point((sx, cy), fill=NEON_CYAN_HI)


def draw_antenna(x_base, y_base, h=14):
    """Thin antenna with blinking light on top."""
    d.line([(x_base, y_base), (x_base, y_base - h)], fill=(60, 60, 90))
    d.point((x_base, y_base - h - 1), fill=NEON_PINK)
    # cross supports
    d.line([(x_base-2, y_base - h + 3), (x_base+2, y_base - h + 3)], fill=(60, 60, 90))


# ============================================================
# Arena layout — # walls, = platform top, o platform body, . empty sky
# ============================================================
layout = [
    "#..............................#",  # 0  open sky (only side walls)
    "#..............................#",  # 1
    "#..............................#",  # 2
    "#..............................#",  # 3
    "#..............................#",  # 4
    "#..............................#",  # 5
    "#..............................#",  # 6
    "#......===.............===.....#",  # 7  upper platforms
    "#......ooo.............ooo.....#",  # 8
    "#..............................#",  # 9
    "#..............................#",  # 10
    "#............======............#",  # 11 center platform
    "#............oooooo............#",  # 12
    "#..............................#",  # 13
    "#..............................#",  # 14
    "#...====...........====........#",  # 15 lower-mid platforms
    "#...oooo...........oooo........#",  # 16
    "#..............................#",  # 17
    "#..............................#",  # 18
    "#..............................#",  # 19
    "#..............................#",  # 20
    "#..............................#",  # 21
    "################################",  # 22 rooftop top
    "################################",  # 23 rooftop bottom
]
assert len(layout) == ROWS


# ============================================================
# Render everything
# ============================================================
def render():
    paint_sky()
    paint_stars()
    paint_moon()
    paint_far_skyline()
    paint_mid_skyline()
    paint_drone()
    paint_rain()

    # Draw arena tiles
    for row in range(ROWS):
        for col in range(COLS):
            ch = layout[row][col]
            x, y = col*TILE, row*TILE
            if ch == '#':
                # determine neon edge: top row of the floor (row 22) gets cyan top
                # side walls get cyan inner-facing
                is_floor_top = (row == 22)
                is_left_wall = (col == 0 and row < 22)
                is_right_wall = (col == COLS-1 and row < 22)
                panel_tile(
                    x, y,
                    top_neon=NEON_CYAN if is_floor_top else None,
                    right_neon=NEON_CYAN if is_left_wall else None,
                    left_neon=NEON_CYAN if is_right_wall else None,
                )
            elif ch == '=':
                platform_top(x, y, neon=NEON_MAG)
            elif ch == 'o':
                platform_body(x, y)

    # Decorations
    # Hanging paper lanterns from sky (top boundary)
    draw_lantern(50, 8, cord_len=10)
    draw_lantern(115, 4, cord_len=14)
    draw_lantern(205, 6, cord_len=12)
    draw_lantern(280, 10, cord_len=8)

    # Holographic billboard mid-air, off-center
    draw_holo_billboard(160, 50, w=30, h=18)

    # Antennas on top of side walls
    draw_antenna(5, 0, h=12)
    draw_antenna(315, 0, h=10)

    # Final glow pass — soft purple ambient on lower half
    for y in range(int(H*0.7), H):
        for x in range(W):
            if random.random() < 0.04:
                cur = img.getpixel((x, y))
                d.point((x, y), fill=(
                    min(255, cur[0]+25),
                    min(255, cur[1]+8),
                    min(255, cur[2]+30)))

    # Subtle vignette at corners
    for y in range(H):
        for x in range(W):
            dx = abs(x - W/2) / (W/2)
            dy = abs(y - H/2) / (H/2)
            dist = (dx*dx + dy*dy) ** 0.5
            if dist > 0.92:
                amt = min(0.35, (dist - 0.92) * 2.0)
                cur = img.getpixel((x, y))
                d.point((x, y), fill=(
                    int(cur[0]*(1-amt)),
                    int(cur[1]*(1-amt)),
                    int(cur[2]*(1-amt))))


render()

import os
OUT = '/sessions/nice-zen-rubin/mnt/outputs/backgrounds/neotokyo'
os.makedirs(OUT, exist_ok=True)
img.save(f'{OUT}/neotokyo_level_320x240.png')
img.resize((W*2, H*2), Image.NEAREST).save(f'{OUT}/neotokyo_level_640x480.png')
img.resize((W*4, H*4), Image.NEAREST).save(f'{OUT}/neotokyo_level_1280x960.png')
print('Saved neotokyo_level at 320x240, 640x480, 1280x960')
