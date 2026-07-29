#!/bin/bash
################################################################################
# CachyOS Razer 17 Setup - USB Bootstrap
#
# Lives on a small FAT32 partition alongside the CachyOS install image on
# the boot USB. Run this after booting the live environment (or after a
# fresh install) to pull down the setup repo without typing the clone
# command from memory.
################################################################################

set -uo pipefail

REPO_URL="https://github.com/huginkronstam/cachyosrazer17setup"
DEST="$HOME/CachyOsRazer17Setup"

echo "CachyOS Razer 17 Setup - Bootstrap"
echo "This will install git (if needed) and clone:"
echo "  $REPO_URL"
echo "into:"
echo "  $DEST"
echo ""
read -p "Continue? [y/N] " confirm
case "$confirm" in
[Yy]*) ;;
*)
    echo "Cancelled"
    exit 0
    ;;
esac

sudo pacman -Sy --needed --noconfirm git

if [ -d "$DEST" ]; then
    echo "Already cloned at $DEST"
else
    git clone "$REPO_URL" "$DEST"
fi

echo ""
echo "Done. Next steps:"
echo "  cd $DEST"
echo "  ./cachyos-setup.sh"
