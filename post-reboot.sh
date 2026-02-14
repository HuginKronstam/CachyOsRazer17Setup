#!/bin/bash

################################################################################
# CachyOS Post-Reboot Verification & Configuration Script
# For: Razer Blade 17 (Intel + NVIDIA RTX 3080 Mobile)
# Runs automatically on first login after main setup script
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_FILE="$SCRIPT_DIR/post-reboot.log"
AUTOSTART_FILE="$HOME/.config/autostart/cachyos-post-reboot.desktop"

# Track overall pass/fail
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}\n"
    echo "" >> "$LOG_FILE"
    echo "=== $1 ===" >> "$LOG_FILE"
}

print_section() {
    echo -e "\n${CYAN}── $1 ──${NC}"
    echo "-- $1 --" >> "$LOG_FILE"
}

pass() {
    echo -e "  ${GREEN}✓ $1${NC}"
    echo "  [PASS] $1" >> "$LOG_FILE"
    ((CHECKS_PASSED++))
}

fail() {
    echo -e "  ${RED}✗ $1${NC}"
    echo "  [FAIL] $1" >> "$LOG_FILE"
    ((CHECKS_FAILED++))
}

warn() {
    echo -e "  ${YELLOW}⚠ $1${NC}"
    echo "  [WARN] $1" >> "$LOG_FILE"
    ((CHECKS_WARNED++))
}

info() {
    echo -e "  ${BLUE}ℹ $1${NC}"
    echo "  [INFO] $1" >> "$LOG_FILE"
}

################################################################################
# X11 Session Guard
################################################################################

check_x11_session() {
    if [ "$XDG_SESSION_TYPE" = "x11" ]; then
        return 0
    else
        return 1
    fi
}

handle_wrong_session() {
    clear
    echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠  Wrong Session Type Detected             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Current session: ${RED}$XDG_SESSION_TYPE${NC}"
    echo -e "Required session: ${GREEN}x11${NC}"
    echo ""
    echo "This script must run under an X11 session to verify"
    echo "the NVIDIA GPU configuration correctly."
    echo ""
    echo "To fix this:"
    echo "  1. Log out"
    echo "  2. At the login screen, select your username"
    echo "  3. Look for session selector (gear icon, bottom corner)"
    echo "  4. Select 'Plasma (X11)'"
    echo "  5. Log back in - this script will run automatically"
    echo ""

    while true; do
        read -p "Would you like to reboot now to try again? [y/n] " choice
        case $choice in
            [Yy]*)
                echo ""
                echo "Rebooting in 5 seconds..."
                sleep 5
                sudo reboot
                ;;
            [Nn]*)
                echo ""
                echo "Okay. When you log in with X11, run this script manually:"
                echo "  $SCRIPT_DIR/post-reboot.sh"
                echo ""
                echo "Or it will run automatically on your next login."
                exit 0
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

################################################################################
# Verification Checks
################################################################################

verify_session() {
    print_section "Session Verification"
    
    local session_type="${XDG_SESSION_TYPE:-unknown}"
    info "Session type: $session_type"
    
    if [ "$session_type" = "x11" ]; then
        pass "Running in X11 session"
    else
        fail "Not running in X11 session (got: $session_type)"
    fi
}

verify_nvidia() {
    print_section "NVIDIA GPU"

    # Check nvidia-smi
    if nvidia-smi &>/dev/null; then
        local driver_ver
        driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null)
        pass "NVIDIA driver loaded (v$driver_ver)"
    else
        fail "nvidia-smi failed - NVIDIA driver not working"
    fi

    # Check GLX renderer
    local renderer
    renderer=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | awk -F': ' '{print $2}')
    if echo "$renderer" | grep -qi "nvidia"; then
        pass "GLX renderer: $renderer"
    elif [ -n "$renderer" ]; then
        fail "GLX using wrong renderer: $renderer (expected NVIDIA)"
    else
        fail "GLX renderer not detected (glxinfo failed)"
    fi

    # Check EnvyControl mode
    local envy_mode
    envy_mode=$(envycontrol --query 2>/dev/null || echo "unknown")
    if echo "$envy_mode" | grep -qi "nvidia"; then
        pass "EnvyControl mode: $envy_mode"
    else
        warn "EnvyControl mode: $envy_mode (expected nvidia)"
    fi

    # Check NVIDIA DRM modeset
    local modeset
    modeset=$(sudo cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo "unknown")
    if [ "$modeset" = "Y" ]; then
        pass "NVIDIA DRM modesetting enabled"
    else
        warn "NVIDIA DRM modesetting: $modeset (expected Y)"
    fi
}

verify_display() {
    print_section "Display Configuration"

    # Check connected displays
    local display_count
    display_count=$(xrandr 2>/dev/null | grep -c " connected")
    info "Connected displays: $display_count"

    if [ "$display_count" -ge 1 ]; then
        pass "At least one display detected"
        xrandr 2>/dev/null | grep " connected" | while read -r line; do
            info "  → $line"
        done
    else
        fail "No displays detected via xrandr"
    fi
}

verify_razer() {
    print_section "Razer Control"

    # Check daemon is running
    if systemctl --user is-active razercontrol.service &>/dev/null; then
        pass "Razer Control daemon is running"
    else
        warn "Razer Control daemon not running - attempting to start..."
        systemctl --user enable --now razercontrol.service 2>/dev/null \
            && pass "Razer Control daemon started" \
            || fail "Could not start Razer Control daemon"
    fi
}

