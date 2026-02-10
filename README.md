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
    └── vscode/
        └── settings.json  # VS Code settings
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
3) Exit
```

- **Option 1**: Install system (choose interactive/automatic mode)
- **Option 2**: Backup your current configs to ./configs/
- **Option 3**: Exit

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
- Saves everything to ./configs/ ready for git commit

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
5. **GPU Configuration** - Sets NVIDIA as primary GPU for rendering
6. **Initramfs Rebuild** - Applies driver changes
7. **YAY Installation** - Installs AUR helper
8. **Gaming Setup** - Installs cachyos-gaming-meta package
9. **Applications** - Installs your software suite:
   - Discord
   - Brave Browser
   - Bitwarden
   - Steam
   - VLC
   - VS Code
   - Obsidian (note-taking)
   - WezTerm (terminal)
   - BlexMono Nerd Font
10. **Remove Unwanted Software** - Removes pre-installed apps:
   - Alacritty (replaced by WezTerm)
   - Firefox (replaced by Brave)
   - All associated configs cleaned up
11. **NVIDIA Services** - Enables power management for suspend/resume
12. **Verification** - Checks that NVIDIA is working
13. **Deploy Configurations** - Deploys all your custom configs (done last to ensure proper defaults)

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

### Why X11 Instead of Wayland?

The script defaults to X11 because:
- **Better multi-monitor support** with NVIDIA GPUs
- **No refresh rate sync issues** between different displays (360Hz laptop + 144Hz external)
- **More stable gaming performance** with external monitors
- **Better game compatibility**
- **No rendering issues** (black boxes) with NVIDIA

The script configures **NVIDIA Optimus** properly so:
- ✅ Laptop screen works (via Intel GPU output)
- ✅ External monitors work (via NVIDIA GPU)
- ✅ NVIDIA does all rendering (high performance)
- ✅ Gaming is smooth on both laptop and external displays
- ✅ No black boxes or GLX errors

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
AUR_PACKAGES="brave-bin bitwarden visual-studio-code-bin spotify"
```

### Useful Commands After Setup

- **Check GPU usage:** `nvidia-smi`
- **Monitor GPU continuously:** `watch -n 1 nvidia-smi`
- **NVIDIA settings:** `nvidia-settings`
- **Check which GPU is being used:** `glxinfo | grep "OpenGL renderer"`
- **Force app to use NVIDIA:** `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia application-name`

### Steam-Specific Tips

Steam should automatically use NVIDIA GPU. To verify:
1. Launch Steam
2. Go to Steam > Settings > System
3. Check that your NVIDIA GPU is detected

For per-game settings:
- Right-click game > Properties > General
- In "Launch Options" you can add specific flags if needed

### Why This Configuration is Safe

- **Doesn't blacklist Intel GPU** (which can brick your system)
- **Uses environment variables** to prefer NVIDIA
- **Keeps Intel as fallback** for basic display if NVIDIA fails
- **DKMS drivers** automatically rebuild on kernel updates
- **Tested configuration** commonly used for hybrid GPU laptops

## Need Help?

If you run into issues:
1. Run in interactive mode to see where it fails
2. Check the explanations for each step
3. You can manually run individual steps from the script
4. The script uses standard Arch/CachyOS commands, so Arch Wiki is helpful

Good luck with your setup!
