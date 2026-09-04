#!/bin/bash
################################################################################
# Disposable CachyOS test install - Btrfs subvolume based
#
# Builds a second, real, bootable CachyOS install into new Btrfs subvolumes
# on the SAME physical partition as the main system (no new partition, no
# VM/container - genuine hardware/GPU access for testing cachyos-setup.sh,
# especially the NVIDIA/hybrid-graphics steps). Shares the existing ESP
# (/boot) with the main system via a bind mount rather than a dedicated boot
# partition - see the kernel-file collision handling in cmd_create below.
#
# Subcommands:
#   backup-esp   Raw-image the ESP before anything touches it (run once, first)
#   create       Build the test install (subvolumes, base system, boot entry)
#   baseline     Snapshot the current @test/@test-home as the revert target
#   revert       Wipe @test/@test-home, restore instantly from the baseline
#   destroy      Full teardown - subvolumes, boot entry, kernel files
#
# Run every subcommand from the MAIN system, not while booted into the test
# install. Booting into "CachyOS (TEST - disposable)" itself just happens
# from the systemd-boot menu once `create` has run - nothing to run for that.
################################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() { echo -e "\n${BLUE}================================${NC}\n${BLUE}$1${NC}\n${BLUE}================================${NC}\n"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# This machine's actual layout (see cachyos-setup.sh header comment / README
# for how this was confirmed) - edit if the disk is ever repartitioned.
BTRFS_UUID="effcb6a1-580c-45be-8ee2-4b15d3c505c6"
ESP_UUID="3536-6D5F"
ESP_DEV="/dev/nvme0n1p1"

BTRFS_TOP_MOUNT="/mnt/btrfs-top"
TEST_ROOT_MOUNT="/mnt/test-root"
ESP_BACKUP_PATH="$HOME/esp-backup-pre-test.img"
BOOT_ENTRY="/boot/loader/entries/cachyos-test.conf"
BOOT_TEST_DIR="/boot/test"
TEST_USERNAME="hugin"

# Mounts the true top-level of the btrfs filesystem (subvolid=5, where the
# @-prefixed subvolumes themselves live, as opposed to any single subvolume's
# own view of it) at $BTRFS_TOP_MOUNT, if not already mounted there.
mount_btrfs_top() {
    mountpoint -q "$BTRFS_TOP_MOUNT" 2>/dev/null && return 0
    sudo mkdir -p "$BTRFS_TOP_MOUNT"
    sudo mount -o subvolid=5 "UUID=$BTRFS_UUID" "$BTRFS_TOP_MOUNT"
}

subvol_exists() {
    sudo btrfs subvolume show "$BTRFS_TOP_MOUNT/$1" &>/dev/null
}

cmd_backup_esp() {
    print_header "Backing Up ESP (/boot) Before Any Changes"

    if [ -f "$ESP_BACKUP_PATH" ]; then
        print_warning "$ESP_BACKUP_PATH already exists"
        read -p "Overwrite it with a fresh backup? [y/N] " confirm
        case $confirm in
            [Yy]*) ;;
            *) print_info "Keeping existing backup"; return 0 ;;
        esac
    fi

    print_info "Imaging $ESP_DEV -> $ESP_BACKUP_PATH"
    print_info "This is the safety net for the whole exercise - keep it until the test"
    print_info "install is confirmed working and reverted at least once."
    sudo dd if="$ESP_DEV" of="$ESP_BACKUP_PATH" bs=4M status=progress
    sudo chown "$USER:$USER" "$ESP_BACKUP_PATH"
    print_success "ESP backed up to $ESP_BACKUP_PATH"
    print_info "To restore if anything goes badly wrong:"
    echo "  sudo dd if=$ESP_BACKUP_PATH of=$ESP_DEV bs=4M status=progress"
}

