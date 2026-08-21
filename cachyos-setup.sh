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

# Where CachyOS ISOs get downloaded/cached for boot drive creation, and the
# official mirror we scrape for the latest desktop release.
CACHYOS_ISO_CACHE_DIR="$HOME/.cache/cachyos-setup-iso"
CACHYOS_ISO_MIRROR="https://mirror.cachyos.org/ISO/desktop"

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
    mkdir -p "$BACKUP_DIR"/{wezterm,kde,obsidian,vscode,vivaldi,handy,kwin-scripts,icons,wallpapers,plasma-widgets-shared,sensorfaces,widget-scripts,widget-source,widgets}

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
        "khotkeysrc"
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

    # Backup Obsidian (small top-level settings/window-state files only -
    # NOT the Chromium/Electron internals like Cache, Cookies, IndexedDB,
    # Local/Session Storage, etc. Those can hold plugin API keys and other
    # sensitive browser-storage data - a previous blind `cp -r` here is
    # what leaked an Anthropic API key into git history. Matches the
    # allow-list in .gitignore.)
    if [ -d ~/.config/obsidian ]; then
        print_info "Backing up Obsidian settings (excluding Chromium/Electron internals)..."
        find ~/.config/obsidian -maxdepth 1 -type f \( -name "*.json" -o -name "obsidian.log" \) \
            -exec cp {} "$BACKUP_DIR/obsidian/" \;
        print_success "Obsidian settings backed up"
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

    # Backup Handy settings (just the settings file - not the models/
    # directory, which holds multi-GB speech-to-text models that are
    # trivially re-downloaded, or transcription history audio)
    if [ -f ~/.config/com.pais.handy/settings_store.json ]; then
        print_info "Backing up Handy settings..."
        cp ~/.config/com.pais.handy/settings_store.json "$BACKUP_DIR/handy/"
        print_success "Handy settings backed up"
    else
        print_warning "Handy settings not found, skipping"
    fi

    # Backup KWin scripts (e.g. Truely Maximized). These are installed via
    # KDE's "Get New Scripts", not a pacman package, so there's nothing to
    # reinstall from without backing up the actual files. Their enabled
    # state and settings are separately covered by kwinrc above - this is
    # just the script code itself.
    if [ -d ~/.local/share/kwin/scripts ] && [ -n "$(ls -A ~/.local/share/kwin/scripts 2>/dev/null)" ]; then
        print_info "Backing up KWin scripts..."
        cp -r ~/.local/share/kwin/scripts/. "$BACKUP_DIR/kwin-scripts/"
        print_success "KWin scripts backed up"
    else
        print_warning "No KWin scripts found, skipping"
    fi

    # Backup custom icons - ~/.local/share/icons/hicolor is the standard
    # per-user location for your OWN icons (e.g. hicolor/Custom/). Only the
    # standard size-named hicolor/ subfolders (16x16, 256x256, scalable,
    # etc.) are excluded - that's auto-regenerated Steam/Wine app icon
    # cache. Full downloaded icon THEMES (candy-icons, Infinity-Dark-Icons,
    # etc. - installed via System Settings' "Get New Icons" dialog) are
    # deliberately NOT copied here: they're third-party content that can
    # run into the hundreds of MB and are trivially reinstallable, so only
    # a lightweight reference list is saved instead (see below).
    if [ -d ~/.local/share/icons/hicolor ]; then
        print_info "Backing up custom icons (hicolor only)..."
        command -v rsync &>/dev/null || sudo pacman -S --noconfirm --needed rsync
        rsync -a --exclude='[0-9]*x[0-9]*/' --exclude='scalable/' \
            ~/.local/share/icons/hicolor/ "$BACKUP_DIR/icons/hicolor/" 2>/dev/null || true
        print_success "Custom icons (hicolor) backed up"
    else
        print_warning "No custom icons directory found, skipping"
    fi

    # Record which full icon themes are installed (downloaded via KDE
    # Store's "Get New Icons" dialog) as a lightweight reference instead of
    # backing up their files - reinstalling is a couple of clicks in
    # System Settings, and doing that beats carrying hundreds of MB of
    # someone else's SVGs through git. Cross-references KNewStuff's own
    # install registry (~/.local/share/knewstuff3/icons.knsregistry) for
    # the name/homepage KDE Store used, when available.
    if [ -d ~/.local/share/icons ]; then
        # The user's own kdeglobals takes precedence, but global themes set
        # the icon theme via the kdedefaults layer instead (confirmed: this
        # machine's active theme only showed up there, not in kdeglobals).
        ACTIVE_ICON_THEME=$(grep -A5 "^\[Icons\]" ~/.config/kdeglobals 2>/dev/null | grep "^Theme=" | head -1 | cut -d= -f2)
        if [ -z "$ACTIVE_ICON_THEME" ]; then
            ACTIVE_ICON_THEME=$(grep -A5 "^\[Icons\]" ~/.config/kdedefaults/kdeglobals 2>/dev/null | grep "^Theme=" | head -1 | cut -d= -f2)
        fi
        python3 - "$ACTIVE_ICON_THEME" > "$BACKUP_DIR/icons/DOWNLOADED-THEMES.md" << 'PYEOF'
import sys, os, glob
import xml.etree.ElementTree as ET

active = sys.argv[1] if len(sys.argv) > 1 else ""
icons_dir = os.path.expanduser("~/.local/share/icons")
registry_path = os.path.expanduser("~/.local/share/knewstuff3/icons.knsregistry")

entries = {}
if os.path.exists(registry_path):
    try:
        tree = ET.parse(registry_path)
        for stuff in tree.getroot().findall("stuff"):
            installed = stuff.findtext("installedfile", "")
            name = stuff.findtext("name", "")
            homepage = stuff.findtext("homepage", "")
            folder = installed.rstrip("/*").split("/")[-1]
            if folder:
                entries[folder] = (name, homepage)
    except ET.ParseError:
        pass

