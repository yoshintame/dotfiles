ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()

hs.loadSpoon("AppLauncher")
spoon.AppLauncher:bindHotkeys({
    ["1password"]          = { { "alt"                  }, "1" },

    ["Telegram"]           = { { "alt"                  }, "Q" },
    ["Wezterm"]            = { { "alt"                  }, "W" },
    ["Warp"]               = { { "alt", "shift"         }, "W" },
    ["Things3"]            = { { "alt"                  }, "E" },
    ["Finder"]             = { { "alt", "shift"         }, "E" },
    ["System Settings"]    = { { "alt"                  }, "R" },

    ["Arc"]                = { { "alt"                  }, "A" },
    ["Safari"]             = { { "alt", "shift"         }, "A" },
    ["Spotify"]            = { { "alt"                  }, "S" },
    ["Spark Mail"]         = { { "alt", "shift"         }, "S" },
    ["Cursor"]             = { { "alt"                  }, "D" },
    ["Visual Studio Code"] = { { "alt", "shift"         }, "D" },

    ["Figma"]              = { { "alt"                  }, "Z" },
    ["Insomnia"]           = { { "alt"                  }, "X" },
    ["Discord"]            = { { "alt"                  }, "C" },
    ["FoXray"]             = { { "alt"                  }, "V" },
    ["Activity Monitor"]   ={{ { "alt", "shift"         }, "V" },
                             { {        "shift", "ctrl" }, "escape" }},
})

hs.loadSpoon("WindowManager"):start()
