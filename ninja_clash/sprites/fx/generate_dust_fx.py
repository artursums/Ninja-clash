"""
TowerFall-style movement dust FX — soft light puffs that kick up from a
ninja's feet. Three one-shot sprite strips, consumed by fx_anim.gd:

  dust_run_4frame_native_64x16.png    small low scuff behind the feet
  dust_jump_5frame_native_120x24.png  downward burst on take-off
  dust_land_5frame_native_160x32.png  wide splash on impact

Each strip is a horizontal sequence (frame N wide x H tall). Drawn at native
pixel-art resolution; the game scales them up with a NEAREST filter.
"""

import os
from PIL import Image, ImageDraw

# light dusty puff — 3 tones, all warm-grey
LIGHT = (232, 228, 236)
MID   = (198, 192, 206)
DARK  = (150, 144, 162)
TRANSPARENT = (0, 0, 0, 0)

OUT = os.path.dirname(os.path.abspath(__file__))


def blob(frame, cx, cy, r, a):
    """Composite one layered puff (dark rim, mid body, light core) at alpha a."""
    layer = Image.new('RGBA', frame.size, TRANSPARENT)
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*DARK, int(a * 0.55)))
    if r >= 1:
        d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], fill=(*MID, a))
    if r >= 2:
        d.ellipse([cx - r + 1, cy - r + 1, cx + r - 2, cy + r - 2], fill=(*LIGHT, a))
    return Image.alpha_composite(frame, layer)


def render(frames, fw, fh):
    """frames: list of frames, each a list of (cx, cy, r, alpha) blobs."""
    sheet = Image.new('RGBA', (fw * len(frames), fh), TRANSPARENT)
    for i, blobs in enumerate(frames):
        cell = Image.new('RGBA', (fw, fh), TRANSPARENT)
        for cx, cy, r, a in blobs:
            cell = blob(cell, cx, cy, r, a)
        sheet.paste(cell, (i * fw, 0), cell)
    return sheet


def save(img, name):
    img.save(os.path.join(OUT, name))
    print('wrote', name)


# ------------------------------------------------------------------
# RUN — 16x16 cells, 4 frames. A small puff pops near the feet and
# drifts up + back, thinning out.
# ------------------------------------------------------------------
RUN = [
    [(8, 12, 2, 235)],
    [(8, 11, 3, 205), (11, 12, 1, 150)],
    [(7, 10, 3, 145), (10, 11, 2, 110), (4, 12, 1, 90)],
    [(6, 9, 2, 80), (9, 10, 1, 60), (3, 11, 1, 50)],
]

# ------------------------------------------------------------------
# JUMP — 24x24 cells, 5 frames. A compact puff under the feet bursts
# down + outward into two lobes, then dissolves.
# ------------------------------------------------------------------
JUMP = [
    [(12, 17, 3, 235)],
    [(12, 18, 4, 215), (8, 18, 2, 160), (16, 18, 2, 160)],
    [(12, 19, 3, 165), (7, 19, 3, 175), (17, 19, 3, 175)],
    [(6, 19, 3, 115), (18, 19, 3, 115), (12, 20, 2, 100)],
    [(5, 19, 2, 60), (19, 19, 2, 60), (12, 20, 1, 50)],
]

# ------------------------------------------------------------------
# LAND — 32x32 cells, 5 frames. Impact splash: a low centre puff throws
# two plumes wide along the ground, rising and fading.
# ------------------------------------------------------------------
LAND = [
    [(16, 23, 3, 235)],
    [(16, 22, 3, 210), (11, 22, 3, 200), (21, 22, 3, 200)],
    [(8, 21, 4, 195), (24, 21, 4, 195), (16, 22, 2, 150)],
    [(5, 19, 3, 130), (27, 19, 3, 130), (12, 21, 2, 110), (20, 21, 2, 110)],
    [(4, 18, 2, 65), (28, 18, 2, 65), (10, 20, 1, 55), (22, 20, 1, 55)],
]


def main():
    save(render(RUN, 16, 16), 'dust_run_4frame_native_64x16.png')
    save(render(JUMP, 24, 24), 'dust_jump_5frame_native_120x24.png')
    save(render(LAND, 32, 32), 'dust_land_5frame_native_160x32.png')

    # review sheet: each effect on its own row, 6x scaled, dark backdrop
    rows = [
        ('run', render(RUN, 16, 16), 16),
        ('jump', render(JUMP, 24, 24), 24),
        ('land', render(LAND, 32, 32), 32),
    ]
    scale, pad = 6, 8
    w = max(s.width for _, s, _ in rows) * scale + pad * 2
    h = sum(s.height for _, s, _ in rows) * scale + pad * (len(rows) + 1)
    pv = Image.new('RGBA', (w, h), (28, 30, 38, 255))
    y = pad
    for _, s, fh in rows:
        big = s.resize((s.width * scale, s.height * scale), Image.NEAREST)
        pv.paste(big, (pad, y), big)
        y += fh * scale + pad
    save(pv, '_dust_fx_preview.png')


if __name__ == '__main__':
    main()
