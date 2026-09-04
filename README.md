# CachyOS Razer 17 Setup Script

## Repository Structure

```
CachyOsRazer17Setup/
├── cachyos-setup.sh       # Main installation script
├── post-reboot.sh         # Post-reboot verification, runs automatically once
├── README.md              # This file
├── .gitignore             # Protects sensitive data
├── scripts/               # Helper scripts installed to ~/.local/bin
│   ├── gpu-mode-toggle.sh     # Manual nvidia/hybrid switch (bind to a hotkey)
│   ├── gpu-mode-monitor.sh    # Auto-detects external monitor, prompts to switch
│   └── gpu-mode-monitor.service   # systemd --user unit for the monitor
└── configs/               # Your custom configuration files
    ├── README.md          # Config management guide
    ├── wezterm/
    │   └── wezterm.lua    # WezTerm terminal config
    ├── kde/
    │   └── (KDE configs)  # KDE customizations
    ├── obsidian/
    │   └── (configs)      # Obsidian configs
    ├── vscode/
    │   └── settings.json  # VS Code settings
    ├── vivaldi/
    │   └── (configs)      # Vivaldi bookmarks/preferences (no cache/cookies/logins)
    ├── handy/
    │   └── settings_store.json  # Handy settings
    ├── kwin-scripts/
    │   └── (scripts)      # KWin scripts (e.g. Truely Maximized) - not packages, so files are backed up directly
    ├── icons/
    │   ├── hicolor/       # Your own custom icons only
    │   └── DOWNLOADED-THEMES.md  # Reinstall links for downloaded icon themes (not backed up as files)
    ├── wallpapers/
    │   └── (images)       # Custom wallpapers
    └── widgets/
        ├── TODO.md        # Notes/follow-ups for the custom widgets below
        └── HuginWB/       # Custom-built panel widget (window buttons), full plasmoid package
```

## Quick Start - Fresh Install

### 1. On Fresh CachyOS Installation

```bash
# Clone this repository
git clone https://github.com/yourusername/CachyOsRazer17Setup.git
cd CachyOsRazer17Setup

# Make script executable
chmod +x cachyos-setup.sh

# Run the script
./cachyos-setup.sh
```

### 2. Select from Menu

```
╔════════════════════════════════════════╗
║   CachyOS Razer 17 Setup Script       ║
╚════════════════════════════════════════╝

1) Setup System
2) Backup Configs
3) Backup Obsidian Vault to Proton Drive
4) Restore Obsidian Vault from Proton Drive
5) Backup Contacts to Proton Drive
6) Exit
```

- **Option 1**: Install system (choose interactive/automatic mode)
- **Option 2**: Backup your current configs to ./configs/, and offer to create a CachyOS boot drive if a suitable USB stick is plugged in
- **Option 3**: Upload your Obsidian vault to Proton Drive
- **Option 4**: Download your Obsidian vault from Proton Drive (overwrites local changes that differ)
- **Option 5**: Upload your Radicale contacts collection to Proton Drive
- **Option 6**: Exit

### 3. Follow the Prompts

If you chose interactive mode, the script will explain each step and let you skip if needed.

### 4. Reboot

After the script completes, reboot to apply all changes.

## Features

### Setup System
- Updates all packages
- Installs and configures NVIDIA drivers for RTX 3080 Mobile
- Installs XWayland support, sets Plasma **Wayland** as the default session (X11 stays available as a fallback)
- Sets GPU mode to **nvidia** by default, with an auto-detect service and a toggle script for switching to **hybrid** when mobile
- Installs gaming optimizations
- Installs your application suite
- Removes unwanted pre-installed software
- Deploys your custom configurations

### Backup Configs
- Backs up WezTerm configuration
- Backs up all KDE customizations (fonts, shortcuts, panel layout/position, custom shortcuts, etc.)
- Backs up Obsidian configs
- Backs up VS Code settings
- Backs up Vivaldi bookmarks/preferences
- Backs up Handy settings
- Backs up KWin scripts (e.g. Truely Maximized) - these aren't packages, so
  their actual files have to be backed up, not just their settings
- Backs up custom icons (~/.local/share/icons/hicolor/ only - your own
  icons, not downloaded icon themes) and wallpapers (~/.local/share/wallpapers/)
