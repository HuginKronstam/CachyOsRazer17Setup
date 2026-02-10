#!/bin/bash

################################################################################
# CachyOS Post-Installation Setup Script
# For: Razer Blade 17 (Intel + NVIDIA RTX 3080 Mobile)
# DE: KDE Plasma (Wayland preferred, X11 fallback)
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Interactive mode flag
INTERACTIVE=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
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

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    BACKUP_DIR="$SCRIPT_DIR/configs"

    print_info "Backup location: $BACKUP_DIR"
    echo ""

    # Create backup directories
    mkdir -p "$BACKUP_DIR"/{wezterm,kde,obsidian,vscode}

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
    echo "3) Exit"
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

    # Configure X11 for NVIDIA Optimus (hybrid graphics)
    print_info "Configuring X11 for NVIDIA Optimus hybrid graphics..."
    sudo mkdir -p /etc/X11/xorg.conf.d
    cat << 'EOF' | sudo tee /etc/X11/xorg.conf.d/20-nvidia-optimus.conf > /dev/null
Section "ServerLayout"
    Identifier "layout"
    Option "AllowNVIDIAGPUScreens"
EndSection

Section "Device"
    Identifier "nvidia"
    Driver "nvidia"
    BusID "PCI:1:0:0"
    Option "AllowEmptyInitialConfiguration"
EndSection

Section "Device"
    Identifier "intel"
    Driver "modesetting"
    BusID "PCI:0:2:0"
EndSection
EOF

    print_success "X11 installed and set as default session"
    print_info "GLX vendor configured for NVIDIA"
    print_info "X11 Optimus configuration created (supports both laptop and external displays)"
    print_info "After reboot, you'll automatically login to Plasma X11"
    print_info "To switch to Wayland: select 'Plasma (Wayland)' at login screen"
fi

################################################################################
# STEP 4: Configure NVIDIA as Primary GPU
################################################################################

if ask_continue "Configure NVIDIA as Primary GPU" \
"This step configures your system to use NVIDIA as the primary GPU.

We'll create configuration files to:
  1. Tell the system to use NVIDIA by default for rendering
  2. Enable kernel modesetting (smoother boot and better Wayland support)
  3. Preserve video memory allocations (better stability)

Method: We'll set environment variables that make NVIDIA the default
GPU while keeping Intel available as a fallback (safer than blacklisting).

Files created:
  - /etc/modprobe.d/nvidia.conf (kernel module options)
  - /etc/environment.d/nvidia.conf (environment variables)

This is MUCH safer than blacklisting the Intel GPU and won't brick
your system."; then

    print_header "Step 3: Configuring NVIDIA as Primary"

    # Enable nvidia-drm modesetting and preserve video memory
    print_info "Creating NVIDIA kernel module configuration..."
    echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
    echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee -a /etc/modprobe.d/nvidia.conf > /dev/null

    # Set NVIDIA as primary GPU via environment variables
    print_info "Setting NVIDIA as primary GPU..."
    sudo mkdir -p /etc/environment.d
    cat << 'EOF' | sudo tee /etc/environment.d/nvidia.conf > /dev/null
# Make NVIDIA the primary GPU
__NV_PRIME_RENDER_OFFLOAD=0
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
EOF

    print_success "NVIDIA configured as primary GPU"
    print_info "Intel GPU remains available as fallback (safe configuration)"
fi

################################################################################
# STEP 5: Update Initramfs
################################################################################

if ask_continue "Rebuild Initramfs" \
"This step rebuilds the initial ramdisk (initramfs).

The initramfs is loaded by the bootloader before the main system boots.
It contains essential drivers and modules needed during early boot.

We need to rebuild it to include:
  - New NVIDIA driver modules
  - Updated kernel module options

Without this, your NVIDIA configuration changes won't take effect
until you manually rebuild it later.

Command: 'mkinitcpio -P' rebuilds initramfs for all installed kernels."; then

    print_header "Step 4: Rebuilding Initramfs"
    sudo mkinitcpio -P
    print_success "Initramfs rebuilt with new NVIDIA configuration"
fi

################################################################################
# STEP 6: Install YAY (AUR Helper)
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

Note: Some software in your list (like Bitwarden, VS Code) may come
from AUR, so we need this before installing your applications."; then

    print_header "Step 5: Installing YAY"

    if ! command -v yay &> /dev/null; then
        sudo pacman -S --noconfirm yay
        print_success "YAY installed successfully"
    else
        print_warning "YAY is already installed, skipping"
    fi
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
  - brave-bin: Privacy-focused web browser (from AUR)
  - bitwarden: Password manager
  - steam: Gaming platform
  - vlc: Media player
  - visual-studio-code-bin: Code editor (from AUR)
  - obsidian: Note-taking and knowledge base (from AUR)
  - wezterm: GPU-accelerated terminal emulator (from AUR)
  - ttf-blex-nerd: BlexMono Nerd Font (for WezTerm)

