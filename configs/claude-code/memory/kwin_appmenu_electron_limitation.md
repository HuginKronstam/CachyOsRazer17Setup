---
name: kwin-appmenu-electron-limitation
description: "Global Menu panel widget never works for Vivaldi/VS Code/Electron apps - confirmed system limitation, not a truely-maximized script bug"
metadata: 
  node_type: memory
  type: project
  originSessionId: 447ee8ed-79fb-475a-8bf3-6c82788795b9
  modified: 2026-09-01T15:12:03.592Z
---

On this system, the "Truely Maximized" KWin script (`~/.local/share/kwin/scripts/truely-maximized/`, backed up in the dotfiles repo at `configs/kwin-scripts/truely-maximized/`) and the Global Menu panel widget (`org.kde.plasma.appmenu`) are two independent mechanisms that happen to visually combine for some apps but not others.

Confirmed via live KWin scripting probe (`window.hasApplicationMenu` for every open window):
- Dolphin, Konsole, System Settings (native Qt/KDE apps): `hasApplicationMenu=true` — menu bar merges into the panel.
- Vivaldi, VS Code, Discord, Obsidian (Chromium/Electron apps): `hasApplicationMenu=false` — titlebar still correctly hides when maximized (`noBorder=true`, truely-maximized working as designed), but no menu ever appears in the panel.

**Why:** Qt's `QMenuBar` auto-exports via the KDE-specific `org_kde_kwin_appmenu` Wayland protocol (X11/XWayland equivalent: `com.canonical.AppMenu.Registrar` D-Bus service) through Plasma's platform integration, for free. Chromium/Electron draw their entire UI (URL bar, hamburger menu, VS Code's File/Edit/... bar) as custom-painted content, not a native toolkit menu widget — there's nothing to export. Upstream Chromium/Electron never implemented this niche, KDE-only protocol. Not fixable via config on either the script or the widget side; would need a patched Chromium/Electron build (no maintained one exists for modern versions).

**How to apply:** If asked again about global-menu/appmenu not working for a specific app, check whether it's Qt/KDE-native (works) vs Electron/Chromium-based (won't, ever, on this system) before re-investigating — this is a settled, confirmed limitation, not a bug to chase.
