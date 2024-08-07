ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()

hs.loadSpoon("AppLauncher")
spoon.AppLauncher:bindHotkeys({
    ["Telegram"]           = { { "alt" }, "Q" },
    ["Warp"]               = { { "alt" }, "W" },
    ["lf"]                 = { { "alt" }, "E", isWarp = true },
    ["Arc"]                = { { "alt" }, "A" },
    ["Spotify"]            = { { "alt" }, "S" },
    ["Cursor"]             = { { "alt" }, "D" },
    ["Figma"]              = { { "alt" }, "Z" },
    ["Insomnia"]           = { { "alt" }, "X" },
    ["Discord"]            = { { "alt" }, "C" },
    ["System Settings"]    = { { "alt" }, "R" },
    ["btop"]               = { { "alt" }, "V", isWarp = true },
    ["Bitwarden"]          = { { "alt" }, "B" },
    ["Terminal"]           = { { "alt", "shift" }, "W" },
    ["Finder"]             = { { "alt", "shift" }, "E" },
    ["Safari"]             = { { "alt", "shift" }, "A" },
    ["Visual Studio Code"] = { { "alt", "shift" }, "D" },
    ["Activity Monitor"]   = { { "alt", "shift" }, "V" },
    ["Activity Monitor"]   = { { "ctrl", "shift" }, "escape" },
})

hs.loadSpoon("WindowManager"):start()
