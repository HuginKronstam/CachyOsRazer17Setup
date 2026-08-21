import math
from PIL import Image, ImageDraw, ImageFilter
from widget_config import load_gpu_config, detect_gap, hex_to_rgb

MOON_BASE = "/home/hugin/.local/share/icons/hicolor/Custom/neon-moon-base.png"
OUT_PATH = "/home/hugin/.local/share/plasma-widgets-shared/gpu_overlay.png"

cfg = load_gpu_config()
ARC_FROM, ARC_TO = detect_gap()
CYAN = hex_to_rgb(cfg["moonCyanHex"])
MAGENTA = hex_to_rgb(cfg["moonMagentaHex"])


def pie_dir(angle_deg):
    a = math.radians(angle_deg)
    return math.sin(a), -math.cos(a)


def moon_color(angle_deg):
    """Blend cyan (top, 0deg) -> magenta (bottom, 180deg), matching the
    moon's own fixed gradient - not a directional light/shadow model, since
    the moon's glow isn't lit from one side, it's just always that color by
    angle. Symmetric left/right (both sides transition the same way)."""
    a = ((angle_deg % 360) + 360) % 360
    if a > 180:
        a = 360 - a
    t = a / 180.0
    return tuple(int(CYAN[i] + (MAGENTA[i] - CYAN[i]) * t) for i in range(3))


def in_arc(angle_deg):
    a = ((angle_deg + 180) % 360) - 180
    return ARC_FROM <= a <= ARC_TO


def bake(ring_thickness_ratio=None, out_path=OUT_PATH):
    """Renders the bevel + tick overlay. ring_thickness_ratio overrides
    cfg["ringThicknessRatio"] for generating comparison variants without
    touching the shared config."""
    moon = Image.open(MOON_BASE).convert("RGBA")
    W, H = moon.size
    cx, cy = W / 2, H / 2

    moon_fill_factor = cfg["moonFillFactor"]
    ring_outer_r = (W / moon_fill_factor) / 2
    thickness_ratio = ring_thickness_ratio if ring_thickness_ratio is not None else cfg["ringThicknessRatio"]
    ring_thickness = ring_outer_r * 2 * thickness_ratio
    ring_inner_r = ring_outer_r - ring_thickness

    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # ---- 1. Glowing ring: cyan->magenta edge glow + soft bloom halo ----
    # Replaces the old white/black directional bevel (calibrated for a
    # different wallpaper's light source, unrelated to this moon's own
    # colors) with glow that's actually made of the same cyan/magenta light
    # the moon glows with - the goal is "belongs to the same object," not "a
    # separate metal bezel sitting nearby."
    #
    # Edge-only (a thin band straddling the outer and inner true edges,
    # fading over `margin`), not a solid fill across the whole ring width -
    # the live wedge (usage/temp color, drawn separately by the actual
    # Charts.PieChart) needs to stay visible in the middle of the band. A
    # first pass filled the entire band solidly and completely hid it,
    # which looked like the widget's live functionality had stopped working.
    core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cpx = core.load()
    # Halved from 0.42 - at 0.42 per edge, the two edges together ate 84% of
    # the band's width, leaving only a 16% sliver for the live usage/temp
    # wedge to show through (hard to read the actual system load at a
    # glance). This leaves ~58% of the band clear instead.
    margin = ring_thickness * 0.21
    bbox_r = int(ring_outer_r + margin) + 2
    for yy in range(int(cy - bbox_r), int(cy + bbox_r)):
        for xx in range(int(cx - bbox_r), int(cx + bbox_r)):
            dx_, dy_ = xx - cx, yy - cy
            r = math.hypot(dx_, dy_)
            if r < ring_inner_r - margin or r > ring_outer_r + margin:
                continue
            ang = math.degrees(math.atan2(dx_, -dy_))
            if not in_arc(ang):
                continue
            edge_dist = min(abs(r - ring_outer_r), abs(r - ring_inner_r))
            if edge_dist > margin:
                continue
            alpha = int(255 * (1 - edge_dist / margin))
            cpx[xx, yy] = (*moon_color(ang), alpha)

    # Soft bloom: a blurred, brightened copy of the core sitting behind it,
    # so light bleeds outward/inward like the moon's own rim glow does,
    # instead of a crisp graphic edge.
    glow = core.filter(ImageFilter.GaussianBlur(ring_thickness * 0.45))
    glow_alpha = glow.split()[3].point(lambda a: min(255, int(a * 1.4)))
    glow.putalpha(glow_alpha)
    overlay.alpha_composite(glow)
    overlay.alpha_composite(core)
    draw = ImageDraw.Draw(overlay)

    # ---- 2. Tick marks around the outer edge, avoiding the gap ----
    tick_count = 32
    tick_span = 360 / tick_count
    for i in range(tick_count):
        ang = -180 + i * tick_span
        if not in_arc(ang):
            continue
        major = i % 4 == 0
        length = (ring_thickness * 0.5) if major else (ring_thickness * 0.3)
        dx_, dy_ = pie_dir(ang)
        r1 = ring_outer_r - ring_thickness * 0.15
        r2 = ring_outer_r + length
        x1, y1 = cx + r1 * dx_, cy + r1 * dy_
        x2, y2 = cx + r2 * dx_, cy + r2 * dy_
        tick_width = max(2, int(ring_thickness * (0.11 if major else 0.07)))
        draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 160 if major else 100), width=tick_width)

    overlay.save(out_path)
    print("saved", out_path, overlay.size, "ratio=", thickness_ratio)
    return overlay


if __name__ == "__main__":
    bake()