print("# Downloaded icon themes\n")
print("Not backed up as files (can be hundreds of MB, trivially reinstallable).")
print("Reinstall via System Settings > Appearance > Icons > Get New Icons,")
print("search for the name below, or open the homepage link directly. Then")
print("set the active one the same way (or in System Settings > Icons).\n")

found_any = False
for path in sorted(glob.glob(os.path.join(icons_dir, "*"))):
    folder = os.path.basename(path)
    if folder == "hicolor" or not os.path.isdir(path):
        continue
    found_any = True
    marker = " (active)" if folder == active else ""
    if folder in entries:
        name, homepage = entries[folder]
        print(f"- **{name or folder}**{marker}: {homepage}")
    else:
        print(f"- **{folder}**{marker}: source unknown, check store.kde.org or wherever you originally got it")

if not found_any:
    print("(none found)")
PYEOF
        print_success "Downloaded icon theme list saved (files not backed up)"
    fi

    if [ -d ~/.local/share/wallpapers ] && [ -n "$(ls -A ~/.local/share/wallpapers 2>/dev/null)" ]; then
        print_info "Backing up custom wallpapers..."
        cp -r ~/.local/share/wallpapers/. "$BACKUP_DIR/wallpapers/"
        print_success "Custom wallpapers backed up"
    else
        print_warning "No custom wallpapers found, skipping"
    fi

    # Backup shared QML components + generated assets used by the custom
    # System Monitor sensor faces below (thermal ring color logic, value
    # smoothing, moon relighting)
    if [ -d ~/.local/share/plasma-widgets-shared ] && [ -n "$(ls -A ~/.local/share/plasma-widgets-shared 2>/dev/null)" ]; then
        print_info "Backing up shared Plasma widget QML/assets..."
        cp -r ~/.local/share/plasma-widgets-shared/. "$BACKUP_DIR/plasma-widgets-shared/"
        print_success "Shared Plasma widget QML/assets backed up"
    else
        print_warning "No shared Plasma widget QML/assets found, skipping"
    fi

    # Backup custom System Monitor sensor faces (forked KPackages for the
    # CPU/GPU thermal ring widgets). Their placement on the desktop and
    # sensor picks aren't stored here - see POST_INSTALL_WIDGET_SETUP.md
    # for the manual re-add step after a restore.
    if [ -d ~/.local/share/ksysguard/sensorfaces ] && [ -n "$(ls -A ~/.local/share/ksysguard/sensorfaces 2>/dev/null)" ]; then
        print_info "Backing up custom System Monitor sensor faces..."
        cp -r ~/.local/share/ksysguard/sensorfaces/. "$BACKUP_DIR/sensorfaces/"
        print_success "Custom System Monitor sensor faces backed up"
    else
        print_warning "No custom System Monitor sensor faces found, skipping"
    fi

    # Backup widget setup/calibration scripts (moon relighting bake scripts
    # and shared config loader - the post-restore instructions doc lives in
    # the Obsidian vault instead, so it's covered by the vault backup)
    if [ -d ~/.local/share/scripts/widgets ] && [ -n "$(ls -A ~/.local/share/scripts/widgets 2>/dev/null)" ]; then
        print_info "Backing up widget setup scripts..."
        rsync -a --exclude='__pycache__/' \
            ~/.local/share/scripts/widgets/ "$BACKUP_DIR/widget-scripts/" 2>/dev/null || true
        print_success "Widget setup scripts backed up"
    else
        print_warning "No widget setup scripts found, skipping"
    fi

    # Backup the raw source photo for the neon moon widget - isolate_neon_moon.py
    # reads this to (re)produce neon-moon-base.png. The baked output is
    # already backed up via the icons folder, but keeping the source lets
    # the crop/feather be re-tuned later without needing to re-source the photo.
    if [ -f ~/Pictures/neon-moon-dreams-stockcake.jpg ]; then
        print_info "Backing up neon moon source photo..."
        cp ~/Pictures/neon-moon-dreams-stockcake.jpg "$BACKUP_DIR/widget-source/"
        print_success "Neon moon source photo backed up"
    else
        print_warning "Neon moon source photo not found, skipping"
    fi

    # Backup custom-built plasmoids (full packages, not just the shared
    # QML/scripts above) - each lives in its own subfolder under widgets/,
    # named to match its plasmoid id under ~/.local/share/plasma/plasmoids/
    if [ -d ~/.local/share/plasma/plasmoids/HuginWB ]; then
        print_info "Backing up HuginWB widget..."
        mkdir -p "$BACKUP_DIR/widgets/HuginWB"
        cp -r ~/.local/share/plasma/plasmoids/HuginWB/. "$BACKUP_DIR/widgets/HuginWB/"
        print_success "HuginWB widget backed up"
    else
        print_warning "HuginWB widget not found, skipping"
    fi

    # Check whether a newer Razer Control Revived release has shipped -
    # this project fixes device-specific bugs frequently (we're currently
    # tracking one: GetBatteryHealthOptimizer crashes the entire status
    # response on devices whose laptops.json entry lacks the "bho"
    # feature, e.g. this laptop), so it's worth knowing when a fix lands
    # without having to remember to check manually.
    if [ -f ~/.local/share/razercontrol/.installed-version ]; then
        print_info "Checking for Razer Control Revived updates..."
        INSTALLED_RAZER_TAG=$(cat ~/.local/share/razercontrol/.installed-version 2>/dev/null)
        LATEST_RAZER_TAG=$(curl -sL --connect-timeout 10 --max-time 15 \
            "https://api.github.com/repos/encomjp/razer-control-revived/releases/latest" \
            | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
        if [ -z "$LATEST_RAZER_TAG" ]; then
            print_warning "Could not check for Razer Control Revived updates (network/API issue)"
        elif [ "$LATEST_RAZER_TAG" != "$INSTALLED_RAZER_TAG" ]; then
            print_warning "Razer Control Revived $LATEST_RAZER_TAG is available (you have $INSTALLED_RAZER_TAG)"
            print_info "Re-run Setup System, Step 8 to upgrade"
        else
            print_success "Razer Control Revived is up to date ($INSTALLED_RAZER_TAG)"
        fi
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

    offer_create_boot_drive
}

