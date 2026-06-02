#!/usr/bin/env python3
# PROTOTYPE asset generator — Sakura Temple ambience birds.
#
# Emits a 4-frame wing-flap silhouette of a distant gull, drawn as a horizontal
# strip so a Sprite2D can cycle hframes. Each cell is 14x9 px (strip 56x9).
# The body is a dark slate silhouette; the *topmost* lit pixel of each wing
# column gets a cool moonlit rim so the bird reads against the night sky.
#
# Output (native + 4x/8x NEAREST upscales):
#   birds_4frame_native_56x9.png
#   birds_4frame_4x_224x36.png
#   birds_4frame_8x_448x72.png

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

CELL_W, CELL_H = 14, 9
FRAMES = 4

DARK = (54, 58, 78, 255)      # silhouette body/wing
RIM  = (150, 162, 196, 255)   # moonlit top edge

# Per-frame LEFT-wing polylines, body-center -> wingtip. Right wing mirrors
# across x=13. Points are (x, y), y=0 at top. Each wing humps up to a peak then
# droops to the tip, giving the classic distant-gull "mm" silhouette; the flap
# cycles the peak height: high -> mid -> low(flat) -> mid.
LEFT_WINGS = [
	[(6, 5), (5, 3), (3, 2), (1, 3), (0, 5)],   # 0: deep up-flap (peak high)
	[(6, 5), (5, 4), (3, 3), (1, 4), (0, 5)],   # 1: mid, descending
	[(6, 5), (5, 4), (3, 4), (1, 4), (0, 5)],   # 2: down-flap (peak flat/low)
	[(6, 5), (5, 4), (3, 3), (1, 4), (0, 5)],   # 3: mid, rising
]

# Small body block, shared across frames (sits at the wing valley).
BODY = [(6, 5), (7, 5), (6, 6), (7, 6)]


def _line(px, a, b, color):
	# Integer Bresenham between two points (inclusive).
	x0, y0 = a
	x1, y1 = b
	dx = abs(x1 - x0)
	dy = -abs(y1 - y0)
	sx = 1 if x0 < x1 else -1
	sy = 1 if y0 < y1 else -1
	err = dx + dy
	while True:
		px[(x0, y0)] = color
		if x0 == x1 and y0 == y1:
			break
		e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


def build_frame(idx):
	px = {}
	# Left wing polyline + mirrored right wing.
	pts = LEFT_WINGS[idx]
	for i in range(len(pts) - 1):
		_line(px, pts[i], pts[i + 1], DARK)
		a = (13 - pts[i][0], pts[i][1])
		b = (13 - pts[i + 1][0], pts[i + 1][1])
		_line(px, a, b, DARK)
	for p in BODY:
		px[p] = DARK
	# Moonlit rim: lighten the topmost filled pixel in each column.
	cols = {}
	for (x, y) in px:
		if x not in cols or y < cols[x]:
			cols[x] = y
	for x, y in cols.items():
		px[(x, y)] = RIM
	return px


def main():
	strip = Image.new("RGBA", (CELL_W * FRAMES, CELL_H), (0, 0, 0, 0))
	for f in range(FRAMES):
		px = build_frame(f)
		for (x, y), c in px.items():
			if 0 <= x < CELL_W and 0 <= y < CELL_H:
				strip.putpixel((f * CELL_W + x, y), c)

	native = os.path.join(HERE, "birds_4frame_native_56x9.png")
	strip.save(native)
	for scale, tag in ((4, "4x_224x36"), (8, "8x_448x72")):
		up = strip.resize((strip.width * scale, strip.height * scale), Image.NEAREST)
		up.save(os.path.join(HERE, "birds_4frame_%s.png" % tag))
	print("wrote", native, "and 4x/8x upscales")


if __name__ == "__main__":
	main()
