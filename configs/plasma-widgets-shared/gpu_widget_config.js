.pragma library

// Single source of truth shared between the QML widget (imported directly
// as a script module, see PieChart.qml) and the Python bake scripts (see
// widget_config.py, which parses this same file - keep the object literal
// on its own between the markers below valid JSON, since Python parses it
// with json.loads after stripping the JS wrapper).
var gpuWidgetConfig = {
    // Scale of the ring/tick overlay image specifically - the overlay's own
    // internal geometry (ring_outer_r etc. in bake_gpu_overlay.py) is
    // calibrated assuming this value, so don't change it to move the moon;
    // use moonImageScale for that instead (see below - they used to be the
    // same value, which meant nothing could ever change size *relative to*
    // the ring, only both together).
    "moonFillFactor": 1.15,
    // Scale of the moon image specifically, decoupled from moonFillFactor -
    // deliberately smaller than the ring so the moon reads as a distinct
    // glowing sphere with the ring floating around it (a halo/reticle look)
    // rather than the ring sitting on the moon's surface. Tune this to
    // adjust the gap.
    "moonImageScale": 0.85,
    "ringThicknessRatio": 0.041,
    "lightAnglePie": 225,
    "lightColorHex": "#CD1D71",
    "coldColorHex": "#04CEFC",
    "hotColorHex": "#FF5A1F",
    // Sampled directly from neon-moon-dreams-stockcake.jpg's own rim glow
    // (top and bottom) - the ring overlay's glow uses these, blended by
    // angle to match the moon's actual cyan-top/magenta-bottom gradient,
    // instead of the old lightAnglePie-based white/black bevel (which was
    // calibrated for a completely different wallpaper's light direction and
    // had no relationship to this moon's own colors).
    "moonCyanHex": "#08B4FA",
    "moonMagentaHex": "#FA0BEC"
}
