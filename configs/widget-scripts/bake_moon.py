import math
from PIL import Image

# Clean, defect-fixed base (edge-trimmed + anti-aliased) - see
# fix_moon_base.py, which only needs to run once per source photo. This
# script just applies the directional rim-light on top of it.
BASE_PATH = "/home/hugin/.local/share/icons/hicolor/Custom/moon-base-fixed.png"
OUT_PATH = "/home/hugin/.local/share/plasma-widgets-shared/moon_gpu_lit.png"

moon = Image.open(BASE_PATH).convert("RGBA")
W, H = moon.size

angle = math.radians(135)  # full diagonal southwest, picked from comparison
lx, ly = math.cos(angle), math.sin(angle)
light_color = (205 / 255, 29 / 255, 113 / 255)
lr, lg, lb = light_color

px = moon.load()
R = min(W, H) / 2
cx0, cy0 = W / 2, H / 2

for yy in range(H):
    for xx in range(W):
        r_, g_, b_, a_ = px[xx, yy]
        if a_ == 0:
            continue
        dx = (xx - cx0) / R
        dy = (yy - cy0) / R
        d2 = min(1.0, dx * dx + dy * dy)
        nz = math.sqrt(max(0.0, 1 - d2))
        facing = dx * lx + dy * ly

        lit = max(0.0, facing)
        rim = (lit ** 1.8) * ((1 - nz) ** 0.55)
        strength = min(1.0, rim * 3.4)
        nr = r_ + strength * lr * 255 * 1.15
        ng = g_ + strength * lg * 255 * 1.15
        nb = b_ + strength * lb * 255 * 1.15

        shadow = max(0.0, -facing) ** 1.4
        dark = 1 - shadow * 0.55
        nr *= dark
        ng *= dark
        nb *= dark

        px[xx, yy] = (int(max(0, min(255, nr))), int(max(0, min(255, ng))), int(max(0, min(255, nb))), a_)

moon.save(OUT_PATH)
print("saved", OUT_PATH, moon.size)
