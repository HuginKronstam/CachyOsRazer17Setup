local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- General
config.font_size = 12
config.line_height = 1.2
config.font = wezterm.font("BlexMono Nerd Font Mono")
config.color_scheme = "tokyonight_night"

config.colors = {
  cursor_bg = "#7aa2f7",
  cursor_border = "#7aa2f7",
}

config.window_decorations = "RESIZE"
config.enable_tab_bar = true

-- Key Bindings
config.keys= {
  {
  key = 'w',
  mods = 'WIN',
  action = wezterm.action.CloseCurrentPane { confirm = false },
  },
  {
    key = 's',
    mods = 'WIN',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 's',
    mods = 'WIN|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
}
return config
