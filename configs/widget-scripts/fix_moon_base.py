from PIL import Image, ImageDraw

SRC = "/home/hugin/Pictures/moonPng.png"
OUT = "/home/hugin/.local/share/icons/hicolor/Custom/moon-base-fixed.png"

moon = Image.open(SRC).convert("RGBA")
W, H = moon.size
px = moon.load()

# The source cutout has a ~5-6% wide defect band right at its true edge: an
# over-exaggerated bright limb ramp ending in a 1-2px dark matting fringe
# from whatever tool originally cut this out. Trim the alpha mask inward
# past it, with a supersampled/box-downsampled circle for a clean
# anti-aliased edge (not a blur - a binary per-pixel cutoff produces
# jagged/pixelated edges at display size).
FULL_R = min(W, H) / 2
R = FULL_R * 0.94
cx0, cy0 = W / 2, H / 2

SS = 4
mask_hi = Image.new("L", (W * SS, H * SS), 0)
ImageDraw.Draw(mask_hi).ellipse(
    [(cx0 - R) * SS, (cy0 - R) * SS, (cx0 + R) * SS, (cy0 + R) * SS], fill=255
)
mask = mask_hi.resize((W, H), Image.Resampling.BOX)
mask_px = mask.load()

for yy in range(H):
    for xx in range(W):
        r_, g_, b_, a_ = px[xx, yy]
        if a_ == 0:
            continue
        m = mask_px[xx, yy]
        px[xx, yy] = (r_, g_, b_, min(a_, m))

moon.save(OUT)
print("saved", OUT, moon.size)
