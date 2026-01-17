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
    ["ChatGPT"]            = { { "alt", "shift"         }, "A" },
    ["Spotify"]            = { { "alt"                  }, "S" },
    ["Spark Mail"]         = { { "alt", "shift"         }, "S" },
    ["Cursor"]             = { { "alt"                  }, "D" },
    ["Linear"]             = { { "alt", "shift"         }, "D" },

    ["Figma"]              = { { "alt"                  }, "Z" },
    ["Insomnia"]           = { { "alt"                  }, "X" },
    ["Discord"]            = { { "alt"                  }, "C" },
    ["Activity Monitor"]   ={{ { "alt"                  }, "V" },
                             { { "alt"                  }, "escape" },
                             { {        "shift", "ctrl" }, "escape" }},

    ["System Settings"]    = { { "alt"                  }, "," },
})

hs.loadSpoon("Hammerflow")
spoon.Hammerflow.registerFormat({
	atScreenEdge = 2,
	padding = 16,
	radius = 8,
	fillColor = { alpha = .80, hex = "0a0a0a" },
	strokeColor = { alpha = .85, hex = "89b4fa" },
	textColor = { alpha = 1, hex = "cdd6f4" },
	textStyle = {
		paragraphStyle = { lineSpacing = 6 },
		shadow = { offset = { h = -1, w = 1 }, blurRadius = 12, color = { alpha = .60, white = 0 } }
	},
	strokeWidth = 2,
	textFont = "Monaco",
	textSize = 12
})
spoon.Hammerflow.loadFirstValidTomlFile({
	"home.toml",
	"work.toml",
	"./sample.toml"
})

