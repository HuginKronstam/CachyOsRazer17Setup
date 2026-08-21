from PIL import Image, ImageDraw, ImageFilter

SRC = "/home/hugin/Pictures/neon-moon-dreams-stockcake.jpg"
OUT_BASE = "/home/hugin/.local/share/icons/hicolor/Custom/neon-moon-base.png"

im = Image.open(SRC).convert("RGBA")
W, H = im.size

# Center/radius measured by blurring to smooth out background stars, then
# finding the bounding box of the big bright blob (the moon + its glow),
# excluding the small secondary planet and stray star points.
cx, cy = 524, 473
radius = 370  # a bit past the measured glow extent, feathered out below

# Soft falloff, not a hard cutout - this image's own glow already fades
# naturally into the dark background, so a hard edge would clip that look;
# a wide feather matches the source material instead of fighting it (this
# is different from the realistic moon photo, where feathering was
# explicitly rejected - that one had a graphic hard-cutout style to match).
SS = 4
mask_hi = Image.new("L", (W * SS, H * SS), 0)
ImageDraw.Draw(mask_hi).ellipse(
    [(cx - radius) * SS, (cy - radius) * SS, (cx + radius) * SS, (cy + radius) * SS], fill=255
)
mask = mask_hi.resize((W, H), Image.Resampling.BOX)
mask = mask.filter(ImageFilter.GaussianBlur(28))

out = im.copy()
out.putalpha(mask)

# Crop tight around the disc so the content fills the same fraction of the
# canvas as moon-base-fixed.png (0.94 of the half-canvas) - this photo's
# moon+glow only occupies ~72% of its own 1024px canvas, and both moon and
# overlay images share the same moonFillFactor display scale in QML, so
# without this the moon would render visibly smaller than the ring instead
# of slightly overhanging it.
TARGET_RATIO = 0.94
blur_margin = 28 * 2  # generous allowance for the gaussian feather's spread
content_r = radius + blur_margin
crop_half = content_r / TARGET_RATIO
left, top = cx - crop_half, cy - crop_half
right, bottom = cx + crop_half, cy + crop_half
out = out.crop((int(left), int(top), int(right), int(bottom)))

out.save(OUT_BASE)
print("saved", OUT_BASE, out.size)