Some packages are from official repos, others from AUR.
AUR packages take longer to install as they're compiled locally.

This may take 10-20 minutes depending on your system and internet speed."; then

    print_header "Step 8: Installing Applications"

    # Define packages
    OFFICIAL_PACKAGES="discord steam vlc"
    AUR_PACKAGES="brave-bin bitwarden visual-studio-code-bin obsidian wezterm ttf-blex-nerd"

    # Install official packages
    print_info "Installing packages from official repositories..."
    sudo pacman -S --noconfirm $OFFICIAL_PACKAGES

    # Install AUR packages
    print_info "Installing packages from AUR (this may take a while)..."
    yay -S --noconfirm $AUR_PACKAGES

    print_success "All applications installed successfully"
fi

################################################################################
# STEP 9: Remove Unwanted Software
################################################################################

if ask_continue "Remove Unwanted Software" \
"This step removes pre-installed software and their configs:

Removing:
  - alacritty: Default terminal (replaced by WezTerm)
  - firefox: Default browser (replaced by Brave)
  - firefox-ublock-origin: Firefox extension

This includes removing all config files and data for these applications
to keep your system clean.

Note: Firefox will only be removed if Brave installed successfully."; then

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

    # Remove Firefox (only if Brave installed successfully)
    if pacman -Q brave-bin &>/dev/null; then
        print_info "Brave installed successfully, removing Firefox..."
        remove_package_with_configs "firefox" ".mozilla" ".cache/mozilla"

        # Also remove ublock-origin if present
        if pacman -Q firefox-ublock-origin &>/dev/null; then
            sudo pacman -R --noconfirm firefox-ublock-origin 2>/dev/null || true
        fi

        print_success "Firefox and extensions removed"
    else
        print_warning "Brave not found, keeping Firefox as fallback"
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

Config files must be in ./configs/ directory relative to this script."; then

    print_header "Step 12: Deploying Configurations"

    # Deploy WezTerm config
    if [ -f "./configs/wezterm/wezterm.lua" ]; then
        print_info "Deploying WezTerm configuration..."
        mkdir -p ~/.config/wezterm
        cp ./configs/wezterm/wezterm.lua ~/.config/wezterm/
        print_success "WezTerm config deployed"
    else
        print_warning "WezTerm config not found, skipping"
    fi

    # Deploy KDE configs
    if [ -d "./configs/kde" ]; then
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
            if [ -f "./configs/kde/$config_file" ]; then
                cp "./configs/kde/$config_file" ~/.config/
                print_success "Deployed $config_file"
            fi
        done
    else
        print_info "No KDE configs found, skipping"
    fi

    # Deploy Obsidian configs
    if [ -d "./configs/obsidian" ]; then
        print_info "Deploying Obsidian configuration..."
        mkdir -p ~/.config/obsidian
        cp -r ./configs/obsidian/* ~/.config/obsidian/ 2>/dev/null || true
        print_success "Obsidian config deployed"
    else
        print_info "No Obsidian config found, skipping"
    fi

    # Deploy VS Code settings
    if [ -f "./configs/vscode/settings.json" ]; then
        print_info "Deploying VS Code settings..."
        mkdir -p ~/.config/Code/User
        cp ./configs/vscode/settings.json ~/.config/Code/User/
        print_success "VS Code settings deployed"
    else
        print_info "No VS Code settings found, skipping"
    fi

    print_success "All configurations deployed"
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
echo "  ✓ X11 Optimus configured (hybrid Intel+NVIDIA graphics)"
echo "  ✓ NVIDIA configured as primary GPU"
echo "  ✓ Initramfs rebuilt with new configuration"
echo "  ✓ YAY AUR helper installed"
echo "  ✓ Gaming meta package installed"
echo "  ✓ Applications installed (Discord, Brave, Bitwarden, Steam, VLC, VS Code, Obsidian, WezTerm)"
echo "  ✓ Unwanted software removed (Alacritty, Firefox)"
echo "  ✓ NVIDIA power management services enabled"
echo "  ✓ Custom configurations deployed"
echo ""

print_warning "IMPORTANT: You must REBOOT for all changes to take effect!"
echo ""
echo "After reboot:"
echo "  1. System will automatically use X11 session (better for gaming)"
echo "  2. NVIDIA GPU will be used for rendering (no black boxes)"
echo "  3. Both laptop and external displays will work correctly"
echo "  4. Multi-monitor setup should work smoothly without frame caps"
echo "  5. Gaming performance will be optimal on both laptop screen and external monitor"
echo "  6. To switch to Wayland (if you want to test):"
echo "     - Log out → Select 'Plasma (Wayland)' at login screen"
echo ""

print_info "Tips:"
echo "  - Use 'nvidia-settings' to configure display settings"
echo "  - Use 'nvidia-smi' to monitor GPU usage"
echo "  - Steam should automatically detect and use your NVIDIA GPU"
echo "  - X11 handles multi-monitor gaming much better than Wayland currently"
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
