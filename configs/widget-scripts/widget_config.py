"""Shared config loading for the bake_*.py scripts - single source of truth
(gpu_widget_config.js) instead of hand-copied constants duplicated across
scripts and QML, which drift out of sync silently. See PieChart.qml, which
imports the same file directly as a QML script module (a plain JSON file
can't be loaded there - local-file XMLHttpRequest is disabled by default in
Qt6 and not worth re-enabling just for this).
"""
import json
import re

CONFIG_PATH = "/home/hugin/.local/share/plasma-widgets-shared/gpu_widget_config.js"
APPLETSRC_PATH = "/home/hugin/.config/plasma-org.kde.plasma.desktop-appletsrc"


def load_gpu_config():
    with open(CONFIG_PATH) as f:
        text = f.read()
    # Strip // line comments (valid JS, not valid JSON) before parsing -
    # careful not to eat "//" inside string values like hex colors, though
    # none currently contain it.
    text = re.sub(r"(?m)^\s*//.*$", "", text)
    # Strip the .pragma library line and "var gpuWidgetConfig = " prefix,
    # leaving a plain JSON object literal.
    match = re.search(r"var\s+gpuWidgetConfig\s*=\s*(\{.*\})\s*$", text, re.DOTALL)
    if not match:
        raise ValueError(f"could not find gpuWidgetConfig object in {CONFIG_PATH}")
    return json.loads(match.group(1))


def detect_gap(chart_face="local.piechart.gputhermal"):
    """Auto-detect the currently configured fromAngle/toAngle for the given
    chart face directly from appletsrc, instead of requiring them to be
    hand-copied into a script and going stale. Falls back to the kcfg
    defaults (-180/180, i.e. no gap) if not explicitly set."""
    with open(APPLETSRC_PATH) as f:
        text = f.read()
    pattern = re.compile(
        r"\[.*\[Configuration\]\[" + re.escape(chart_face) + r"\]\[General\]\n(.*?)(?:\n\[|\Z)",
        re.DOTALL,
    )
    match = pattern.search(text)
    from_angle, to_angle = -180, 180
    if match:
        block = match.group(1)
        fa = re.search(r"^fromAngle=(-?\d+)", block, re.MULTILINE)
        ta = re.search(r"^toAngle=(-?\d+)", block, re.MULTILINE)
        if fa:
            from_angle = int(fa.group(1))
        if ta:
            to_angle = int(ta.group(1))
    return from_angle, to_angle


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