cmd_create() {
    print_header "Creating Disposable Test Install"

    if [ ! -f "$ESP_BACKUP_PATH" ]; then
        print_error "No ESP backup found at $ESP_BACKUP_PATH"
        print_info "Run '$0 backup-esp' first - this step edits the shared boot partition"
        return 1
    fi

    local cmd
    for cmd in pacstrap genfstab arch-chroot; do
        command -v "$cmd" &>/dev/null || {
            print_error "$cmd not found"
            print_info "Install it: sudo pacman -S --needed --noconfirm arch-install-scripts"
            return 1
        }
    done

    print_info "Creating @test and @test-home subvolumes..."
    mount_btrfs_top
    if subvol_exists "@test"; then
        print_error "@test already exists - run '$0 destroy' first if you want to start over"
        return 1
    fi
    sudo btrfs subvolume create "$BTRFS_TOP_MOUNT/@test"
    sudo btrfs subvolume create "$BTRFS_TOP_MOUNT/@test-home"

    print_info "Mounting for install..."
    sudo mkdir -p "$TEST_ROOT_MOUNT"
    sudo mount -o "subvol=@test,compress=zstd,noatime" "UUID=$BTRFS_UUID" "$TEST_ROOT_MOUNT"
    sudo mkdir -p "$TEST_ROOT_MOUNT/home" "$TEST_ROOT_MOUNT/boot"
    sudo mount -o "subvol=@test-home,compress=zstd,noatime" "UUID=$BTRFS_UUID" "$TEST_ROOT_MOUNT/home"
    # Bind mount, not a second independent mount of the ESP device - the ESP
    # is already mounted at /boot by the main system, and mounting the same
    # block device twice as two separate mount instances risks the two
    # instances caching/writing its FAT metadata inconsistently. A bind
    # mount is just a second path onto the exact same existing mount, so
    # there's still only one real mount of the filesystem.
    sudo mount --bind /boot "$TEST_ROOT_MOUNT/boot"

    print_info "Installing base system (a real KDE desktop worth of packages - takes a while)..."
    if ! sudo pacstrap "$TEST_ROOT_MOUNT" base linux-cachyos linux-cachyos-headers linux-firmware \
        networkmanager sudo plasma-meta sddm cachyos-kde-settings nano; then
        print_error "pacstrap failed - test install left half-built"
        print_info "Inspect $TEST_ROOT_MOUNT, or run '$0 destroy' to clean up and start over"
        return 1
    fi

    print_info "Generating fstab..."
    # genfstab would describe /boot as whatever bind-mount arrangement got
    # it here, which is meaningless once the test install boots on its own -
    # drop whatever it wrote for /boot and replace with a plain direct UUID
    # mount, matching how the main system's own /etc/fstab mounts the ESP.
    genfstab -U "$TEST_ROOT_MOUNT" | grep -v '[[:space:]]/boot[[:space:]]' \
        | sudo tee -a "$TEST_ROOT_MOUNT/etc/fstab" > /dev/null
    echo "UUID=$ESP_UUID /boot vfat defaults,umask=0077 0 2" \
        | sudo tee -a "$TEST_ROOT_MOUNT/etc/fstab" > /dev/null
    print_warning "Generated fstab (double check this before rebooting into the test install):"
    grep -E '^\S' "$TEST_ROOT_MOUNT/etc/fstab" | tail -4

    print_info "Configuring the new install (timezone, locale, hostname, user, bootloader)..."
    if ! sudo arch-chroot "$TEST_ROOT_MOUNT" /bin/bash -e <<CHROOT_EOF
ln -sf /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime
hwclock --systohc
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "cachyos-test" > /etc/hostname
useradd -m -G wheel -s /bin/bash "$TEST_USERNAME"
echo "$TEST_USERNAME:$TEST_USERNAME" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
systemctl enable NetworkManager sddm

mkdir -p "$BOOT_TEST_DIR"
sed -i 's|^ALL_kver=.*|ALL_kver="$BOOT_TEST_DIR/vmlinuz-linux-cachyos"|' /etc/mkinitcpio.d/linux-cachyos.preset
sed -i 's|^default_image=.*|default_image="$BOOT_TEST_DIR/initramfs-linux-cachyos.img"|' /etc/mkinitcpio.d/linux-cachyos.preset
mkinitcpio -P
CHROOT_EOF
    then
        print_error "chroot configuration failed - test install left half-built"
        print_info "Inspect $TEST_ROOT_MOUNT, or run '$0 destroy' to clean up and start over"
        return 1
    fi

    print_info "Set a real password for the test install's '$TEST_USERNAME' user (currently just '$TEST_USERNAME'):"
    sudo arch-chroot "$TEST_ROOT_MOUNT" passwd "$TEST_USERNAME"

    print_info "Adding systemd-boot entry..."
    cat <<BOOTENTRY | sudo tee "$BOOT_ENTRY" > /dev/null
title   CachyOS (TEST - disposable)
linux   /test/vmlinuz-linux-cachyos
initrd  /test/initramfs-linux-cachyos.img
options root=UUID=$BTRFS_UUID rootflags=subvol=/@test rw quiet
BOOTENTRY

    print_info "Unmounting..."
    sudo umount -R "$TEST_ROOT_MOUNT"

    print_success "Test install created"
    print_info "Reboot and pick 'CachyOS (TEST - disposable)' at the systemd-boot menu"
    print_info "Once you're happy with a clean baseline in it: $0 baseline"
}

