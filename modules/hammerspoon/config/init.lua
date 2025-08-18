ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()

hs.loadSpoon("AppLauncher")
spoon.AppLauncher:bindHotkeys({
    ["1password"]          = { { "alt"                  }, "1" ,  keyboardLayout = "ABC" },

    ["Telegram"]           = { { "alt"                  }, "Q" },
    ["Warp"]               = { { "alt"                  }, "W"  ,  keyboardLayout = "ABC" },
    ["Kitty"]              = { { "alt", "shift"         }, "W"  ,  keyboardLayout = "ABC" },
    ["Tana"]               = { { "alt"                  }, "E" },
    ["Finder"]             = { { "alt", "shift"         }, "E"  ,  keyboardLayout = "ABC" },

    ["Arc"]                = { { "alt"                  }, "A" },
    ["Safari"]             = { { "alt", "shift"         }, "A" },
    ["Spotify"]            = { { "alt"                  }, "S" },
    ["Spark Mail"]         = { { "alt", "shift"         }, "S" },
    ["Cursor"]             = { { "alt"                  }, "D" },
    ["Height"]             = { { "alt", "shift"         }, "D" },

    ["Figma"]              = { { "alt"                  }, "Z" },
    ["Insomnia"]           = { { "alt"                  }, "X" },
    ["Discord"]            = { { "alt"                  }, "C" },
    ["Activity Monitor"]   ={{ { "alt"                  }, "V" },
                             { { "alt"                  }, "escape" },
                             { {        "shift", "ctrl" }, "escape" }},

    ["System Settings"]    = { { "alt"                  }, "," },
})


