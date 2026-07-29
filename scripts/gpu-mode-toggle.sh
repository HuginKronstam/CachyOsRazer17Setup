#!/bin/bash
################################################################################
# GPU Mode Toggle - nvidia (docked/external monitor) <-> hybrid (mobile)
#
# Meant to be bound to a KDE global shortcut. Since EnvyControl mode
# switches require a reboot, this can't be an instant/silent toggle - it
# confirms before switching, then offers to reboot immediately after.
#
# Uses pkexec (not sudo) so it can prompt for a password via the KDE
# polkit agent when triggered from a hotkey with no terminal attached.
################################################################################

set -uo pipefail

CURRENT_MODE=$(envycontrol --query 2>/dev/null)

case "$CURRENT_MODE" in
    nvidia)
        TARGET_MODE="hybrid"
        TARGET_LABEL="Hybrid (mobile, battery saving, PRIME offload)"
        ;;
    hybrid | integrated)
        TARGET_MODE="nvidia"
        TARGET_LABEL="NVIDIA (docked, external monitor, dGPU always on)"
        ;;
    *)
        notify-send -u critical "GPU Mode Switch" "Could not determine current EnvyControl mode (got: '$CURRENT_MODE')"
        exit 1
        ;;
esac

if ! kdialog --title "GPU Mode Switch" --yesno \
    "Switch GPU mode: $CURRENT_MODE -> $TARGET_MODE\n\n$TARGET_LABEL\n\nThis requires a reboot to take effect."; then
    exit 0
fi

if [ "$TARGET_MODE" = "hybrid" ]; then
    pkexec envycontrol -s hybrid --dm sddm --rtd3 2
else
    pkexec envycontrol -s "$TARGET_MODE" --dm sddm
fi
SWITCH_STATUS=$?

if [ "$SWITCH_STATUS" -ne 0 ]; then
    notify-send -u critical "GPU Mode Switch" "Failed to switch to $TARGET_MODE mode (exit $SWITCH_STATUS) - check envycontrol output"
    exit 1
fi

notify-send "GPU Mode Switch" "Switched to $TARGET_LABEL.\nReboot required to take effect."

if kdialog --title "GPU Mode Switch" --yesno "Reboot now to apply $TARGET_MODE mode?"; then
    systemctl reboot
fi