################################################################################
# Caligula - CachyOS Boot Drive Creation
################################################################################
# Checks the official mirror for the latest CachyOS desktop ISO, looks for an
# attached removable drive with enough space, and offers to burn it with
# caligula. Only runs the (large) download if a suitable drive is found and
# the user opts in.

# Scrapes the CachyOS ISO mirror for the latest desktop release. On success,
# sets CACHYOS_ISO_URL, CACHYOS_ISO_NAME, CACHYOS_ISO_SHA256, CACHYOS_ISO_SIZE.
find_latest_cachyos_iso() {
    local index_html latest_date folder_html sha_content curl_opts=(-sL --connect-timeout 10 --max-time 30)

    index_html=$(curl "${curl_opts[@]}" "$CACHYOS_ISO_MIRROR/") || return 1
    latest_date=$(grep -oE 'href="[0-9]{6}/"' <<<"$index_html" | grep -oE '[0-9]{6}' | sort -n | tail -1)
    [ -n "$latest_date" ] || return 1

    folder_html=$(curl "${curl_opts[@]}" "$CACHYOS_ISO_MIRROR/$latest_date/") || return 1
    CACHYOS_ISO_NAME=$(grep -oE 'href="cachyos-desktop-linux-[0-9]{6}\.iso"' <<<"$folder_html" | sed -E 's/href="(.*)"/\1/')
    [ -n "$CACHYOS_ISO_NAME" ] || return 1

    CACHYOS_ISO_URL="$CACHYOS_ISO_MIRROR/$latest_date/$CACHYOS_ISO_NAME"

    sha_content=$(curl "${curl_opts[@]}" "$CACHYOS_ISO_URL.sha256") || return 1
    CACHYOS_ISO_SHA256=$(awk '{print $1}' <<<"$sha_content")
    [ -n "$CACHYOS_ISO_SHA256" ] || return 1

    CACHYOS_ISO_SIZE=$(curl -sIL --connect-timeout 10 --max-time 30 "$CACHYOS_ISO_URL" \
        | grep -i '^content-length:' | tail -1 | awk '{print $2}' | tr -d '\r')
    [ -n "$CACHYOS_ISO_SIZE" ] || return 1

    return 0
}

# Prints "name\tsize\ttran\tmodel\tvendor" for removable disks with at least
# $1 bytes of capacity.
find_usb_candidates() {
    local min_bytes="$1"
    command -v jq &>/dev/null || sudo pacman -S --noconfirm --needed jq
    lsblk -d -b -J -o NAME,SIZE,TYPE,RM,TRAN,MODEL,VENDOR 2>/dev/null | \
        jq -r --argjson min "$min_bytes" \
        '.blockdevices[]? | select(.rm==true and .size>=$min) | "\(.name)\t\(.size)\t\(.tran)\t\(.model)\t\(.vendor)"'
}

human_size() {
    numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 bytes"
}

