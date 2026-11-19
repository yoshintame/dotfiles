local apps = require("actions.apps")
local finder = require("actions.finder")
local open = require("actions.open")
local windows = require("actions.windows")
local clipboard = require("features.clipboard-history")
local proxy = require("generated.proxy-bindings")

return {
    launcher = {
        { "1password",        "alt",        "1", layout = "ABC" },

        { "Telegram",         "alt",        "q" },
        { "Warp",             "alt",        "w", layout = "ABC" },
        { "yazi",             "alt",        "r", layout = "ABC", warp = true },
        { "btop",             "alt",        "b", layout = "ABC", warp = true },
        { "Terminal",         "alt shift",  "w", layout = "ABC" },
        { "Zed",              "alt",        "e", layout = "ABC" },
        { "Finder",           "alt shift",  "e", layout = "ABC" },

        { "Dia",              "alt",        "a" },
        { "Safari",           "alt shift",  "a" },
        { "Spotifast",        "alt",        "s" },
        { "Spark Mail",       "alt shift",  "s" },
        { "Paseo",            "alt",        "d" },
        { "Jira",             "alt shift",  "d" },
        { "Fork",             "alt",        "x" },

        { "TickTick",         "alt",        "t" },
        { "Claude",           "alt",        "z" },
        { "yaak",             "alt",        "g" },
        { "Discord",          "alt",        "c" },
        { "Activity Monitor", "alt",        "v" },
        { "Activity Monitor", "alt",        "escape" },
        { "Activity Monitor", "ctrl shift", "escape" },

        { "System Settings",  "alt",        "," },
    },

    binds = {
        { "alt",       "f", windows.floatMaximize({ width = 420, maxHeight = 860 }) },
        { "alt",       "n", open.draft({ dir = "~/.local/share/scratchpad", app = "Zed" }) },
        { "cmd shift", "c", finder.copySelectedPath, app = "com.apple.finder" },
    },

    proxy = {
        { proxy.paste_history1,      clipboard.pasteAt(1) },
        { proxy.paste_history2,      clipboard.pasteAt(2) },
        { proxy.paste_history3,      clipboard.pasteAt(3) },
        { proxy.paste_history4,      clipboard.pasteAt(4) },
        { proxy.paste_history5,      clipboard.pasteAt(5) },
        { proxy.current_app_windows, apps.switchWindows },
    },
}
