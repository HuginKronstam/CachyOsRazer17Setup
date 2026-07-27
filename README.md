# CachyOS Razer 17 Setup Script

## Repository Structure

```
CachyOsRazer17Setup/
├── cachyos-setup.sh       # Main installation script
├── README.md              # This file
├── .gitignore             # Protects sensitive data
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
    └── vivaldi/
        └── (configs)      # Vivaldi bookmarks/preferences (no cache/cookies/logins)
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
5) Exit
```

- **Option 1**: Install system (choose interactive/automatic mode)
- **Option 2**: Backup your current configs to ./configs/
- **Option 3**: Upload your Obsidian vault to Proton Drive
- **Option 4**: Download your Obsidian vault from Proton Drive (overwrites local changes that differ)
- **Option 5**: Exit

### 3. Follow the Prompts

If you chose interactive mode, the script will explain each step and let you skip if needed.

### 4. Reboot

After the script completes, reboot to apply all changes.

## Features

### Setup System
- Updates all packages
- Installs and configures NVIDIA drivers for RTX 3080 Mobile
- Sets up X11 with proper Optimus configuration
- Installs gaming optimizations
- Installs your application suite
- Removes unwanted pre-installed software
- Deploys your custom configurations

### Backup Configs
- Backs up WezTerm configuration
- Backs up all KDE customizations (fonts, shortcuts, power, etc.)
- Backs up Obsidian configs
- Backs up VS Code settings
- Backs up Vivaldi bookmarks/preferences
- Saves everything to ./configs/ ready for git commit

### Obsidian Vault Backup/Restore (Proton Drive)
- Uses the official [Proton Drive CLI](https://proton.me/blog/proton-drive-cli) (`proton-drive-cli-bin` from the AUR)
- Backs up your actual notes (not just app settings) to `/my-files/<vault name>` on Proton Drive
- Restore pulls the vault back down - local files that differ are replaced with the Proton Drive version
- Requires signing in once with `proton-drive auth login` (opens a browser; the script can't do this non-interactively)

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
3. **X11 Installation** - Installs X11, Plasma X11 session, and sets it as default
4. **X11 NVIDIA Optimus Configuration** - Configures hybrid graphics properly:
   - GLX vendor configuration for NVIDIA
   - X11 Optimus setup (supports both Intel and NVIDIA GPUs)
   - Fixes black box rendering issues
   - Enables both laptop and external displays
5. **GPU Configuration** - Sets GPU mode to **hybrid** (PRIME offload): the RTX
   3080 stays powered off until an app explicitly requests it (`prime-run`,
   a Steam launch option, or KDE's per-app toggle), then powers back down.
   Also installs `nvidia-prime`, `switcheroo-control`, and `thermald`.
6. **Initramfs Rebuild** - Applies driver changes
7. **YAY Installation** - Installs AUR helper
8. **Gaming Setup** - Installs cachyos-gaming-meta package
9. **Applications** - Installs your software suite:
   - Discord
   - Vivaldi Browser
   - Bitwarden
   - Steam
   - VLC
   - VS Code
   - Obsidian (note-taking)
   - WezTerm (terminal)
   - BlexMono Nerd Font
10. **Remove Unwanted Software** - Removes pre-installed apps:
   - Alacritty (replaced by WezTerm)
   - Firefox (replaced by Vivaldi)
   - All associated configs cleaned up
11. **NVIDIA Services** - Enables power management for suspend/resume
12. **Verification** - Checks that NVIDIA is working
13. **Deploy Configurations** - Deploys all your custom configs (done last to ensure proper defaults)
14. **Proton Drive CLI** - Installs `proton-drive-cli-bin` for Obsidian vault backup/restore (see below). You still need to run `proton-drive auth login` yourself afterward - sign-in opens a browser and can't be scripted.

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

### Why X11 Instead of Wayland?

The script defaults to X11 because:
- **Better multi-monitor support** with NVIDIA GPUs
- **No refresh rate sync issues** between different displays (360Hz laptop + 144Hz external)
- **More stable gaming performance** with external monitors
- **Better game compatibility**
- **No rendering issues** (black boxes) with NVIDIA

The script configures **NVIDIA Optimus in hybrid mode (PRIME offload)** so:
- ✅ Laptop screen works (via Intel GPU output)
- ✅ External monitors work (via NVIDIA GPU when needed)
- ✅ The RTX 3080 stays powered off at idle and wakes on demand - much better battery life than forcing it on permanently
- ✅ Gaming is smooth on both laptop and external displays once launched via `prime-run`, Steam, or KDE's per-app toggle
- ✅ No black boxes or GLX errors

If you're docked and gaming full-time and don't care about battery, you can switch to always-on NVIDIA with `sudo envycontrol -s nvidia` (see below).

You can still switch to Wayland later if you want to test it - just select "Plasma (Wayland)" at the login screen.

### Switching Between X11 and Wayland

The script sets X11 as default. To switch to Wayland for testing:

1. Log out
2. Click your username at login screen
3. Look for session selector (usually bottom-left or bottom-right corner)
4. Choose:
   - **Plasma (X11)** - Default, stable, best for gaming with external monitors
   - **Plasma (Wayland)** - Modern compositor, test if you want

**Note:** If you use Wayland with external monitors, you may experience frame rate caps or choppiness due to compositor sync issues with mixed refresh rates.

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

1. Find STEP 7 in the script
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

### Steam-Specific Tips

Steam should automatically use NVIDIA GPU. To verify:
1. Launch Steam
2. Go to Steam > Settings > System
3. Check that your NVIDIA GPU is detected

For per-game settings:
- Right-click game > Properties > General
- In "Launch Options" you can add specific flags if needed

### Why This Configuration is Safe

- **Doesn't blacklist Intel GPU** (which can brick your system) - Intel drives the displays by default in hybrid mode
- **Uses PRIME offload** (`prime-run`, launch options, KDE's per-app toggle) to send specific apps to NVIDIA instead of forcing it on for everything
- **Matches the CachyOS-recommended default** for hybrid-GPU laptops - see [wiki.cachyos.org/configuration/dual_gpu](https://wiki.cachyos.org/configuration/dual_gpu/)
- **DKMS drivers** automatically rebuild on kernel updates
- **Much better idle battery life** than forcing NVIDIA on permanently - the dGPU powers down when nothing needs it

## Need Help?

If you run into issues:
1. Run in interactive mode to see where it fails
2. Check the explanations for each step
3. You can manually run individual steps from the script
4. The script uses standard Arch/CachyOS commands, so Arch Wiki is helpful

Good luck with your setup!