offer_create_boot_drive() {
    print_header "CachyOS Boot Drive (Caligula)"

    if ! command -v caligula &>/dev/null; then
        print_warning "caligula not installed - skipping boot drive check"
        print_info "Install it via Setup System, or manually: sudo pacman -S caligula"
        return 0
    fi

    print_info "Checking for the latest CachyOS release and any attached USB drives..."

    if ! find_latest_cachyos_iso; then
        print_warning "Could not reach the CachyOS ISO mirror - skipping boot drive check"
        return 0
    fi

    local candidates=()
    while IFS=$'\t' read -r name size tran model vendor; do
        [ -n "$name" ] && candidates+=("$name|$size|$tran|$model|$vendor")
    done < <(find_usb_candidates "$CACHYOS_ISO_SIZE")

    if [ ${#candidates[@]} -eq 0 ]; then
        print_info "No removable drive with at least $(human_size "$CACHYOS_ISO_SIZE") free is currently plugged in - skipping"
        return 0
    fi

    echo ""
    print_info "Latest CachyOS release: $CACHYOS_ISO_NAME ($(human_size "$CACHYOS_ISO_SIZE"))"
    print_info "Found ${#candidates[@]} removable drive(s) with enough space:"
    local i=1 entry name size tran model vendor
    for entry in "${candidates[@]}"; do
        IFS='|' read -r name size tran model vendor <<<"$entry"
        echo "    $i) /dev/$name - $(human_size "$size") - $(xargs <<<"$vendor $model") ($tran)"
        i=$((i + 1))
    done
    echo ""

    read -p "Create a CachyOS boot drive on one of these? [y/N] " confirm
    case $confirm in
        [Yy]*) ;;
        *) print_info "Skipping boot drive creation"; return 0 ;;
    esac

    local device
    if [ ${#candidates[@]} -eq 1 ]; then
        IFS='|' read -r device _ _ _ _ <<<"${candidates[0]}"
    else
        read -p "Which drive? [1-${#candidates[@]}] " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#candidates[@]} ]; then
            print_error "Invalid selection - cancelling"
            return 1
        fi
        IFS='|' read -r device _ _ _ _ <<<"${candidates[$((choice - 1))]}"
    fi

    print_warning "This will ERASE ALL DATA on /dev/$device."
    print_info "Caligula will show its own confirmation before writing anything."

    mkdir -p "$CACHYOS_ISO_CACHE_DIR"
    local iso_path="$CACHYOS_ISO_CACHE_DIR/$CACHYOS_ISO_NAME"

    if [ -f "$iso_path" ] && [ "$(sha256sum "$iso_path" | awk '{print $1}')" = "$CACHYOS_ISO_SHA256" ]; then
        print_success "Using already-downloaded and verified ISO: $iso_path"
    else
        print_info "Downloading $CACHYOS_ISO_NAME ($(human_size "$CACHYOS_ISO_SIZE"))..."
        if ! curl -L --fail -o "$iso_path" "$CACHYOS_ISO_URL"; then
            print_error "Download failed"
            rm -f "$iso_path"
            return 1
        fi

        local actual_hash
        actual_hash=$(sha256sum "$iso_path" | awk '{print $1}')
        if [ "$actual_hash" != "$CACHYOS_ISO_SHA256" ]; then
            print_error "Checksum mismatch - downloaded file may be corrupt, aborting"
            rm -f "$iso_path"
            return 1
        fi
        print_success "Downloaded and verified $CACHYOS_ISO_NAME"
    fi

    print_info "Launching caligula - follow its prompts to confirm and write /dev/$device"
    if sudo caligula burn -o "/dev/$device" -z none --hash-of raw \
        -s "sha256-$CACHYOS_ISO_SHA256" --root never "$iso_path"; then
        print_success "Boot drive created on /dev/$device"
        add_setup_bootstrap_partition "$device"
    else
        print_warning "Caligula exited without completing - boot drive may not have been created"
    fi
}

# Adds a small FAT32 partition in whatever free space is left on the USB
# stick after the ISO (ISOs are usually a few GB, sticks are often much
# bigger, so there's normally plenty left over) containing a bootstrap
# script that clones this repo. Entirely optional, skips cleanly if there's
# no meaningful free space.
add_setup_bootstrap_partition() {
    local device="$1"
    local dev_path="/dev/$device"

    print_header "Setup Bootstrap Partition"

    command -v parted &>/dev/null || sudo pacman -S --noconfirm --needed parted
    command -v mkfs.vfat &>/dev/null || sudo pacman -S --noconfirm --needed dosfstools

    print_info "Checking for free space on $dev_path after the ISO..."
    sudo partprobe "$dev_path" 2>/dev/null
    udevadm settle 2>/dev/null

    local free_line free_start_mib free_size_mib
    free_line=$(LC_ALL=C sudo parted -s -m "$dev_path" unit MiB print free 2>/dev/null | grep ':free;$' | tail -1)
    if [ -z "$free_line" ]; then
        print_info "No free space left on $dev_path - skipping bootstrap partition"
        return 0
    fi

    free_start_mib=$(echo "$free_line" | cut -d: -f2 | tr -d 'MiB')
    free_size_mib=$(echo "$free_line" | cut -d: -f4 | tr -d 'MiB')

    if awk "BEGIN{exit !($free_size_mib < 8)}"; then
        print_info "Not enough free space on $dev_path (${free_size_mib}MiB) for a bootstrap partition - skipping"
        return 0
    fi

    print_info "Free space after the ISO: ${free_size_mib}MiB"
    read -p "Add a small FAT32 partition there with a setup bootstrap script? [y/N] " confirm
    case $confirm in
        [Yy]*) ;;
        *) print_info "Skipping bootstrap partition"; return 0 ;;
    esac

    print_info "Creating partition..."
    if ! sudo parted -s "$dev_path" mkpart primary fat32 "${free_start_mib}MiB" 100%; then
        print_error "Failed to create bootstrap partition"
        return 1
    fi
    sudo partprobe "$dev_path" 2>/dev/null
    udevadm settle 2>/dev/null
    sleep 1

    local part_num part_dev
    part_num=$(LC_ALL=C sudo parted -s -m "$dev_path" print 2>/dev/null | tail -1 | cut -d: -f1)
    part_dev="${dev_path}${part_num}"

    if [ ! -b "$part_dev" ]; then
        print_error "New partition device $part_dev not found after creation - aborting"
        return 1
    fi

    print_info "Formatting $part_dev as FAT32..."
    sudo mkfs.vfat -n CACHYSETUP "$part_dev" >/dev/null

    local mount_point
    mount_point=$(mktemp -d)
    sudo mount "$part_dev" "$mount_point"
    sudo cp "$SCRIPT_DIR/scripts/usb-bootstrap.sh" "$mount_point/bootstrap.sh"
    sudo chmod +x "$mount_point/bootstrap.sh"
    sync
    sudo umount "$mount_point"
    rmdir "$mount_point"

    print_success "Bootstrap partition created on $part_dev (label CACHYSETUP)"
    print_info "After booting from this drive: mount it and run bootstrap.sh"
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
# STEP 3: Install XWayland Support (X11 kept as fallback only)
################################################################################

if ask_continue "Install XWayland Support and Set Wayland as Default" \
"This step installs X11/XWayland packages (needed for X11-only apps to run
inside a Wayland session, and kept available as a manual fallback session),
and sets Plasma Wayland as the default login session.

Why Wayland instead of forcing X11?
  Measured directly on this laptop: with the external monitor's DisplayPort
  wired straight to the RTX 3080 (not the Intel iGPU), X11's PRIME model
  copies every frame from Intel to NVIDIA for that output (reverse offload).
  KWin on Wayland instead scans out natively on whichever GPU actually owns
  the connected port - measured ~33% lower idle power draw (18W vs 27W) and
  the GPU sitting in its actual idle clock state (P8) instead of boosted
  (P0), for the exact same idle desktop on the same external monitor.
  Gaming and tearing were also fine in testing.

We'll install:
  - xorg-server: Needed for XWayland (X11 app compatibility under Wayland)
  - xorg-xinit: X11 initialization utilities
  - xf86-input-libinput: Modern input driver, used if you ever pick the X11 session
  - plasma-x11-session: KDE Plasma X11 session files - kept as a manual
    fallback in the SDDM session picker, no longer the default

Then configure SDDM (login manager) to default to Plasma Wayland, and
enable NumLock on the login screen - SDDM has its own separate NumLock
setting (defaults to leaving it unchanged) that ignores your Plasma
session's NumLock preference entirely unless explicitly set.

