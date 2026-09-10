#!/usr/bin/env python3
# PROTOTYPE asset generator — Neo Tokyo ambience flying cars.
#
# Emits a 4-frame sleek hovercar silhouette, drawn as a horizontal strip so a
# Sprite2D can cycle hframes. Each cell is 20x10 px (strip 80x10). The car faces
# RIGHT by default (flip_h handles the other direction in-engine).
#
# Like the Sakura birds: a dark hull silhouette + a cool light rim on the top
# edge, so the shape reads against the rainy night sky. Extra future-car flavour:
#   - a glowing rear THRUSTER whose exhaust plume pulses across the 4 frames,
#   - a blinking NAV light on the nose,
#   - a faint UNDERGLOW reflection line beneath the hull.
# The whole sprite is tinted per-instance in GDScript (modulate) to cyan / magenta
# / amber, so the near-white glow pixels take the neon colour brightly while the
# dark hull stays a deep tinted shadow.
#
# Output (native + 4x/8x NEAREST upscales):
#   flyingcars_4frame_native_80x10.png
#   flyingcars_4frame_4x_320x40.png
#   flyingcars_4frame_8x_640x80.png

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

CELL_W, CELL_H = 20, 10
FRAMES = 4

DARK  = (40, 44, 70, 255)        # hull body silhouette
RIM   = (158, 176, 214, 255)     # cool lit top edge / canopy dome
GLOW  = (236, 246, 255, 255)     # thruster core (near-white -> takes tint bright)
UNDER = (120, 150, 205, 255)     # faint underglow reflection
NAV   = (255, 255, 255, 255)     # blinking nose nav light

# Hull spans per row (y -> inclusive x range), car facing right. A sleek wedge:
# blunt rear at x~4, pointed nose at x~18, low-profile canopy on top.
HULL = {
    3: (10, 14),   # canopy roofline
    4: (6, 17),    # upper body
    5: (4, 18),    # widest band, nose tip at 18
    6: (4, 17),    # lower body
    7: (6, 14),    # underside taper
}

# Canopy dome bump (RIM glass) sitting above the roofline.
CANOPY = [(11, 2), (12, 2), (13, 2)]

# Rear thruster core (GLOW), behind the hull.
THRUSTER = [(3, 5), (3, 6), (4, 5), (4, 6)]

# Per-frame exhaust plume trailing left from the thruster (x columns, at y=5..6).
# Pulse: long -> med -> short -> med.
EXHAUST = [
    [0, 1, 2],
    [1, 2],
    [2],
    [1, 2],
]

# Nav light blinks on for frames 0,1 and off for 2,3.
NAV_ON = [True, True, False, False]
NAV_POS = (17, 4)

# Faint underglow reflection line beneath the hull.
UNDERGLOW = [(x, 8) for x in range(7, 14)]


def build_frame(idx):
    px = {}
    # Hull body.
    for y, (x0, x1) in HULL.items():
        for x in range(x0, x1 + 1):
            px[(x, y)] = DARK
    # Cool lit rim on the topmost hull pixel of each column.
    cols = {}
    for (x, y) in list(px.keys()):
        if x not in cols or y < cols[x]:
            cols[x] = y
    for x, y in cols.items():
        px[(x, y)] = RIM
    # Canopy dome.
    for p in CANOPY:
        px[p] = RIM
    # Underglow reflection.
    for p in UNDERGLOW:
        px[p] = UNDER
    # Thruster core + exhaust plume.
    for p in THRUSTER:
        px[p] = GLOW
    for x in EXHAUST[idx]:
        px[(x, 5)] = GLOW
        px[(x, 6)] = GLOW
    # Nav light.
    if NAV_ON[idx]:
        px[NAV_POS] = NAV
    return px


def main():
    strip = Image.new("RGBA", (CELL_W * FRAMES, CELL_H), (0, 0, 0, 0))
    for f in range(FRAMES):
        px = build_frame(f)
        for (x, y), c in px.items():
            if 0 <= x < CELL_W and 0 <= y < CELL_H:
                strip.putpixel((f * CELL_W + x, y), c)

    native = os.path.join(HERE, "flyingcars_4frame_native_80x10.png")
    strip.save(native)
    for scale, tag in ((4, "4x_320x40"), (8, "8x_640x80")):
        up = strip.resize((strip.width * scale, strip.height * scale), Image.NEAREST)
        up.save(os.path.join(HERE, "flyingcars_4frame_%s.png" % tag))
    print("wrote", native, "and 4x/8x upscales")


if __name__ == "__main__":
    main()
