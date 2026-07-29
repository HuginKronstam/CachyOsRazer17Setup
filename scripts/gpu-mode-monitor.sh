#!/bin/bash
################################################################################
# GPU Mode Monitor - watches for external monitor connect/disconnect and
# prompts (via gpu-mode-toggle.sh) to switch GPU mode to match.
#
# Detection reads /sys/class/drm/*/status directly, so it works the same
# regardless of X11 or Wayland session. Only re-prompts when the connected
# state actually changes (edge-triggered) - if you decline the prompt, it
# won't nag again until you plug/unplug the monitor again.
#
# Meant to run persistently as a systemd --user service
# (gpu-mode-monitor.service), started with the graphical session.
################################################################################

set -uo pipefail

STATE_FILE="$HOME/.cache/gpu-mode-monitor-last-state"
TOGGLE_SCRIPT="$HOME/.local/bin/gpu-mode-toggle.sh"

external_monitor_connected() {
    local f conn
    for f in /sys/class/drm/card*-*/status; do
        conn="$(basename "$(dirname "$f")")"
        case "$conn" in
        *eDP*) continue ;;
        esac
        [ "$(cat "$f" 2>/dev/null)" = "connected" ] && return 0
    done
    return 1
}

check_and_prompt() {
    local external="disconnected" desired_mode current_mode last_state=""

    external_monitor_connected && external="connected"

    [ -f "$STATE_FILE" ] && last_state=$(cat "$STATE_FILE")
    if [ "$external" = "$last_state" ]; then
        return # no change since last check - don't re-prompt
    fi
    echo "$external" >"$STATE_FILE"

    current_mode=$(envycontrol --query 2>/dev/null)
    if [ "$external" = "connected" ]; then
        desired_mode="nvidia"
    else
        desired_mode="hybrid"
    fi

    if [ "$current_mode" != "$desired_mode" ] && [ -x "$TOGGLE_SCRIPT" ]; then
        notify-send "GPU Mode" "External monitor $external - current mode is '$current_mode', recommended is '$desired_mode'"
        "$TOGGLE_SCRIPT"
    fi
}

mkdir -p "$(dirname "$STATE_FILE")"

# Prime the state file on startup without prompting for whatever state was
# already true when this service started (avoids prompting on every login)
if [ ! -f "$STATE_FILE" ]; then
    external="disconnected"
    external_monitor_connected && external="connected"
    echo "$external" >"$STATE_FILE"
fi

udevadm monitor --udev --subsystem-match=drm 2>/dev/null | while read -r line; do
    if echo "$line" | grep -q "change"; then
        sleep 1 # let sysfs settle after the event
        check_and_prompt
    fi
done