You can still select 'Plasma (X11)' at the login screen any time if you need it."; then

    print_header "Step 3: Installing XWayland Support"

    # Install X11/XWayland packages - plasma-x11-session stays available as
    # a fallback session, it's just no longer the default
    print_info "Installing XWayland and Plasma X11 fallback session..."
    sudo pacman -S --noconfirm --needed xorg-server xorg-xinit xf86-input-libinput plasma-x11-session
    print_success "XWayland packages installed"

    # Set Wayland as default session in SDDM
    print_info "Configuring SDDM to default to Plasma Wayland..."

    # Create SDDM config directory if it doesn't exist
    sudo mkdir -p /etc/sddm.conf.d

    # Configure SDDM to use Wayland by default, and match the login
    # screen's NumLock state to the Plasma session preference (kcminputrc
    # NumLock=0 means "on" - SDDM has its own separate NumLock setting
    # that defaults to "none"/unchanged and ignores the Plasma one
    # entirely unless explicitly set here).
    #
    # DisplayServer=x11 forces the *greeter* (login screen) specifically
    # to run on X11 rather than native Wayland. This only affects the
    # login screen - the actual session after login is still Wayland,
    # controlled independently by Session=plasma below. This override is
    # required for Numlock=on to actually work: sddm-greeter only
    # implements NumLock via X11/XCB-XKB calls (confirmed via strings on
    # /usr/bin/sddm-greeter-qt6 - it has no Wayland-native code path for
    # it), so under a Wayland greeter the setting is silently ignored.
    cat << 'EOF' | sudo tee /etc/sddm.conf.d/default-session.conf > /dev/null
[General]
# Run the login screen itself on X11 so NumLock actually works (see
# comment above) - does not affect the Wayland session after login
DisplayServer=x11
# Set Plasma Wayland as default session
Session=plasma
# Match the login screen's NumLock state to the Plasma session preference
Numlock=on
EOF

    # Configure GLX vendor for NVIDIA - still needed for XWayland/GLX apps
    # and the X11 fallback session, harmless under Wayland
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

    print_success "XWayland installed, Plasma Wayland set as default session"
    print_info "NumLock enabled on the login screen"
    print_info "GLX vendor configured for NVIDIA"
    print_info "After reboot, you'll automatically login to Plasma Wayland"
    print_info "To use X11 instead: select 'Plasma (X11)' at the login screen"
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
NVIDIA Optimus laptops (Intel + NVIDIA hybrid systems), plus a
docked/mobile GPU mode switcher: an auto-detect service that prompts
you when it's worth switching, and a manual toggle script for a hotkey.

GPU Modes available:
  - integrated: Intel GPU only (maximum battery life)
  - hybrid:     Both GPUs, NVIDIA used on-demand via PRIME offload (balanced)
  - nvidia:     NVIDIA GPU only, always on (maximum performance, worst battery)

Your external monitor's DisplayPort is wired directly to the RTX 3080, not
the Intel iGPU - measured on this laptop, so this isn't a guess. Since you
use an external monitor 90%+ of the time, the dGPU has to be awake for
almost all of your actual usage regardless of GPU mode, and hybrid mode
adds PRIME reverse-offload overhead for that external output. So we'll
set 'nvidia' mode as the default (matches your primary, docked use case):

  - Docked: nvidia mode, dGPU always on, no offload overhead
  - Mobile: hybrid mode with RTD3 (--rtd3 2), dGPU sleeps when idle

Two ways to switch between them, both installed:
  - gpu-mode-monitor.service: runs in the background, watches
    /sys/class/drm for your external monitor connecting/disconnecting
    (works under X11 or Wayland), and when the current mode doesn't
    match, prompts you to switch - only once per actual plug/unplug,
    not repeatedly.
  - gpu-mode-toggle.sh: the same prompt-and-switch logic, callable
    directly - bind it to a hotkey if you'd rather trigger it manually.

Either way, switching asks for confirmation, uses pkexec for a GUI
password prompt (no terminal needed), and offers to reboot immediately -
EnvyControl mode switches always need a reboot to take effect.

Also installed in this step:
  - nvidia-prime: adds the 'prime-run <program>' shortcut for forcing
    a specific app onto the NVIDIA GPU (only relevant in hybrid mode)
  - switcheroo-control: powers KDE's per-app 'Run using dedicated
    graphics card' checkbox in hybrid mode
  - thermald: Intel thermal management daemon, applies CPU power/perf
    limits before the firmware has to throttle aggressively

Also disables G-SYNC negotiation retries (nvidia-modeset conceal_vrr_caps)
on displays where it repeatedly fails to initialize - each failed retry
forces a display re-sync, which shows up as the screen going dark and
flashing for a moment, several times a day. Harmless to disable since
VRR is already off in KDE for every output on this laptop anyway.

⚠️  EnvyControl will manage /etc/X11/xorg.conf and related files.
    Do not manually edit these files after this step.

To switch modes manually instead of using the hotkey:
  sudo envycontrol -s nvidia          # Docked - external monitor, dGPU always on
  sudo envycontrol -s hybrid --rtd3 2 # Mobile - battery saving, PRIME offload
  sudo envycontrol -s integrated      # Maximum battery, dGPU fully off
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

    # Default to nvidia mode - matches the docked/external-monitor use case
    # that covers the vast majority of actual usage on this laptop
    print_info "Setting GPU mode to nvidia (docked default)..."
    sudo envycontrol -s nvidia --dm sddm

    # Extra NVIDIA options EnvyControl doesn't set, in our own file so
    # they survive EnvyControl rewriting nvidia.conf on future mode switches
    print_info "Configuring additional NVIDIA kernel module options..."
    cat << 'EOF' | sudo tee /etc/modprobe.d/99-nvidia-extra.conf > /dev/null
