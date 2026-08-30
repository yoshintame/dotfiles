local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config = {
    window_close_confirmation = 'NeverPrompt',
    font = wezterm.font_with_fallback({ "GeistMono Nerd Font Mono" }),
    font_size = 16,
    enable_tab_bar = false,
    window_decorations = "RESIZE",
    default_cursor_style = "BlinkingBar",
    window_background_opacity = 0.7,
    macos_window_background_blur = 100,
    cursor_blink_rate = 600,
    color_scheme = "Catppuccin Frappe",
    colors = {
        foreground = '#ffffff',
        background = '#010101',
    },
}

return config
