ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()

hs.loadSpoon("AppLauncher")
spoon.AppLauncher:bindHotkeys({
    ["1password"]          = { { "alt"                  }, "1" },

    ["Telegram"]           = { { "alt"                  }, "Q" },
    ["Warp"]               = { { "alt"                  }, "W" },
    ["Wezterm"]            = { { "alt", "shift"         }, "W" },
    ["lf"]                 = { { "alt"                  }, "E", isWarp = true },
    ["Finder"]             = { { "alt", "shift"         }, "E" },
    ["System Settings"]    = { { "alt"                  }, "R" },

    ["Arc"]                = { { "alt"                  }, "A" },
    ["Safari"]             = { { "alt", "shift"         }, "A" },
    ["Spotify"]            = { { "alt"                  }, "S" },
    ["Cursor"]             = { { "alt"                  }, "D" },
    ["Visual Studio Code"] = { { "alt", "shift"         }, "D" },

    ["Figma"]              = { { "alt"                  }, "Z" },
    ["Insomnia"]           = { { "alt"                  }, "X" },
    ["Discord"]            = { { "alt"                  }, "C" },
    ["btop"]               = { { "alt"                  }, "V", isWarp = true },
    ["Activity Monitor"]   ={{ { "alt", "shift"         }, "V" },
                             { {        "shift", "ctrl" }, "escape" }},
})

hs.loadSpoon("WindowManager"):start()