options nvidia NVreg_PreserveVideoMemoryAllocations=1
# Stops the driver from repeatedly retrying (and failing) G-SYNC
# negotiation on monitors where it doesn't work - each failed retry
# forces the display to re-sync, visible as the screen going dark and
# flashing for a moment. VRR is already disabled in KDE for every
# output on this laptop, so conceal_vrr_caps costs nothing right now.
options nvidia-modeset conceal_vrr_caps=1
EOF

    # Install the docked/mobile GPU mode toggle script and the
    # auto-detect monitor service that calls it
    print_info "Installing GPU mode toggle script and monitor service..."
    mkdir -p ~/.local/bin ~/.config/systemd/user
    cp "$SCRIPT_DIR/scripts/gpu-mode-toggle.sh" ~/.local/bin/gpu-mode-toggle.sh
    cp "$SCRIPT_DIR/scripts/gpu-mode-monitor.sh" ~/.local/bin/gpu-mode-monitor.sh
    chmod +x ~/.local/bin/gpu-mode-toggle.sh ~/.local/bin/gpu-mode-monitor.sh
    cp "$SCRIPT_DIR/scripts/gpu-mode-monitor.service" ~/.config/systemd/user/gpu-mode-monitor.service

    systemctl --user daemon-reload
    systemctl --user enable --now gpu-mode-monitor.service 2>/dev/null \
        || print_info "gpu-mode-monitor.service will start on next login (normal before reboot)"

    print_success "EnvyControl installed and GPU set to nvidia mode (docked default)"
    print_info "G-SYNC negotiation retries disabled (prevents periodic screen flashing)"
    print_info "Auto-detect service running: unplugging/plugging the external monitor"
    print_info "  will now prompt you to switch GPU modes"
    print_info "Optional hotkey: System Settings > Shortcuts > Custom Shortcuts >"
    print_info "  New > Global Shortcut > Command/URL, set command to:"
    print_info "  ~/.local/bin/gpu-mode-toggle.sh"
    print_info "To switch modes manually: sudo envycontrol -s [integrated|hybrid|nvidia]"
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
  - caligula: USB boot drive imaging tool, used by the Backup Configs menu
    option to offer creating a CachyOS boot drive (from official repo)
  - bitwarden: Password manager
  - steam: Gaming platform
  - vlc: Media player
  - visual-studio-code-bin: Code editor (from AUR)
  - obsidian: Note-taking and knowledge base (from AUR)
  - wezterm: GPU-accelerated terminal emulator (from AUR)
  - ttf-ibmplex-mono-nerd: BlexMono Nerd Font (for WezTerm, from official repo)
  - razer-control-revived: Razer hardware control (fan, RGB, battery, power)
  - razer-control KDE widget: Panel widget for quick Razer hardware access
  - handy: Offline, local speech-to-text transcription (from AUR, handy-bin)
  - gtk-layer-shell + wtype + openblas: Handy's Linux/Wayland runtime dependencies

Razer Control Revived provides:
  - Fan speed control
  - Keyboard RGB lighting
  - Battery charge limit (extends battery lifespan)
  - Real-time CPU/GPU power monitoring
  - KDE Plasma widget for panel integration

Handy needs a couple of Linux-specific pieces to work well under Wayland:
  - gtk-layer-shell: required at runtime, missing/broken installs are the
    most common cause of Handy crashing on startup
  - wtype: needed for reliable text input on Wayland (without it, Handy
    falls back to a less compatible method)
  - openblas: not declared as a dependency by the handy-bin AUR package
    at all, but Handy fails to even launch without it
    ('error while loading shared libraries: libopenblas.so.0') - we
    install it explicitly to work around that packaging gap
  - Wayland has no app-level global shortcuts, so you'll need to bind one
    yourself after install: System Settings > Shortcuts > Custom Shortcuts
    > New > Global Shortcut > Command/URL, command: handy --toggle-transcription

This may take 15-25 minutes depending on your system and internet speed."; then

    print_header "Step 8: Installing Applications"

    # Define packages
    OFFICIAL_PACKAGES="discord steam vlc ttf-ibmplex-mono-nerd vivaldi vivaldi-ffmpeg-codecs caligula gtk-layer-shell wtype openblas"
    AUR_PACKAGES="bitwarden visual-studio-code-bin obsidian wezterm handy-bin"

    # Install official packages
    print_info "Installing packages from official repositories..."
    sudo pacman -S --noconfirm $OFFICIAL_PACKAGES

    # Install AUR packages
    print_info "Installing packages from AUR (this may take a while)..."
    yay -S --noconfirm $AUR_PACKAGES

    # Install Razer Control Revived from the latest GitHub release tarball.
    # Always grabs the latest release rather than pinning a version - this
    # project ships frequent per-device detection fixes (device matching
    # for composite HID interfaces is a known source of "no supported
    # device found" bugs on some Blade models), so an old pinned version
    # can end up permanently broken for a device that later releases fix.
    print_info "Installing Razer Control Revived..."
    RAZER_RELEASE_JSON=$(curl -sL --connect-timeout 10 --max-time 15 \
        "https://api.github.com/repos/encomjp/razer-control-revived/releases/latest")
    RAZER_URL=$(grep -oP '"browser_download_url":\s*"\K[^"]*razer-control-[^"]*-x86_64\.tar\.gz' <<<"$RAZER_RELEASE_JSON" | head -1)
    RAZER_TAG=$(grep -oP '"tag_name":\s*"\K[^"]+' <<<"$RAZER_RELEASE_JSON" | head -1)
    if [ -z "$RAZER_URL" ]; then
        print_warning "Could not determine latest Razer Control Revived release, falling back to v0.3.4"
        RAZER_URL="https://github.com/encomjp/razer-control-revived/releases/download/v0.3.4/razer-control-0.3.4-x86_64.tar.gz"
        RAZER_TAG="v0.3.4"
    fi
    RAZER_TARBALL="$(basename "$RAZER_URL")"
    RAZER_TMP="/tmp/razer-control"

    mkdir -p "$RAZER_TMP"
    print_info "Downloading Razer Control Revived ($RAZER_TARBALL)..."
    curl -L "$RAZER_URL" -o "$RAZER_TMP/$RAZER_TARBALL"

    print_info "Extracting and installing daemon..."
    tar xzf "$RAZER_TMP/$RAZER_TARBALL" -C "$RAZER_TMP"
    RAZER_EXTRACTED_DIR=$(tar tzf "$RAZER_TMP/$RAZER_TARBALL" | head -1 | cut -d/ -f1)

    # Run install.sh as normal user - it calls sudo internally where needed
    (
        cd "$RAZER_TMP/$RAZER_EXTRACTED_DIR" || exit 1
        bash ./install.sh
    ) || print_warning "Razer Control daemon install had issues - may need manual install"

    # Record which release we installed, so Backup Configs can later check
    # whether a newer one has shipped (e.g. a fix for a known bug)
    mkdir -p ~/.local/share/razercontrol
    echo "$RAZER_TAG" > ~/.local/share/razercontrol/.installed-version

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
    print_info "Handy needs a hotkey bound manually (Wayland has no app-level global shortcuts):"
    print_info "  System Settings → Shortcuts → Custom Shortcuts → New → Global Shortcut →"
    print_info "  Command/URL, set command to: handy --toggle-transcription"
