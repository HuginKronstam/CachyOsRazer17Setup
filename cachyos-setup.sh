#!/bin/bash

################################################################################
# CachyOS Post-Installation Setup Script
# For: Razer Blade 17 (Intel + NVIDIA RTX 3080 Mobile)
# DE: KDE Plasma (X11)
################################################################################

# Don't exit on errors - handle them explicitly per step
set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Interactive mode flag
INTERACTIVE=false

# Script directory (so configs are found regardless of where script is run from)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Log file (gitignored, records warnings/errors from last run)
LOG_FILE="$SCRIPT_DIR/last-run.log"

# Local Obsidian vault location, used by the Proton Drive backup/restore
# menu options. Edit this if your vault moves or is renamed.
OBSIDIAN_VAULT_DIR="$HOME/Documents/Obsidian/Hugins Saga"

# Marker file (gitignored) whose mtime is the timestamp of the last
# successful Proton Drive backup. Used to find changed files for
# incremental backups instead of re-uploading the whole vault every time.
PROTON_BACKUP_MARKER="$SCRIPT_DIR/.proton-obsidian-backup-marker"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
    echo "" >> "$LOG_FILE"
    echo "=== $1 ===" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo "[OK] $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    echo "[WARN] $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    echo "[INFO] $1" >> "$LOG_FILE"
}

ask_continue() {
    local step_name="$1"
    local explanation="$2"

    if [ "$INTERACTIVE" = true ]; then
        echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Next Step: $step_name${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "\n$explanation\n"

        while true; do
            read -p "Continue with this step? [Y/n/q] " response
            case $response in
                [Yy]* | "" ) return 0;;
                [Nn]* ) print_warning "Skipping step: $step_name"; return 1;;
                [Qq]* ) print_info "Exiting script."; exit 0;;
                * ) echo "Please answer y, n, or q.";;
            esac
        done
    fi
    return 0
}

################################################################################
# Backup Configs Function
################################################################################