cmd_baseline() {
    print_header "Snapshotting Test Install Baseline"

    mount_btrfs_top
    if ! subvol_exists "@test"; then
        print_error "@test doesn't exist - run '$0 create' first"
        return 1
    fi
    if subvol_exists "@test-baseline"; then
        print_warning "@test-baseline already exists"
        read -p "Replace it with a new baseline from the current @test state? [y/N] " confirm
        case $confirm in
            [Yy]*) sudo btrfs subvolume delete "$BTRFS_TOP_MOUNT/@test-baseline" "$BTRFS_TOP_MOUNT/@test-home-baseline" ;;
            *) print_info "Keeping existing baseline"; return 0 ;;
        esac
    fi

    sudo btrfs subvolume snapshot "$BTRFS_TOP_MOUNT/@test" "$BTRFS_TOP_MOUNT/@test-baseline"
    sudo btrfs subvolume snapshot "$BTRFS_TOP_MOUNT/@test-home" "$BTRFS_TOP_MOUNT/@test-home-baseline"
    print_success "Baseline snapshot taken - '$0 revert' now resets to this exact state"
}

cmd_revert() {
    print_header "Reverting Test Install to Baseline"

    mount_btrfs_top
    if ! subvol_exists "@test-baseline"; then
        print_error "No baseline found - run '$0 baseline' first (after '$0 create')"
        return 1
    fi

    print_warning "This deletes the current @test/@test-home and replaces them with fresh"
    print_warning "copies of the baseline. Make sure you're NOT currently booted into the"
    print_warning "test install - this must run from the main system."
    read -p "Continue? [y/N] " confirm
    case $confirm in
        [Yy]*) ;;
        *) print_info "Cancelled"; return 0 ;;
    esac

    sudo umount -R "$TEST_ROOT_MOUNT" 2>/dev/null || true
    sudo btrfs subvolume delete "$BTRFS_TOP_MOUNT/@test" "$BTRFS_TOP_MOUNT/@test-home"
    sudo btrfs subvolume snapshot "$BTRFS_TOP_MOUNT/@test-baseline" "$BTRFS_TOP_MOUNT/@test"
    sudo btrfs subvolume snapshot "$BTRFS_TOP_MOUNT/@test-home-baseline" "$BTRFS_TOP_MOUNT/@test-home"
    print_success "Reverted - @test is back to the baseline snapshot"
}

cmd_destroy() {
    print_header "Destroying Test Install"

    print_warning "This permanently deletes the test install: subvolumes, baseline"
    print_warning "snapshot, boot entry, and kernel files. Main system is untouched."
    read -p "Continue? [y/N] " confirm
    case $confirm in
        [Yy]*) ;;
        *) print_info "Cancelled"; return 0 ;;
    esac

    mount_btrfs_top
    sudo umount -R "$TEST_ROOT_MOUNT" 2>/dev/null || true

    local subvol
    for subvol in @test @test-home @test-baseline @test-home-baseline; do
        subvol_exists "$subvol" && sudo btrfs subvolume delete "$BTRFS_TOP_MOUNT/$subvol"
    done

    sudo rm -f "$BOOT_ENTRY"
    sudo rm -rf "$BOOT_TEST_DIR"

    print_success "Test install fully removed"
}

usage() {
    echo "Usage: $0 {backup-esp|create|baseline|revert|destroy}"
    echo ""
    echo "  backup-esp  Raw-image the shared ESP before making any changes (run first, once)"
    echo "  create      Build the disposable test install (subvolumes + base system + boot entry)"
    echo "  baseline    Snapshot the current test install state as the revert target"
    echo "  revert      Wipe the test install and restore it from the baseline snapshot (seconds)"
    echo "  destroy     Fully remove the test install (subvolumes, boot entry, kernel files)"
}

case "${1:-}" in
    backup-esp) cmd_backup_esp ;;
    create) cmd_create ;;
    baseline) cmd_baseline ;;
    revert) cmd_revert ;;
    destroy) cmd_destroy ;;
    *) usage; exit 1 ;;
esac