fi

################################################################################
# STEP 9: Remove Unwanted Software
################################################################################

if ask_continue "Remove Unwanted Software" \
"This step removes pre-installed software and their configs:

Removing:
  - alacritty: Default terminal (replaced by WezTerm)
  - firefox: Default browser (replaced by Vivaldi), including both the
    legacy (~/.mozilla) and XDG-compliant (~/.config/mozilla) profile
    paths - which one is actually used varies by build
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
        # .mozilla is the legacy profile path; this CachyOS Firefox build
        # actually uses the XDG-compliant .config/mozilla instead - both
        # are removed since which one is used can vary by build/version
        remove_package_with_configs "firefox" ".mozilla" ".cache/mozilla" ".config/mozilla"

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
  - Obsidian → ~/.config/obsidian/ (settings/window-state only, not Chromium internals)
  - VS Code → ~/.config/Code/User/settings.json (if available)
  - Vivaldi → ~/.config/vivaldi/ (bookmarks/preferences only, if available)
  - Handy → ~/.config/com.pais.handy/settings_store.json (if available)
  - KWin scripts → ~/.local/share/kwin/scripts/ (if available)
  - Custom icons → ~/.local/share/icons/ (if available)
  - Custom wallpapers → ~/.local/share/wallpapers/ (if available)
  - Shared Plasma widget QML/assets → ~/.local/share/plasma-widgets-shared/ (if available)
  - System Monitor sensor faces → ~/.local/share/ksysguard/sensorfaces/ (if available)
  - Widget setup scripts → ~/.local/share/scripts/widgets/ (if available)
  - Neon moon source photo → ~/Pictures/ (if available)
  - HuginWB widget → ~/.local/share/plasma/plasmoids/HuginWB/ (if available)

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
            "khotkeysrc"
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

    # Deploy Obsidian settings (small top-level settings/window-state
    # files only - matches the allow-list in .gitignore and backup_configs())
    if [ -d "$SCRIPT_DIR/configs/obsidian" ]; then
        print_info "Deploying Obsidian settings..."
        mkdir -p ~/.config/obsidian
        find "$SCRIPT_DIR/configs/obsidian" -maxdepth 1 -type f \( -name "*.json" -o -name "obsidian.log" \) \
            -exec cp {} ~/.config/obsidian/ \;
        print_success "Obsidian settings deployed"
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

    # Deploy Handy settings
    if [ -f "$SCRIPT_DIR/configs/handy/settings_store.json" ]; then
        print_info "Deploying Handy settings..."
        mkdir -p ~/.config/com.pais.handy
        cp "$SCRIPT_DIR/configs/handy/settings_store.json" ~/.config/com.pais.handy/
        print_success "Handy settings deployed"
    else
        print_info "No Handy settings found, skipping"
    fi

    # Deploy KWin scripts (e.g. Truely Maximized)
    if [ -d "$SCRIPT_DIR/configs/kwin-scripts" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/kwin-scripts" 2>/dev/null)" ]; then
        print_info "Deploying KWin scripts..."
        mkdir -p ~/.local/share/kwin/scripts
        cp -r "$SCRIPT_DIR/configs/kwin-scripts/." ~/.local/share/kwin/scripts/
        print_success "KWin scripts deployed"
    else
        print_info "No KWin scripts found, skipping"
    fi

    # Deploy custom icons (hicolor only - see below for downloaded themes)
    if [ -d "$SCRIPT_DIR/configs/icons/hicolor" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/icons/hicolor" 2>/dev/null)" ]; then
        print_info "Deploying custom icons..."
        mkdir -p ~/.local/share/icons/hicolor
        command -v rsync &>/dev/null || sudo pacman -S --noconfirm --needed rsync
        rsync -a "$SCRIPT_DIR/configs/icons/hicolor/" ~/.local/share/icons/hicolor/ 2>/dev/null || true
        print_success "Custom icons deployed"
    else
        print_info "No custom icons found, skipping"
    fi

    # Downloaded icon themes aren't backed up as files (see backup_configs) -
    # print the reference list so they can be reinstalled via System
    # Settings' "Get New Icons" dialog instead
    if [ -f "$SCRIPT_DIR/configs/icons/DOWNLOADED-THEMES.md" ]; then
        print_info "Downloaded icon themes to reinstall manually:"
        cat "$SCRIPT_DIR/configs/icons/DOWNLOADED-THEMES.md"
    fi

    if [ -d "$SCRIPT_DIR/configs/wallpapers" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/wallpapers" 2>/dev/null)" ]; then
        print_info "Deploying custom wallpapers..."
        mkdir -p ~/.local/share/wallpapers
        cp -r "$SCRIPT_DIR/configs/wallpapers/." ~/.local/share/wallpapers/
        print_success "Custom wallpapers deployed"
    else
        print_info "No custom wallpapers found, skipping"
    fi

    # Deploy shared Plasma widget QML/assets
    if [ -d "$SCRIPT_DIR/configs/plasma-widgets-shared" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/plasma-widgets-shared" 2>/dev/null)" ]; then
        print_info "Deploying shared Plasma widget QML/assets..."
        mkdir -p ~/.local/share/plasma-widgets-shared
        cp -r "$SCRIPT_DIR/configs/plasma-widgets-shared/." ~/.local/share/plasma-widgets-shared/
        print_success "Shared Plasma widget QML/assets deployed"
    else
        print_info "No shared Plasma widget QML/assets found, skipping"
    fi

    # Deploy custom System Monitor sensor faces (still need to be manually
    # re-added as widgets via the GUI afterwards - see
    # POST_INSTALL_WIDGET_SETUP.md in the Obsidian vault)
    if [ -d "$SCRIPT_DIR/configs/sensorfaces" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/sensorfaces" 2>/dev/null)" ]; then
        print_info "Deploying custom System Monitor sensor faces..."
        mkdir -p ~/.local/share/ksysguard/sensorfaces
        cp -r "$SCRIPT_DIR/configs/sensorfaces/." ~/.local/share/ksysguard/sensorfaces/
        print_success "Custom System Monitor sensor faces deployed"
    else
        print_info "No custom System Monitor sensor faces found, skipping"
    fi

    # Deploy widget setup/calibration scripts
    if [ -d "$SCRIPT_DIR/configs/widget-scripts" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/widget-scripts" 2>/dev/null)" ]; then
        print_info "Deploying widget setup scripts..."
        mkdir -p ~/.local/share/scripts/widgets
        cp -r "$SCRIPT_DIR/configs/widget-scripts/." ~/.local/share/scripts/widgets/
        print_success "Widget setup scripts deployed"
        print_info "See POST_INSTALL_WIDGET_SETUP.md in the Obsidian vault for the manual re-add step"
    else
        print_info "No widget setup scripts found, skipping"
    fi

    # Deploy neon moon source photo
    if [ -f "$SCRIPT_DIR/configs/widget-source/neon-moon-dreams-stockcake.jpg" ]; then
        print_info "Deploying neon moon source photo..."
        mkdir -p ~/Pictures
        cp "$SCRIPT_DIR/configs/widget-source/neon-moon-dreams-stockcake.jpg" ~/Pictures/
        print_success "Neon moon source photo deployed"
    else
        print_info "No neon moon source photo found, skipping"
    fi

    # Deploy custom-built plasmoids
    if [ -d "$SCRIPT_DIR/configs/widgets/HuginWB" ] && [ -n "$(ls -A "$SCRIPT_DIR/configs/widgets/HuginWB" 2>/dev/null)" ]; then
        print_info "Deploying HuginWB widget..."
        mkdir -p ~/.local/share/plasma/plasmoids/HuginWB
        cp -r "$SCRIPT_DIR/configs/widgets/HuginWB/." ~/.local/share/plasma/plasmoids/HuginWB/
        print_success "HuginWB widget deployed"
        print_info "Restart plasmashell (or log out/in) to pick it up, then add it to your panel via Add Widgets"
    else
        print_info "No HuginWB widget found, skipping"
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
# STEP 14: Open Firewall Ports for KDE Connect
################################################################################