verify_applications() {
    print_section "Installed Applications"

    local apps=(
        "brave:brave"
        "discord:discord"
        "steam:steam"
        "vlc:vlc"
        "code:Visual Studio Code"
        "obsidian:obsidian"
        "wezterm:wezterm"
        "envycontrol:EnvyControl"
        "nvidia-smi:NVIDIA SMI"
    )

    for entry in "${apps[@]}"; do
        local cmd="${entry%%:*}"
        local name="${entry##*:}"
        if command -v "$cmd" &>/dev/null; then
            pass "$name"
        else
            fail "$name (command '$cmd' not found)"
        fi
    done
}

verify_services() {
    print_section "System Services"

    local services=(
        "nvidia-suspend.service"
        "nvidia-hibernate.service"
        "nvidia-resume.service"
    )

    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            pass "$service enabled"
        else
            warn "$service not enabled"
        fi
    done
}

################################################################################
# Configuration
################################################################################

configure_kde_defaults() {
    print_section "KDE Default Applications"

    # Set WezTerm as default terminal
    if command -v wezterm &>/dev/null; then
        kwriteconfig5 --file kdeglobals --group General \
            --key TerminalApplication wezterm 2>/dev/null \
            && pass "WezTerm set as default terminal" \
            || warn "Could not set WezTerm as default terminal"
    else
        warn "WezTerm not found, skipping terminal default"
    fi

    # Set Brave as default browser
    if command -v brave &>/dev/null; then
        xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null \
            && pass "Brave set as default browser" \
            || warn "Could not set Brave as default browser"
    else
        warn "Brave not found, skipping browser default"
    fi
}

configure_razer_widget() {
    print_section "Razer Control KDE Widget"

    # Check if plasmoid is installed
    if kpackagetool6 --list --type Plasma/Applet 2>/dev/null | grep -qi "razer"; then
        pass "Razer Control plasmoid is installed"
        info "To add to panel: Right-click panel → Add Widgets → Search 'Razer'"
    else
        warn "Razer Control plasmoid not found in KDE"
        info "Try manually: cd $SCRIPT_DIR && git clone https://github.com/encomjp/razer-control-revived.git /tmp/razer-repo && cd /tmp/razer-repo/razer_control_gui/kde-widget && ./install-plasmoid.sh"
    fi
}

################################################################################
# GPU Stress Test
################################################################################

run_gpu_stress_test() {
    print_section "GPU Stress Test"

    # Check if glmark2 is available, install if not
    if ! command -v glmark2 &>/dev/null; then
        info "Installing glmark2 benchmark..."
        sudo pacman -S --noconfirm glmark2 2>/dev/null \
            && info "glmark2 installed" \
            || warn "Could not install glmark2, skipping stress test"
    fi

    if command -v glmark2 &>/dev/null; then
        info "Running GPU benchmark (30 seconds)..."
        info "Watch for smooth rendering and high FPS scores"
        echo ""

        # Run glmark2 with a subset of tests for speed
        local score
        score=$(glmark2 --run-forever=false 2>&1 | tail -5)
        
        if echo "$score" | grep -q "Score"; then
            pass "GPU benchmark completed"
            echo "$score" | while read -r line; do
                info "  $line"
            done
        else
            warn "GPU benchmark completed but score not detected"
            info "  Check output above for any rendering errors"
        fi
    fi
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_header "Post-Reboot Verification Summary"

    local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNED))

    echo -e "  Total checks: $total"
    echo -e "  ${GREEN}Passed:  $CHECKS_PASSED${NC}"
    echo -e "  ${YELLOW}Warnings: $CHECKS_WARNED${NC}"
    echo -e "  ${RED}Failed:  $CHECKS_FAILED${NC}"
    echo ""

    if [ "$CHECKS_FAILED" -eq 0 ] && [ "$CHECKS_WARNED" -eq 0 ]; then
        echo -e "${GREEN}✓ Everything looks great! Your system is fully configured.${NC}"
    elif [ "$CHECKS_FAILED" -eq 0 ]; then
        echo -e "${YELLOW}⚠ Setup complete with some warnings. Check the log for details.${NC}"
    else
        echo -e "${RED}✗ Some checks failed. Review the log and fix issues.${NC}"
    fi

    echo ""
    echo -e "Full log saved to: ${BLUE}$LOG_FILE${NC}"
    echo ""
    echo "Quick reference:"
    echo "  envycontrol --query              # Current GPU mode"
    echo "  sudo envycontrol -s hybrid       # Switch to hybrid (battery)"
    echo "  sudo envycontrol -s nvidia       # Switch to NVIDIA only (gaming)"
    echo "  nvidia-smi                       # GPU status"
    echo "  systemctl --user status razercontrol.service  # Razer daemon"
    echo ""
}

################################################################################
# Cleanup - Remove autostart entry on success
################################################################################

cleanup_autostart() {
    if [ "$CHECKS_FAILED" -eq 0 ]; then
        rm -f "$AUTOSTART_FILE"
        info "Autostart entry removed (won't run again on login)"
    else
        warn "Autostart entry kept - script will run again on next login"
        warn "Fix the failed checks above, then delete manually if needed:"
        warn "  rm $AUTOSTART_FILE"
    fi
}

################################################################################
# Entry Point
################################################################################

# Initialize log
echo "=== CachyOS Post-Reboot Log - $(date) ===" > "$LOG_FILE"

# Check X11 session first - bail out if wrong session
if ! check_x11_session; then
    handle_wrong_session
fi

# All good - run the script
clear
print_header "CachyOS Post-Reboot Verification"
echo "Running verification checks and applying final configuration..."
echo "This should only take a minute or two."
echo ""

# Verifications
verify_session
verify_nvidia
verify_display
verify_razer
verify_applications
verify_services

# Configuration
configure_kde_defaults
configure_razer_widget

# GPU stress test
run_gpu_stress_test

# Summary and cleanup
print_summary
cleanup_autostart

read -p "Press Enter to close..."
