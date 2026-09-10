#!/usr/bin/env python3
"""Generate the katana slash VFX sprite sheet — a 5-frame swept crescent matching the procedural
slash design (a crisp white-hot tapered arc with a soft glow). Follows the clash-lightning approach:
a horizontal strip played one-shot by fx_anim, additive, runtime-tinted to the clan colour via
modulate.

Frames are baked WHITE (rgb=255, alpha=brightness) so a runtime modulate tints the whole crescent to
the fighter's pastel clan colour while staying bright. The crescent sweeps + stretches across the 5
frames (forming -> full stretch -> fading), reading as one fast film-style slash. The pivot (the hand)
is at a FIXED pixel in every frame, so the arc stays anchored while it sweeps.

Crescent is drawn analytically (crisp band + soft glow), not blurred blobs, to match the in-engine
Line2D look. Outputs (clash naming convention):
  katana_slash_5frame_native_400x80.png   (80x80 per frame)
  katana_slash_5frame_4x_1600x320.png      (320x320 per frame, crisp source)
"""
import math
import numpy as np
from PIL import Image

FRAMES = 5
FS = 80                 # native frame size (px)
SS = 4                  # supersample factor
S = FS * SS
PIVOT = (34.0, 46.0)    # hand position within the frame (native px), constant across frames
RADIUS = 28.0           # blade reach (native px)
START_DEG = -140.0
ARC_SPAN_DEG = 170.0
CORE_HALF = 3.2         # native half-width of the bright core at its fattest
GLOW_HALF = 9.0         # native half-width of the soft glow at its fattest
FRAME_P = [0.1, 0.3, 0.5, 0.7, 0.9]   # swing-progress sampled per frame


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def width_curve(u):
    # Tapered: wisp at the trailing tail (u=0) -> fat middle (u≈0.55) -> fine tip (u=1).
    return np.where(u <= 0.55,
                    lerp(0.05, 1.0, u / 0.55),
                    lerp(1.0, 0.22, (u - 0.55) / 0.45))


def envelope(p):
    if p < 0.12:
        return p / 0.12
    if p > 0.55:
        return max(0.0, 1.0 - (p - 0.55) / 0.45)
    return 1.0


def band(dist, ang, tail, lead, radius, half_at_max):
    # Analytic crescent: a band of radius `radius` swept from `tail`..`lead`, half-width tapering
    # along it (width_curve), brightness fading from the trailing tail -> bright leading edge.
    u = (ang - tail) / (lead - tail)
    inside = (u >= 0.0) & (u <= 1.0)
    hw = np.maximum(0.6, half_at_max * width_curve(np.clip(u, 0.0, 1.0)))
    radial = smoothstep(1.0, 0.0, np.abs(dist - radius) / hw)   # 1 on the centerline -> 0 at edges
    along = np.clip(u, 0.0, 1.0)                                 # faint tail -> bright lead
    ends = smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.90, u)   # soften the very ends
    return np.where(inside, radial * along * ends, 0.0)


def render_frame(p):
    snap = min(max(p / 0.5, 0.0), 1.0)
    snap = 1.0 - (1.0 - snap) ** 3
    a0 = math.radians(START_DEG)
    lead = a0 + math.radians(ARC_SPAN_DEG) * snap
    radius = RADIUS * lerp(0.8, 1.12, snap) * SS
    tail = lead - math.radians(lerp(40.0, 105.0, snap))
    env = envelope(p)

    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    cx, cy = PIVOT[0] * SS, PIVOT[1] * SS
    dx, dy = xx - cx, yy - cy
    dist = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)

    core = band(dist, ang, tail, lead, radius, CORE_HALF * SS)
    glow = band(dist, ang, tail, lead, radius, GLOW_HALF * SS) * 0.55
    alpha = np.clip((core + glow) * env, 0.0, 1.0)

    rgba = np.zeros((S, S, 4), np.uint8)
    rgba[..., 0:3] = 255
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def main():
    big = Image.new("RGBA", (S * FRAMES, S), (0, 0, 0, 0))
    for i, p in enumerate(FRAME_P):
        big.paste(render_frame(p), (i * S, 0))
    big.save("katana_slash_5frame_4x_1600x320.png")
    native = big.resize((FS * FRAMES, FS), Image.LANCZOS)
    native.save("katana_slash_5frame_native_400x80.png")
    print("wrote katana_slash_5frame_native_400x80.png + _4x_1600x320.png")


if __name__ == "__main__":
    main()
