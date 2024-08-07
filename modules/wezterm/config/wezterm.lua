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
    colors = {
        cursor_bg = '#aeaeae',
        foreground = '#ffffff',
        background = '#010101',
        ansi = { "#121212", "#9834f6", "#682ef5", "#3a2bf5", "#344ef5", "#4481f7", "#5bb6f9", "#f1f1f1" },
        brights = { "#666666", "#ba5aff", "#905aff", "#695ef6", "#5c78ff", "#5ea2ff", "#5ac8ff", "#ffffff" }
    },
}

return config