- Records which full icon themes are installed (downloaded via System
  Settings' "Get New Icons") as a name + store.kde.org link list instead of
  backing up their files - these can run into the hundreds of MB and are a
  couple of clicks to reinstall, so it's not worth carrying someone else's
  SVGs through git. The list, including which theme is active, is printed
  during Deploy Custom Configurations as a reminder to reinstall them
- Backs up custom-built plasmoids (~/.local/share/plasma/plasmoids/), e.g.
  HuginWB, our own window-buttons panel widget (see configs/widgets/TODO.md)
- Backs up Kando settings (config.json/menus.json/achievements.json and any
  custom icon/menu/sound themes), not the rest of ~/.config/kando, which is
  a full Chromium/Electron profile (cache, cookies, local storage)
- Backs up Claude Code's settings.json, installed-plugin-marketplace list,
  and this project's persistent memory - not ~/.claude/.credentials.json or
  ~/.claude.json (both hold auth/account data), and not session transcripts
  or any other runtime/cache state
- Checks whether a newer Razer Control Revived release is available (compares
  against `~/.local/share/razercontrol/.installed-version`, written when Step 8
  installs it) - useful for tracking known upstream bugs until they're fixed,
  without having to remember to check manually
- Saves everything to ./configs/ ready for git commit
- Also checks for an attached USB drive with enough space and offers to create a
  CachyOS boot drive with [Caligula](https://github.com/ifd3f/caligula) - see below

### Obsidian Vault Backup/Restore (Proton Drive)
- Uses the official [Proton Drive CLI](https://proton.me/blog/proton-drive-cli) (`proton-drive-cli-bin` from the AUR)
- Backs up your actual notes (not just app settings) to `/my-files/<vault name>` on Proton Drive
- Restore pulls the vault back down - local files that differ are replaced with the Proton Drive version
- Requires signing in once with `proton-drive auth login` (opens a browser; the script can't do this non-interactively)

### Contacts Backup (Proton Drive)
- Backs up the local Radicale CardDAV collection (the address book KAddressBook
  and DAVx5/Android both sync through - see "Self-hosted contact sync" below) to
  `/my-files/contacts` on Proton Drive
- Same incremental-upload logic as the Obsidian backup, just no restore side yet -
  restoring into a live Radicale collection needs more care than downloading a
  folder back into place, so for now this is backup-only
- Radicale's storage (`/var/lib/radicale/collections/...`) is owned by the
  `radicale` system user/group at `750` - your user needs to be in that group to
  read it without sudo on every backup run:
  ```bash
  sudo usermod -aG radicale "$USER"   # then log out/in once
  ```

### Self-hosted Contact Sync (Radicale + Tailscale + DAVx5)
Contacts are synced across devices without Google, using open protocols instead
of a vendor's account:
- **[Radicale](https://radicale.org/)** runs as a systemd service
  (`/etc/radicale/config`, tracked at `configs/radicale/config`), storing
  contacts as plain vCards - this is the source of truth
- **[Tailscale](https://tailscale.com/)** gives the phone a private route to
  reach wherever Radicale is running, without exposing anything to the public
  internet
- **KAddressBook** (via Akonadi's DAV Groupware resource) and **[DAVx5](https://www.davx5.com/)**
  (Android, syncs into the native Contacts app) are two independent CardDAV
  clients both pointed at the same Radicale collection
- KDE Connect's own contacts-sync plugin is disabled on the paired device to
  avoid a second, conflicting write path into the same contacts

Setup System's **Step 15** installs and configures Radicale + Tailscale,
asking whether Radicale should go on this laptop or a remote host over SSH
(e.g. a future NAS - assumed to also be Arch-based). Tailscale is always
installed locally regardless, since this machine stays a CardDAV client
either way. What it can't do for you: `tailscale up` (browser login),
adding the DAV Groupware resource in KAddressBook, creating the address
book collection via Radicale's web UI, and setting up DAVx5 on the phone -
all one-time, interactive, and documented above as they came up.

## How to Use

### First Time Setup
1. Copy the script to your fresh CachyOS installation
2. Make it executable:
   ```bash
   chmod +x cachyos-setup.sh
   ```

### Running the Script

**Interactive Mode (Recommended for learning):**
```bash
./cachyos-setup.sh --interactive
```
- Explains each step before running it
- Lets you skip steps you don't need
- Great for understanding what's happening
- Press 'n' to skip a step, 'y' to continue, 'q' to quit

**Automatic Mode (Fast reinstalls):**
```bash
./cachyos-setup.sh
```
- Runs all steps automatically
- Perfect once you know everything works
- Faster for repeated installations

### What the Script Does

1. **System Update** - Updates all packages to latest versions
2. **NVIDIA Drivers** - Verifies/installs drivers for RTX 3080 Mobile
3. **XWayland Support** - Installs X11/XWayland packages (needed for X11-app
   compatibility under Wayland, and kept as a manual fallback session), sets
   Plasma **Wayland** as the default SDDM session, enables NumLock on the
   login screen (SDDM has its own separate NumLock setting, independent of
   the Plasma session's preference), and configures the GLX vendor for
   NVIDIA (used by XWayland apps and the X11 fallback) - all part of this
   same step, not a separate one
4. **YAY Installation** - Installs the AUR helper, needed before the next
   step since EnvyControl is an AUR package
5. **GPU Configuration** - Installs EnvyControl and sets GPU mode to
   **nvidia** by default (the external monitor on this laptop is wired
   directly to the dGPU, so it has to be awake for that anyway - measured,
   not assumed). Installs two ways to switch to **hybrid** (RTD3, dGPU
   sleeps when idle) for mobile/battery use:
   - `gpu-mode-monitor.service`: watches for the external monitor
     connecting/disconnecting and prompts you to switch
   - `gpu-mode-toggle.sh`: same prompt-and-switch logic, for a hotkey
   Also installs `nvidia-prime`, `switcheroo-control`, and `thermald`.
6. **Initramfs Rebuild** - Applies driver changes
7. **Gaming Setup** - Installs cachyos-gaming-meta package
8. **Applications** - Installs your software suite:
   - Discord
   - Vivaldi Browser
   - Bitwarden
   - Steam
   - VLC
   - VS Code
   - Obsidian (note-taking)
   - WezTerm (terminal)
   - BlexMono Nerd Font
   - Caligula (USB boot drive imaging, used by the Backup Configs menu option)
   - Handy (offline speech-to-text transcription)
   - Razer Control Revived + its KDE panel widget (fan/RGB/battery/power)
   - Kando (pie menu) + its KWin integration plugin, built from source
9. **Remove Unwanted Software** - Removes pre-installed apps:
   - Alacritty (replaced by WezTerm)
   - Firefox (replaced by Vivaldi)
   - All associated configs cleaned up
10. **NVIDIA Services** - Enables power management for suspend/resume
11. **Verification** - Checks that NVIDIA is working
12. **Deploy Configurations** - Deploys all your custom configs (done last to ensure proper defaults)
13. **Proton Drive CLI** - Installs `proton-drive-cli-bin` for Obsidian vault/contacts backup (see below). You still need to run `proton-drive auth login` yourself afterward - sign-in opens a browser and can't be scripted.
14. **KDE Connect Firewall** - Opens TCP/UDP ports 1714-1764 in `ufw`. KDE Connect comes pre-installed with Plasma, but `ufw` blocks its discovery traffic by default, so pairing silently fails until these ports are opened.
15. **Self-Hosted Contact Sync** - Installs and configures Radicale + Tailscale (see "Self-hosted Contact Sync" below); the manual follow-up steps it can't do for you (`tailscale up`, the KAddressBook DAV wizard, DAVx5 on your phone) are printed at the end of this step.

### After Running

**MUST REBOOT** for changes to take effect!

## Backing Up Your Configs

When you've customized your system and want to save those changes:

1. **Run the backup function:**
   ```bash
   cd ~/CachyOsRazer17Setup
   ./cachyos-setup.sh
   # Select option 2) Backup Configs
   ```

2. **Review what was backed up:**
   ```bash
   ls -R configs/
   ```

3. **Commit to git:**
   ```bash
   git add configs/
   git commit -m "Update configs from $(date +%Y-%m-%d)"
   git push
   ```

Now your configs are saved and will be deployed on your next fresh install!

## Creating a CachyOS Boot Drive (Caligula)

Every time you run **Backup Configs**, the script also checks whether a removable
USB drive with enough free space is currently plugged in:

1. It looks up the latest CachyOS desktop release on the
   [official mirror](https://mirror.cachyos.org/ISO/desktop/) (no download yet - just
   the filename, size, and published SHA-256 checksum).
2. It lists any attached removable drives that are large enough to hold it.
3. If none are found, it silently skips - no prompt, no download.
4. If one or more are found, it asks whether you want to create a boot drive, and
   which drive to use if there's more than one.
5. Only then does it download the ISO (cached in `~/.cache/cachyos-setup-iso/` and
   verified against the published checksum, so repeat runs don't re-download it)
   and hand off to [Caligula](https://github.com/ifd3f/caligula) to burn it.

Caligula does the actual writing and shows **its own** confirmation dialog with the
target disk's model and size before touching anything - the script never passes
`--force`, so you always get a last chance to back out. This is a destructive,
whole-disk write: everything on the selected drive is erased.

Requires `caligula` (installed automatically in Step 8, or manually via
`sudo pacman -S caligula` - it's in the official Arch/CachyOS repos, no AUR needed).

## Backing Up Your Obsidian Vault (Proton Drive)

Unlike `configs/`, your Obsidian **vault** (the actual notes) is never committed to
this git repo - it goes to Proton Drive instead, end-to-end encrypted.

1. **One-time setup:**
   ```bash
   yay -S proton-drive-cli-bin   # or via Setup System, step 13
   proton-drive auth login       # opens a browser - keep the terminal open until it's done
   ```

2. **Back up:**
   ```bash
   ./cachyos-setup.sh
   # Select option 3) Backup Obsidian Vault to Proton Drive
   ```
   This uploads `OBSIDIAN_VAULT_DIR` (set near the top of `cachyos-setup.sh`, defaults to
   `~/Documents/Obsidian/Hugins Saga`) to `/my-files/<vault name>` on Proton Drive. It's
   a one-way push - files that differ are **replaced** with your local copy.

   The Proton Drive CLI has no built-in diffing, so the script does its own: the very
   first backup uploads the whole vault once, then every backup after that only
   uploads files whose modification time changed since the last successful run
   (tracked via `.proton-obsidian-backup-marker`, gitignored). If nothing changed,
   it skips the upload entirely - no repeated full-vault re-uploads.

3. **Restore (e.g. on a fresh install):**
   ```bash
   ./cachyos-setup.sh
   # Select option 4) Restore Obsidian Vault from Proton Drive
   ```
   This downloads `/my-files/<vault name>` back into `OBSIDIAN_VAULT_DIR`. Local files
   that differ from the Proton Drive version are **replaced** - back up first if you
   have local changes you don't want to lose.

If your vault moves or gets renamed, update `OBSIDIAN_VAULT_DIR` near the top of
`cachyos-setup.sh` to match.

### Why Wayland Instead of X11?

Earlier versions of this script defaulted to X11, on the theory that it would
give better NVIDIA multi-monitor behavior. That turned out to be backwards for
this specific laptop, and it's not a guess - it was measured directly:

The external monitor's DisplayPort is wired straight to the RTX 3080, not the
Intel iGPU. Under X11, PRIME's provider model copies every rendered frame from
Intel to NVIDIA for that output (reverse offload) - the GPU sits at boosted
clocks (P0) doing that copy work even for an idle desktop. Under Wayland, KWin
scans out natively on whichever GPU physically owns the connected port - no
copy step. Measured on this laptop, same idle desktop, same external monitor:

| | X11 | Wayland |
|---|---|---|
| Power state | P0 (boosted) | P8 (idle) |
| Power draw | ~27W | ~18W |
| GPU utilization | 17-26% | ~9% |

Gaming and tearing were also checked directly on Wayland and found to be fine.

The script now installs XWayland support (for X11-only apps and as a manual
fallback session) but sets **Plasma Wayland** as the default.

### Switching Between Wayland and X11

The script sets Wayland as default. To use X11 instead (e.g. to troubleshoot,
or if you hit an app that needs it):

1. Log out
2. Click your username at login screen
3. Look for session selector (usually bottom-left or bottom-right corner)
4. Choose:
   - **Plasma (Wayland)** - Default, measured lower power with your external monitor setup
   - **Plasma (X11)** - Fallback, available if you need it

### GPU Mode: Docked vs Mobile

Two GPU modes, switched via [EnvyControl](https://github.com/bayasdev/envycontrol):

- **nvidia** (default) - dGPU always on, no PRIME overhead. Matches actual
  daily use: external monitor connected 90%+ of the time, wired to the dGPU.
- **hybrid** - dGPU sleeps when idle (RTD3, `--rtd3 2`), wakes on demand via
  `prime-run`/Steam/KDE's per-app toggle. For when you're mobile on battery.

Both are installed by the script, along with two ways to switch:

1. **Automatic** (`gpu-mode-monitor.service`, runs by default): watches
   `/sys/class/drm` for the external monitor connecting or disconnecting -
   works under X11 or Wayland - and if the current mode doesn't match
   (e.g. still in `hybrid` after you've docked), prompts you to switch. It
   only prompts once per actual plug/unplug event, not repeatedly, and it
   never switches without confirmation.
2. **Manual** (`~/.local/bin/gpu-mode-toggle.sh`): same prompt-and-switch
   logic, for binding to a hotkey. Not bound automatically - Wayland has no
   app-level global shortcuts, so add one yourself:
   System Settings → Shortcuts → Custom Shortcuts → New → Global Shortcut →
   Command/URL, command: `~/.local/bin/gpu-mode-toggle.sh`

Either way, switching uses `pkexec` for a GUI password prompt (works from a
hotkey with no terminal attached), and offers to reboot immediately -
EnvyControl mode switches always need a reboot to take effect, so this can't
be instant, but it's a couple of clicks instead of remembering the commands.

Check the service any time with `systemctl --user status gpu-mode-monitor`.

### Troubleshooting

**Script fails during AUR package installation:**
- AUR packages sometimes have issues
- Run the script again with `--interactive` and skip the failing step
- Install problematic packages manually later with: `yay -S package-name`

**NVIDIA not working after reboot:**
- Check: `nvidia-smi`
- If it fails, check: `lsmod | grep nvidia`
- Verify kernel modules loaded: `dmesg | grep nvidia`

**Display issues with multiple monitors:**
- Use `nvidia-settings` to configure displays
- For Wayland: KDE System Settings > Display Configuration
- For X11: nvidia-settings or KDE System Settings

### Customizing the Script

The script is well-commented and modular. To add your own software:

1. Find STEP 8 in the script
2. Add packages to:
   - `OFFICIAL_PACKAGES` for official repo packages
   - `AUR_PACKAGES` for AUR packages

Example:
```bash
OFFICIAL_PACKAGES="discord joplin-desktop p7zip steam vlc neofetch htop"
AUR_PACKAGES="bitwarden visual-studio-code-bin spotify"
```

### Useful Commands After Setup

- **Check GPU usage:** `nvidia-smi`
- **Monitor GPU continuously:** `watch -n 1 nvidia-smi`
- **NVIDIA settings:** `nvidia-settings`
- **Check which GPU is being used:** `glxinfo | grep "OpenGL renderer"`
- **Force an app onto the RTX 3080:** `prime-run application-name` (shortcut for the `__NV_PRIME_RENDER_OFFLOAD`/`__GLX_VENDOR_LIBRARY_NAME` env vars, installed via `nvidia-prime`)
- **Run on dedicated GPU from KDE:** right-click the app → Properties → Advanced Options → "Run using dedicated graphics card" (needs `switcheroo-control`, installed by the script)
- **Proton Drive sign-in:** `proton-drive auth login`
- **List your Proton Drive files:** `proton-drive filesystem list /my-files`
- **Switch GPU mode:** `~/.local/bin/gpu-mode-toggle.sh` (or wait for the auto-detect prompt)
- **Check the GPU auto-detect service:** `systemctl --user status gpu-mode-monitor`
- **Toggle Handy transcription:** `handy --toggle-transcription` (bind this to a hotkey - see [GPU Mode](#gpu-mode-docked-vs-mobile) above for the same KDE Custom Shortcuts steps)

### Steam-Specific Tips

Steam should automatically use NVIDIA GPU. To verify:
1. Launch Steam
2. Go to Steam > Settings > System
3. Check that your NVIDIA GPU is detected

For per-game settings:
- Right-click game > Properties > General
- In "Launch Options" you can add specific flags if needed

### Why This Configuration is Safe

- **Doesn't blacklist Intel GPU** (which can brick your system) - it's still there, still usable, `hybrid` mode uses it as primary any time you switch to it
- **nvidia mode isn't a hack** - it's one of EnvyControl's three standard, supported modes, not a manual xorg.conf hand-edit
- **hybrid mode is one hotkey/prompt away** - see [GPU Mode: Docked vs Mobile](#gpu-mode-docked-vs-mobile) above, for whenever the external monitor isn't in the picture
- **DKMS drivers** automatically rebuild on kernel updates
- **The docked/mobile split matches measured behavior on this laptop**, not a generic recommendation - see [Why Wayland Instead of X11?](#why-wayland-instead-of-x11) above for the actual numbers

## Need Help?

If you run into issues:
1. Run in interactive mode to see where it fails
2. Check the explanations for each step
3. You can manually run individual steps from the script
4. The script uses standard Arch/CachyOS commands, so Arch Wiki is helpful

Good luck with your setup!