if ask_continue "Open Firewall Ports for KDE Connect" \
"This step opens the firewall ports KDE Connect needs to discover and pair
with your phone. KDE Connect is already installed by default (it comes
bundled with Plasma), but ufw blocks its discovery/pairing traffic out of
the box, so it silently fails to find any devices until these ports are
opened.

KDE Connect uses UDP/TCP ports 1714-1764 for device discovery, pairing,
and file transfer.

We'll run:
  sudo ufw allow 1714:1764/udp
  sudo ufw allow 1714:1764/tcp
  sudo ufw reload

These commands are safe to run again later (ufw skips duplicate rules)."; then

    print_header "Step 14: Configuring Firewall for KDE Connect"

    command -v kdeconnectd &>/dev/null || sudo pacman -S --noconfirm --needed kdeconnect

    if command -v ufw &>/dev/null; then
        sudo ufw allow 1714:1764/udp
        sudo ufw allow 1714:1764/tcp
        sudo ufw reload
        print_success "Firewall ports 1714-1764 (TCP/UDP) opened for KDE Connect"
    else
        print_warning "ufw not found - skipping firewall configuration"
        print_info "If you use a different firewall, open TCP/UDP ports 1714-1764 manually"
    fi
fi

################################################################################
# FINAL SUMMARY
################################################################################

print_header "Setup Complete!"

echo -e "${GREEN}All steps completed successfully!${NC}\n"

echo "Summary of what was done:"
echo "  ✓ System updated to latest packages"
echo "  ✓ NVIDIA drivers installed/verified"
echo "  ✓ XWayland installed, Plasma Wayland set as default session (X11 available as fallback)"
echo "  ✓ NumLock enabled on the SDDM login screen"
echo "  ✓ GLX vendor configured for NVIDIA"
echo "  ✓ EnvyControl installed - GPU set to nvidia mode (docked default)"
echo "  ✓ GPU mode auto-detect service running - prompts to switch nvidia/hybrid on monitor plug/unplug"
echo "  ✓ GPU mode toggle script installed (~/.local/bin/gpu-mode-toggle.sh) - optional hotkey for manual switching"
echo "  ✓ switcheroo-control and thermald installed and enabled"
echo "  ✓ Initramfs rebuilt with new configuration"
echo "  ✓ YAY AUR helper installed"
echo "  ✓ Gaming meta package installed"
echo "  ✓ Applications installed (Discord, Vivaldi, Bitwarden, Steam, VLC, VS Code, Obsidian, WezTerm, Handy)"
echo "  ✓ Razer Control Revived installed (fan, RGB, battery, power monitoring)"
echo "  ✓ Razer Control KDE widget installed"
echo "  ✓ Unwanted software removed (Alacritty, Firefox)"
echo "  ✓ NVIDIA power management services enabled"
echo "  ✓ Custom configurations deployed"
echo "  ✓ Proton Drive CLI installed (sign in with: proton-drive auth login)"
echo "  ✓ Firewall ports opened for KDE Connect (1714-1764 TCP/UDP)"
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
echo "  ~/.local/bin/gpu-mode-toggle.sh   # Toggle nvidia <-> hybrid manually (or bind to a hotkey)"
echo "  systemctl --user status gpu-mode-monitor  # Check the auto-detect service"
echo "  envycontrol --query              # Check current GPU mode"
echo "  prime-run <program>              # Force an app onto the RTX 3080 (hybrid mode)"
echo "  sudo envycontrol -s hybrid --rtd3 2  # Switch to hybrid (mobile, battery saving)"
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