backup_configs() {
    print_header "Backing Up System Configurations"

    BACKUP_DIR="$SCRIPT_DIR/configs"

    print_info "Backup location: $BACKUP_DIR"
    echo ""

    # Create backup directories
    mkdir -p "$BACKUP_DIR"/{wezterm,kde,obsidian,vscode,vivaldi}

    # Backup WezTerm
    if [ -f ~/.config/wezterm/wezterm.lua ]; then
        print_info "Backing up WezTerm config..."
        cp ~/.config/wezterm/wezterm.lua "$BACKUP_DIR/wezterm/"
        print_success "WezTerm config backed up"
    else
        print_warning "WezTerm config not found, skipping"
    fi

    # Backup KDE configs
    print_info "Backing up KDE configurations..."
    KDE_CONFIGS=(
        "kdeglobals"
        "kwinrc"
        "kwinrulesrc"
        "kglobalshortcutsrc"
        "plasma-localerc"
        "kscreenlockerrc"
        "plasmashellrc"
        "plasma-org.kde.plasma.desktop-appletsrc"
        "mimeapps.list"
    )

    for config in "${KDE_CONFIGS[@]}"; do
        if [ -f ~/.config/"$config" ]; then
            cp ~/.config/"$config" "$BACKUP_DIR/kde/"
            print_success "Backed up $config"
        else
            print_warning "$config not found, skipping"
        fi
    done

    # Backup Obsidian (entire directory)
    if [ -d ~/.config/obsidian ]; then
        print_info "Backing up Obsidian config..."
        cp -r ~/.config/obsidian/* "$BACKUP_DIR/obsidian/" 2>/dev/null || true
        print_success "Obsidian config backed up"
    else
        print_warning "Obsidian config not found, skipping"
    fi

    # Backup VS Code settings
    if [ -f ~/.config/Code/User/settings.json ]; then
        print_info "Backing up VS Code settings..."
        cp ~/.config/Code/User/settings.json "$BACKUP_DIR/vscode/"
        print_success "VS Code settings backed up"
    else
        print_warning "VS Code settings not found, skipping"
    fi

    # Backup Vivaldi (bookmarks, preferences, extensions state, etc. -
    # excludes cache, cookies, and saved logins)
    if [ -d ~/.config/vivaldi ]; then
        print_info "Backing up Vivaldi config (excluding cache, cookies, login data)..."
        command -v rsync &>/dev/null || sudo pacman -S --noconfirm --needed rsync
        rsync -a \
            --exclude='*[Cc]ache*' \
            --exclude='*Cookies*' \
            --exclude='*Login Data*' \
            --exclude='Singleton*' \
            ~/.config/vivaldi/ "$BACKUP_DIR/vivaldi/" 2>/dev/null || true
        print_success "Vivaldi config backed up"
    else
        print_warning "Vivaldi config not found, skipping"
    fi

    echo ""
    print_success "Backup completed!"
    print_info "Configs saved to: $BACKUP_DIR"
    echo ""
    print_info "To commit these changes to git:"
    echo "  cd $SCRIPT_DIR"
    echo "  git add configs/"
    echo "  git commit -m \"Update configs from $(date +%Y-%m-%d)\""
    echo "  git push"
    echo ""
}

################################################################################
# Proton Drive - Obsidian Vault Backup/Restore
################################################################################
# Uploads/downloads the vault as a whole folder, so the remote path mirrors
# the local folder name: OBSIDIAN_VAULT_DIR uploads into /my-files, and
# comes back down from /my-files/<vault folder name>.

backup_obsidian_to_proton() {
    print_header "Backing Up Obsidian Vault to Proton Drive"

    if ! command -v proton-drive &>/dev/null; then
        print_error "proton-drive CLI not found"
        print_info "Install it via Setup System, or manually: yay -S proton-drive-cli-bin"
        return 1
    fi

    if [ ! -d "$OBSIDIAN_VAULT_DIR" ]; then
        print_error "Obsidian vault not found at: $OBSIDIAN_VAULT_DIR"
        print_info "Edit OBSIDIAN_VAULT_DIR near the top of this script if your vault has moved"
        return 1
    fi

    local vault_name start_time
    vault_name="$(basename "$OBSIDIAN_VAULT_DIR")"
    start_time=$(date +%s.%N)

    print_info "Local vault:  $OBSIDIAN_VAULT_DIR"
    print_info "Remote path:  /my-files/$vault_name"

    if [ ! -f "$PROTON_BACKUP_MARKER" ]; then
        # First backup ever - no marker to diff against, so upload
        # everything once. This also creates the remote folder structure
        # that later incremental runs upload individual files into.
        print_info "No previous backup found - uploading the full vault (first run only)"
        echo ""
        print_warning "Files that differ will be REPLACED on Proton Drive with your local versions."
        read -p "Continue with upload? [y/N] " confirm
        case $confirm in
            [Yy]*) ;;
            *) print_info "Backup cancelled"; return 0 ;;
        esac

        if proton-drive filesystem upload --file-conflict-strategy replace \
            --folder-conflict-strategy merge --skip-thumbnails \
            "$OBSIDIAN_VAULT_DIR" /my-files; then
            touch -d "@$start_time" "$PROTON_BACKUP_MARKER"
            print_success "Obsidian vault backed up to Proton Drive (/my-files/$vault_name)"
        else
            print_error "Backup failed - if this is the first run, sign in first: proton-drive auth login"
            return 1
        fi
        return 0
    fi

    # Incremental run - only upload files modified since the last
    # successful backup, instead of re-uploading/replacing everything.
    local changed_files=()
    while IFS= read -r -d '' file; do
        changed_files+=("$file")
    done < <(find "$OBSIDIAN_VAULT_DIR" -type f -newer "$PROTON_BACKUP_MARKER" -print0)

    if [ ${#changed_files[@]} -eq 0 ]; then
        print_success "Nothing changed since the last backup - skipping upload"
        return 0
    fi

    local file rel_path
    print_info "${#changed_files[@]} file(s) changed since the last backup:"
    for file in "${changed_files[@]}"; do
        rel_path="${file#"$OBSIDIAN_VAULT_DIR"/}"
        echo "    $rel_path"
    done
    echo ""
    print_warning "These files will be REPLACED on Proton Drive with your local versions."
    read -p "Continue with upload? [y/N] " confirm
    case $confirm in
        [Yy]*) ;;
        *) print_info "Backup cancelled"; return 0 ;;
    esac

    local fail=0 rel_dir remote_parent
    for file in "${changed_files[@]}"; do
        rel_path="${file#"$OBSIDIAN_VAULT_DIR"/}"
        rel_dir="$(dirname "$rel_path")"
        if [ "$rel_dir" = "." ]; then
            remote_parent="/my-files/$vault_name"
        else
            remote_parent="/my-files/$vault_name/$rel_dir"
        fi

        if proton-drive filesystem upload --file-conflict-strategy replace \
            --skip-thumbnails "$file" "$remote_parent"; then
            continue
        fi

        if [ "$rel_dir" != "." ]; then
            # Single-file upload failed - most likely the parent folder
            # doesn't exist on Proton Drive yet (e.g. a brand new
            # top-level folder). Retry by uploading the whole parent
            # folder, which recursively creates any missing structure.
            print_warning "Retrying as a folder upload: $rel_dir"
            local grandparent_dir grandparent_remote
            grandparent_dir="$(dirname "$rel_dir")"
            if [ "$grandparent_dir" = "." ]; then
                grandparent_remote="/my-files/$vault_name"
            else
                grandparent_remote="/my-files/$vault_name/$grandparent_dir"
            fi
            if proton-drive filesystem upload --file-conflict-strategy replace \
                --folder-conflict-strategy merge --skip-thumbnails \
                "$OBSIDIAN_VAULT_DIR/$rel_dir" "$grandparent_remote"; then
                continue
            fi
        fi

        print_error "Failed to upload: $rel_path"
        fail=1
    done

    if [ "$fail" -eq 0 ]; then
        touch -d "@$start_time" "$PROTON_BACKUP_MARKER"
        print_success "Uploaded ${#changed_files[@]} changed file(s) to Proton Drive"
    else
        print_warning "Some files failed to upload - marker not updated, they'll be retried next time"
    fi
}

restore_obsidian_from_proton() {
    print_header "Restoring Obsidian Vault from Proton Drive"

    if ! command -v proton-drive &>/dev/null; then
        print_error "proton-drive CLI not found"
        print_info "Install it via Setup System, or manually: yay -S proton-drive-cli-bin"
        return 1
    fi

    local vault_name vault_parent
    vault_name="$(basename "$OBSIDIAN_VAULT_DIR")"
    vault_parent="$(dirname "$OBSIDIAN_VAULT_DIR")"

    print_info "Remote path:  /my-files/$vault_name"
    print_info "Local vault:  $OBSIDIAN_VAULT_DIR"
    echo ""
    print_warning "Local files that differ will be REPLACED with the Proton Drive versions."
    print_warning "Any local changes not yet backed up will be lost."
    read -p "Continue with download? [y/N] " confirm
    case $confirm in
        [Yy]*) ;;
        *) print_info "Restore cancelled"; return 0 ;;
    esac

    mkdir -p "$vault_parent"

    if proton-drive filesystem download --file-conflict-strategy replace \
        --folder-conflict-strategy merge \
        "/my-files/$vault_name" "$vault_parent"; then
        print_success "Obsidian vault restored from Proton Drive to $OBSIDIAN_VAULT_DIR"
    else
        print_error "Restore failed - if this is the first run, sign in first: proton-drive auth login"
    fi
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   CachyOS Razer 17 Setup Script       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Setup System"
    echo "2) Backup Configs"
    echo "3) Backup Obsidian Vault to Proton Drive"
    echo "4) Restore Obsidian Vault from Proton Drive"
    echo "5) Exit"
    echo ""
}

################################################################################
# Main Script Entry Point
################################################################################

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root or with sudo."
    echo "The script will ask for your password when needed."
    exit 1
fi

# Initialize log file
echo "=== CachyOS Setup Log - $(date) ===" > "$LOG_FILE"
echo "Script directory: $SCRIPT_DIR" >> "$LOG_FILE"

# Main menu loop
while true; do
    show_menu
    read -p "Select option: " choice

    case $choice in
        1)
            # Setup System
            echo ""
            read -p "Run in interactive mode? [y/N] " interactive_choice
            case $interactive_choice in
                [Yy]*)
                    INTERACTIVE=true
                    print_info "Running in INTERACTIVE mode"
                    ;;
                *)
                    INTERACTIVE=false
                    print_info "Running in AUTOMATIC mode"
                    ;;
            esac
            echo ""
            read -p "Press Enter to begin setup..."
            break
            ;;
        2)
            # Backup Configs
            backup_configs
            read -p "Press Enter to return to menu..."
            ;;
        3)
            # Backup Obsidian Vault to Proton Drive
            backup_obsidian_to_proton
            read -p "Press Enter to return to menu..."
            ;;
        4)
            # Restore Obsidian Vault from Proton Drive
            restore_obsidian_from_proton
            read -p "Press Enter to return to menu..."
            ;;
        5)
            # Exit
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option, please try again"
            sleep 2
            ;;
    esac
done

################################################################################
# System Setup Starts Here
################################################################################

print_header "CachyOS Setup Script Starting"

if [ "$INTERACTIVE" = true ]; then
    print_info "Running in INTERACTIVE mode"
    echo "You'll be asked before each step and can skip or quit at any time."
else
    print_info "Running in AUTOMATIC mode"
    echo "All steps will run automatically."
fi

################################################################################
# STEP 1: System Update
################################################################################

if ask_continue "System Update" \
"This step updates all packages on your system to the latest versions.

CachyOS uses pacman as its package manager. We'll run:
  - 'pacman -Syu' to synchronize package databases and upgrade all packages

This is crucial for a fresh install to ensure you have the latest:
  - Security patches
  - Bug fixes
  - Feature updates
  - Kernel updates

This may take several minutes depending on your internet speed and how
outdated your installation media was."; then

    print_header "Step 1: Updating System"
    sudo pacman -Syu --noconfirm
    print_success "System updated successfully"
fi

################################################################################
# STEP 2: Install/Verify NVIDIA Drivers
################################################################################

if ask_continue "NVIDIA Driver Installation/Verification" \
"This step ensures NVIDIA drivers are properly installed.

Your system has:
  - Intel UHD Graphics (integrated)
  - NVIDIA RTX 3080 Mobile (discrete)

CachyOS often pre-installs NVIDIA drivers. We'll check if you already
have drivers and only install if needed.

Packages we need:
  - nvidia driver (DKMS or pre-compiled kernel module)
  - nvidia-utils: NVIDIA utilities and libraries
  - lib32-nvidia-utils: 32-bit support (needed for many games)
  - nvidia-settings: GUI tool to configure NVIDIA settings

If drivers are already installed, we'll just verify them and move on."; then

    print_header "Step 2: Checking NVIDIA Drivers"

    # Check if NVIDIA drivers are already installed
    if pacman -Qi nvidia-utils &>/dev/null || pacman -Qi nvidia-open &>/dev/null; then
        NVIDIA_VERSION=$(pacman -Qi nvidia-utils 2>/dev/null | grep Version | awk '{print $3}' || echo "installed")
        print_success "NVIDIA drivers already installed (version: $NVIDIA_VERSION)"
        print_info "Skipping driver installation"

        # Make sure we have nvidia-settings and lib32 utils
        print_info "Ensuring additional NVIDIA packages are installed..."
        sudo pacman -S --noconfirm --needed lib32-nvidia-utils nvidia-settings 2>/dev/null || true

    else
        print_info "No NVIDIA drivers found, installing..."

        # Let user choose which driver version
        echo ""
        print_warning "Multiple NVIDIA driver versions are available."
        echo "For RTX 3080 Mobile, any of these will work:"
        echo "  1) Latest/newest drivers (recommended for best performance)"
        echo "  2) Specific version if you had issues with latest"
        echo ""

        if [ "$INTERACTIVE" = true ]; then
            echo "We'll use the default (latest) unless you prefer otherwise."
            sudo pacman -S --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
        else
            # In non-interactive mode, just accept defaults
            yes "" | sudo pacman -S --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
        fi

        print_success "NVIDIA drivers installed"
    fi
fi

################################################################################
# STEP 3: Install and Configure X11
################################################################################

if ask_continue "Install X11 and Set as Default" \
"This step installs X11 (Xorg) display server and sets it as default.

Why X11 instead of Wayland for your setup?
  - Better NVIDIA multi-monitor support
  - No refresh rate sync issues with mixed displays (360Hz laptop + 144Hz external)
  - More stable for gaming with external monitors
  - Better performance in many games

We'll install:
  - xorg-server: The X11 display server
  - xorg-xinit: X11 initialization utilities
  - xf86-input-libinput: Modern input driver for X11
  - plasma-x11-session: KDE Plasma X11 session files (required!)

Then configure SDDM (login manager) to default to X11 session.

You can always switch back to Wayland at login if you want to test it later."; then

    print_header "Step 3: Installing X11"

    # Install X11 packages including Plasma X11 session
    print_info "Installing X11 packages and Plasma X11 session..."
    sudo pacman -S --noconfirm --needed xorg-server xorg-xinit xf86-input-libinput plasma-x11-session
    print_success "X11 packages installed"

    # Set X11 as default session in SDDM
    print_info "Configuring SDDM to default to X11 session..."

    # Create SDDM config directory if it doesn't exist
    sudo mkdir -p /etc/sddm.conf.d

    # Configure SDDM to use X11 by default
    cat << 'EOF' | sudo tee /etc/sddm.conf.d/default-session.conf > /dev/null
[General]
# Set Plasma X11 as default session
Session=plasmax11
EOF

    # Configure GLX vendor for NVIDIA
    print_info "Configuring GLX vendor for NVIDIA..."
    sudo mkdir -p /usr/share/glvnd/glx_vendor.d/
    cat << 'EOF' | sudo tee /usr/share/glvnd/glx_vendor.d/10-nvidia.json > /dev/null
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "libGLX_nvidia.so.0"
    }
}
EOF

    print_success "X11 installed and set as default session"
    print_info "GLX vendor configured for NVIDIA"
    print_info "X11 Optimus configuration will be handled by EnvyControl in the next step"
    print_info "After reboot, you'll automatically login to Plasma X11"
    print_info "To switch to Wayland: select 'Plasma (Wayland)' at login screen"
fi

################################################################################
# STEP 4: Install YAY (AUR Helper)
################################################################################

if ask_continue "Install YAY AUR Helper" \
"This step installs YAY, an AUR (Arch User Repository) helper.

The AUR contains community-maintained packages not in official repos.
Many popular applications are only available through AUR.

YAY helps you:
  - Search and install AUR packages easily
  - Automatically handle dependencies
  - Update AUR packages alongside system packages

We'll install 'yay' from the CachyOS repositories (it's pre-packaged).

YAY is needed early since EnvyControl and other tools come from AUR."; then

    print_header "Step 4: Installing YAY"

    if ! command -v yay &> /dev/null; then
        sudo pacman -S --noconfirm yay
        print_success "YAY installed successfully"
    else
        print_warning "YAY is already installed, skipping"
    fi
fi

################################################################################
# STEP 5: Install EnvyControl and Configure GPU
################################################################################

if ask_continue "Install EnvyControl and Configure GPU Mode" \
"This step installs EnvyControl, a tool for managing GPU modes on
NVIDIA Optimus laptops (Intel + NVIDIA hybrid systems), plus the
power-related pieces the CachyOS wiki recommends for hybrid-GPU
laptops (https://wiki.cachyos.org/configuration/dual_gpu/).

GPU Modes available:
  - integrated: Intel GPU only (maximum battery life)
  - hybrid:     Both GPUs, NVIDIA used on-demand via PRIME offload (balanced)
  - nvidia:     NVIDIA GPU only, always on (maximum performance, worst battery)

We'll set 'hybrid' mode. This is what CachyOS recommends by default:
the RTX 3080 stays powered off until something explicitly asks for it
(prime-run, a Steam launch option, or KDE's 'Run using dedicated
graphics card' right-click option), then powers back down when idle.
Forcing 'nvidia' mode instead keeps the dGPU on permanently, which
measurably drains battery even at idle.

Also installed in this step:
  - nvidia-prime: adds the 'prime-run <program>' shortcut for forcing
    a specific app onto the NVIDIA GPU
  - switcheroo-control: powers KDE's per-app 'Run using dedicated
    graphics card' checkbox in hybrid mode
  - thermald: Intel thermal management daemon, applies CPU power/perf
    limits before the firmware has to throttle aggressively

⚠️  EnvyControl will manage /etc/X11/xorg.conf and related files.
    Do not manually edit these files after this step.

To switch modes later:
  sudo envycontrol -s hybrid     # Default - battery saving, PRIME offload
  sudo envycontrol -s nvidia     # Gaming/external monitor, dGPU always on
  sudo envycontrol -s integrated # Maximum battery, dGPU fully off
  (Requires reboot after switching)"; then

    print_header "Step 5: Installing EnvyControl"

    # Install envycontrol from AUR
    print_info "Installing EnvyControl from AUR..."
    yay -S --noconfirm envycontrol

    # nvidia-prime gives us the 'prime-run' wrapper for PRIME offload
    print_info "Installing nvidia-prime for PRIME render offload..."
    sudo pacman -S --noconfirm --needed nvidia-prime

    # switcheroo-control powers KDE's per-app dGPU toggle
    print_info "Installing and enabling switcheroo-control..."
    sudo pacman -S --noconfirm --needed switcheroo-control
    sudo systemctl enable --now switcheroo-control.service

    # thermald manages Intel thermal limits before the firmware throttles
    print_info "Installing and enabling thermald..."
    sudo pacman -S --noconfirm --needed thermald
    sudo systemctl enable --now thermald.service

    # Enable nvidia-drm modesetting (EnvyControl doesn't manage this)
    print_info "Configuring NVIDIA kernel module options..."
    echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee -a /etc/modprobe.d/nvidia.conf > /dev/null

    # Set hybrid mode - dGPU sleeps until something requests it via PRIME offload
    print_info "Setting GPU mode to hybrid (PRIME offload)..."
    sudo envycontrol -s hybrid --dm sddm

    print_success "EnvyControl installed and GPU set to hybrid mode"
    print_info "Use 'prime-run <program>' or KDE's per-app toggle to run something on the RTX 3080"
    print_info "To switch modes: sudo envycontrol -s [integrated|hybrid|nvidia]"
fi

################################################################################
# STEP 6: Update Initramfs
################################################################################

if ask_continue "Rebuild Initramfs" \
"This step rebuilds the initial ramdisk (initramfs).

The initramfs is loaded by the bootloader before the main system boots.
It contains essential drivers and modules needed during early boot.

We need to rebuild it to include:
  - New NVIDIA driver modules
  - Updated kernel module options set by EnvyControl

Without this, your GPU configuration changes won't take effect
until you manually rebuild it later.

Command: 'mkinitcpio -P' rebuilds initramfs for all installed kernels."; then

    print_header "Step 6: Rebuilding Initramfs"
    sudo mkinitcpio -P
    print_success "Initramfs rebuilt with new NVIDIA configuration"
fi

################################################################################
# STEP 7: Install Gaming Meta Package
################################################################################

if ask_continue "Install Gaming Meta Package" \
"This step installs 'cachyos-gaming-meta', a meta-package with gaming tools.

This package bundles:
  - GameMode: Optimizes system performance for games
  - MangoHud: In-game performance overlay (FPS, CPU, GPU usage)
  - Vulkan drivers and tools
  - Wine dependencies for Windows games
  - Other gaming-related optimizations

Meta-packages are convenient bundles that install multiple related
packages at once. This ensures you have a complete gaming setup."; then

    print_header "Step 7: Installing Gaming Meta Package"
    sudo pacman -S --noconfirm cachyos-gaming-meta
    print_success "Gaming meta package installed"
fi

################################################################################
# STEP 8: Install Applications
################################################################################

if ask_continue "Install Applications" \
"This step installs your requested applications:

  - discord: Voice, video, and text chat for communities
  - vivaldi: Power-user focused web browser (from official repo)
  - vivaldi-ffmpeg-codecs: Proprietary codec support for Vivaldi
  - bitwarden: Password manager
  - steam: Gaming platform
  - vlc: Media player
  - visual-studio-code-bin: Code editor (from AUR)
  - obsidian: Note-taking and knowledge base (from AUR)
  - wezterm: GPU-accelerated terminal emulator (from AUR)
  - ttf-ibmplex-mono-nerd: BlexMono Nerd Font (for WezTerm, from official repo)
  - antigravity: Google's agentic AI IDE (from AUR)
  - razer-control-revived: Razer hardware control (fan, RGB, battery, power)
  - razer-control KDE widget: Panel widget for quick Razer hardware access

Razer Control Revived provides:
  - Fan speed control
  - Keyboard RGB lighting
  - Battery charge limit (extends battery lifespan)
  - Real-time CPU/GPU power monitoring
  - KDE Plasma widget for panel integration

Note: Antigravity requires a Google account to sign in after install.
      It may occasionally show 'version outdated' - run 'yay -Syu' to update.

This may take 15-25 minutes depending on your system and internet speed."; then

    print_header "Step 8: Installing Applications"

    # Define packages
    OFFICIAL_PACKAGES="discord steam vlc ttf-ibmplex-mono-nerd vivaldi vivaldi-ffmpeg-codecs"
    AUR_PACKAGES="bitwarden visual-studio-code-bin obsidian wezterm antigravity"

    # Install official packages
    print_info "Installing packages from official repositories..."
    sudo pacman -S --noconfirm $OFFICIAL_PACKAGES

    # Install AUR packages
    print_info "Installing packages from AUR (this may take a while)..."
    yay -S --noconfirm $AUR_PACKAGES

    # Install Razer Control Revived from GitHub releases tarball
    print_info "Installing Razer Control Revived..."
    RAZER_VERSION="0.2.8"
    RAZER_TARBALL="razer-control-0.2.7-x86_64.tar.gz"
    RAZER_URL="https://github.com/encomjp/razer-control-revived/releases/download/v${RAZER_VERSION}/${RAZER_TARBALL}"
    RAZER_TMP="/tmp/razer-control"

    mkdir -p "$RAZER_TMP"
    print_info "Downloading Razer Control Revived v${RAZER_VERSION}..."
    curl -L "$RAZER_URL" -o "$RAZER_TMP/$RAZER_TARBALL"

    print_info "Extracting and installing daemon..."
    tar xzf "$RAZER_TMP/$RAZER_TARBALL" -C "$RAZER_TMP"

    # Run install.sh as normal user - it calls sudo internally where needed
    (
        cd "$RAZER_TMP/razer-control-0.2.7-x86_64" || exit 1
        bash ./install.sh
    ) || print_warning "Razer Control daemon install had issues - may need manual install"

    # Install KDE Plasma widget from source repo
    print_info "Installing Razer Control KDE Plasma widget..."
    RAZER_REPO_TMP="/tmp/razer-control-repo"

    # Remove any previous clone attempt
    rm -rf "$RAZER_REPO_TMP"
    git clone https://github.com/encomjp/razer-control-revived.git "$RAZER_REPO_TMP"

    # Run plasmoid install in a subshell
    (
        cd "$RAZER_REPO_TMP/razer_control_gui/kde-widget" || exit 1
        chmod +x install-plasmoid.sh
        ./install-plasmoid.sh
    ) || print_warning "Razer Control widget install had issues - may need manual install"

    # Note: razercontrol.service is enabled by install.sh automatically
    # If it fails before reboot, it will be available after reboot
    print_info "Razer Control daemon installed - will be active after reboot"
    systemctl --user enable razercontrol.service 2>/dev/null \
        || print_info "Razer service will activate on next login (normal before reboot)"

    # Add udev rule for CPU power reading
    print_info "Adding udev rule for CPU power monitoring..."
    echo 'ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", RUN+="/bin/chmod a+r /sys/class/powercap/intel-rapl:0/energy_uj"' \
        | sudo tee /etc/udev/rules.d/99-rapl-readable.rules > /dev/null
    sudo udevadm control --reload-rules && sudo udevadm trigger

    # Cleanup
    rm -rf "$RAZER_TMP" "$RAZER_REPO_TMP"

    print_success "All applications installed successfully"
    print_info "Razer Control widget: Right-click panel → Add Widgets → Search 'Razer Control'"
fi

################################################################################
# STEP 9: Remove Unwanted Software
################################################################################

if ask_continue "Remove Unwanted Software" \
"This step removes pre-installed software and their configs:

Removing:
  - alacritty: Default terminal (replaced by WezTerm)
  - firefox: Default browser (replaced by Vivaldi)
  - firefox-ublock-origin: Firefox extension

This includes removing all config files and data for these applications
to keep your system clean.

Note: Firefox will only be removed if Vivaldi installed successfully."; then

    print_header "Step 9: Removing Unwanted Software"

    # Function to remove package and its configs
    remove_package_with_configs() {
        local package=$1
        local config_paths=("${@:2}")

        if pacman -Q "$package" &>/dev/null; then
            print_info "Removing $package..."
            sudo pacman -Rns --noconfirm "$package" 2>/dev/null || sudo pacman -R --noconfirm "$package"

            # Remove config files
            for config_path in "${config_paths[@]}"; do
                if [ -e ~/"$config_path" ]; then
                    print_info "Removing $package configs: ~/$config_path"
                    rm -rf ~/"$config_path"
                fi
            done

            print_success "$package removed with configs"
        else
            print_warning "$package not installed, skipping"
        fi
    }

    # Remove Alacritty
    remove_package_with_configs "alacritty" ".config/alacritty" ".cache/alacritty"

    # Remove Firefox (only if Vivaldi installed successfully)
    if pacman -Q vivaldi &>/dev/null; then
        print_info "Vivaldi installed successfully, removing Firefox..."
        remove_package_with_configs "firefox" ".mozilla" ".cache/mozilla"

        # Also remove ublock-origin if present
        if pacman -Q firefox-ublock-origin &>/dev/null; then
            sudo pacman -R --noconfirm firefox-ublock-origin 2>/dev/null || true
        fi

        print_success "Firefox and extensions removed"
    else
        print_warning "Vivaldi not found, keeping Firefox as fallback"
    fi

    print_success "Unwanted software removed"
fi

################################################################################
# STEP 10: Enable NVIDIA Services
################################################################################

if ask_continue "Enable NVIDIA Services" \
"This step enables NVIDIA systemd services for better power management.

Services to enable:
  - nvidia-suspend.service: Handles GPU state during system suspend
  - nvidia-hibernate.service: Handles GPU state during hibernation
  - nvidia-resume.service: Restores GPU state after resume

These services prevent issues like:
  - Black screen after waking from sleep
  - GPU not working after hibernation
  - System freezes during suspend/resume

This is especially important for laptops like yours."; then

    print_header "Step 10: Enabling NVIDIA Services"
    sudo systemctl enable nvidia-suspend.service
    sudo systemctl enable nvidia-hibernate.service
    sudo systemctl enable nvidia-resume.service
    print_success "NVIDIA power management services enabled"
fi

################################################################################
# STEP 11: Verify Installation
################################################################################

if ask_continue "Verify Installation" \
"This step verifies that NVIDIA drivers are properly installed.

We'll check:
  - nvidia-smi: NVIDIA System Management Interface tool
  - Driver version and GPU detection
  - CUDA version (if applicable)

This helps confirm everything is working before you reboot.

If this fails, we'll know there's an issue to fix before proceeding."; then

    print_header "Step 11: Verifying NVIDIA Installation"

    if command -v nvidia-smi &> /dev/null; then
        echo ""
        nvidia-smi
        echo ""
        print_success "NVIDIA drivers verified successfully"
        print_info "Your RTX 3080 Mobile should appear above"
    else
        print_error "nvidia-smi not found - there may be an issue with the installation"
    fi
fi

################################################################################
# STEP 12: Deploy Configurations
################################################################################

if ask_continue "Deploy Custom Configurations" \
"This step deploys your custom configuration files.

This is done LAST to ensure:
  - All applications are installed first
  - Default applications are set correctly
  - No configs are overwritten during installation

Configs to deploy:
  - WezTerm → ~/.config/wezterm/wezterm.lua
  - KDE settings → ~/.config/ (fonts, shortcuts, defaults, etc.)
  - Obsidian → ~/.config/obsidian/ (if available)
  - VS Code → ~/.config/Code/User/settings.json (if available)
  - Vivaldi → ~/.config/vivaldi/ (bookmarks/preferences only, if available)

Config files must be in ./configs/ directory relative to this script."; then

    print_header "Step 12: Deploying Configurations"

    # Deploy WezTerm config
    if [ -f "$SCRIPT_DIR/configs/wezterm/wezterm.lua" ]; then
        print_info "Deploying WezTerm configuration..."
        mkdir -p ~/.config/wezterm
        cp "$SCRIPT_DIR/configs/wezterm/wezterm.lua" ~/.config/wezterm/
        print_success "WezTerm config deployed"
    else
        print_warning "WezTerm config not found at $SCRIPT_DIR/configs/wezterm/wezterm.lua, skipping"
        print_info "To fix: copy your wezterm.lua to configs/wezterm/ and commit to git"
    fi

    # Deploy KDE configs
    if [ -d "$SCRIPT_DIR/configs/kde" ]; then
        print_info "Deploying KDE configurations..."

        KDE_CONFIGS=(
            "kdeglobals"
            "kwinrc"
            "kwinrulesrc"
            "kglobalshortcutsrc"
            "plasma-localerc"
            "kscreenlockerrc"
            "plasmashellrc"
            "plasma-org.kde.plasma.desktop-appletsrc"
            "mimeapps.list"
        )

        for config_file in "${KDE_CONFIGS[@]}"; do
            if [ -f "$SCRIPT_DIR/configs/kde/$config_file" ]; then
                cp "$SCRIPT_DIR/configs/kde/$config_file" ~/.config/
                print_success "Deployed $config_file"
            fi
        done
    else
        print_info "No KDE configs found at $SCRIPT_DIR/configs/kde, skipping"
    fi

    # Deploy Obsidian configs
    if [ -d "$SCRIPT_DIR/configs/obsidian" ]; then
        print_info "Deploying Obsidian configuration..."
        mkdir -p ~/.config/obsidian
        cp -r "$SCRIPT_DIR/configs/obsidian/." ~/.config/obsidian/ 2>/dev/null || true
        print_success "Obsidian config deployed"
    else
        print_info "No Obsidian config found, skipping"
    fi

    # Deploy VS Code settings
    if [ -f "$SCRIPT_DIR/configs/vscode/settings.json" ]; then
        print_info "Deploying VS Code settings..."
        mkdir -p ~/.config/Code/User
        cp "$SCRIPT_DIR/configs/vscode/settings.json" ~/.config/Code/User/
        print_success "VS Code settings deployed"
    else
        print_info "No VS Code settings found, skipping"
    fi

    # Deploy Vivaldi configs (bookmarks/preferences only - never touches
    # cache, cookies, or saved logins on the live profile)
    if [ -d "$SCRIPT_DIR/configs/vivaldi" ]; then
        print_info "Deploying Vivaldi configuration..."
        mkdir -p ~/.config/vivaldi
        command -v rsync &>/dev/null || sudo pacman -S --noconfirm --needed rsync
        rsync -a \
            --exclude='*[Cc]ache*' \
            --exclude='*Cookies*' \
            --exclude='*Login Data*' \
            --exclude='Singleton*' \
            "$SCRIPT_DIR/configs/vivaldi/" ~/.config/vivaldi/ 2>/dev/null || true
        print_success "Vivaldi config deployed"
    else
        print_info "No Vivaldi config found, skipping"
    fi

    print_success "All configurations deployed"
fi

################################################################################
# STEP 13: Install Proton Drive CLI
################################################################################

if ask_continue "Install Proton Drive CLI" \
"This step installs the official Proton Drive command-line client, used
to back up and restore your Obsidian vault to/from Proton Drive
(https://proton.me/blog/proton-drive-cli).

We'll install 'proton-drive-cli-bin' from the AUR (the precompiled
binary, package name 'proton-drive').

⚠️  Sign-in happens through your browser, not this script. After install,
    run 'proton-drive auth login' yourself and keep the terminal open
    until it finishes - the session is then stored securely via
    libsecret (KWallet's secret-service on this system).

Once signed in, use the main menu:
  3) Backup Obsidian Vault to Proton Drive
  4) Restore Obsidian Vault from Proton Drive

The vault path is set near the top of this script (OBSIDIAN_VAULT_DIR),
currently: $OBSIDIAN_VAULT_DIR"; then

    print_header "Step 13: Installing Proton Drive CLI"

    yay -S --noconfirm proton-drive-cli-bin

    print_success "Proton Drive CLI installed"
    print_info "Sign in with: proton-drive auth login"
    print_info "Then use menu options 3/4 to backup/restore your Obsidian vault"
fi

################################################################################
# FINAL SUMMARY
################################################################################

print_header "Setup Complete!"

echo -e "${GREEN}All steps completed successfully!${NC}\n"

echo "Summary of what was done:"
echo "  ✓ System updated to latest packages"
echo "  ✓ NVIDIA drivers installed/verified"
echo "  ✓ X11 installed and set as default display server"
echo "  ✓ GLX vendor configured for NVIDIA"
echo "  ✓ EnvyControl installed - GPU set to hybrid mode (PRIME offload)"
echo "  ✓ switcheroo-control and thermald installed and enabled"
echo "  ✓ Initramfs rebuilt with new configuration"
echo "  ✓ YAY AUR helper installed"
echo "  ✓ Gaming meta package installed"
echo "  ✓ Applications installed (Discord, Vivaldi, Bitwarden, Steam, VLC, VS Code, Obsidian, WezTerm, Antigravity)"
echo "  ✓ Razer Control Revived installed (fan, RGB, battery, power monitoring)"
echo "  ✓ Razer Control KDE widget installed"
echo "  ✓ Unwanted software removed (Alacritty, Firefox)"
echo "  ✓ NVIDIA power management services enabled"
echo "  ✓ Custom configurations deployed"
echo "  ✓ Proton Drive CLI installed (sign in with: proton-drive auth login)"
echo ""

# Register post-reboot script to run on first login
print_info "Registering post-reboot verification script..."
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# Ensure post-reboot script is executable
chmod +x "$SCRIPT_DIR/post-reboot.sh"

cat > "$AUTOSTART_DIR/cachyos-post-reboot.desktop" << EOF
[Desktop Entry]
Type=Application
Name=CachyOS Post-Reboot Setup
Exec=wezterm start -- $SCRIPT_DIR/post-reboot.sh
Terminal=false
X-KDE-autostart-after=panel
EOF
print_success "Post-reboot script registered - will run automatically after next login"

print_warning "IMPORTANT: You must REBOOT for all changes to take effect!"
echo "The post-reboot script will run automatically on your first login."
echo ""
echo "Useful commands after reboot:"
echo "  envycontrol --query              # Check current GPU mode"
echo "  prime-run <program>              # Force an app onto the RTX 3080"
echo "  sudo envycontrol -s nvidia       # Switch to NVIDIA only (dGPU always on)"
echo "  sudo envycontrol -s integrated   # Intel only (maximum battery)"
echo "  nvidia-smi                       # Monitor GPU usage"
echo "  yay -Syu                         # Update all packages"
echo "  proton-drive auth login          # Sign in to Proton Drive (do this before backing up)"
echo "  ./cachyos-setup.sh                # Menu options 3/4: backup/restore Obsidian vault"
echo ""

read -p "Would you like to reboot now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Rebooting system..."
    sudo reboot
else
    print_warning "Remember to reboot before using your system normally!"
    print_info "Run 'sudo reboot' when you're ready."
fi
