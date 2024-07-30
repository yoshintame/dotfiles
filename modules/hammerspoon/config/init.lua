ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()


HYPER_KEY = { "alt", "shift", "ctrl", "cmd" }
WINDOW_LAYER_KEY = { "alt" }
WINDOW_SUBLAYER_KEY = { "alt", "shift" }

local function launchOrFocusWarpApp(name)
    return function()
        local app = hs.application.get("Warp")
        local window = app:findWindow(name)
        if window ~= nil then
            window:focus()
        else
            hs.urlevent.openURL('warp://launch/' .. name)
        end
    end
end

local function launchOrFocusApp(name)
    return function()
        hs.application.launchOrFocus(name)
    end
end

-- ================== Binds ==================

hs.hotkey.bind(WINDOW_LAYER_KEY, "Q", launchOrFocusApp("Telegram"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "W", launchOrFocusApp("Warp"))
hs.hotkey.bind(WINDOW_SUBLAYER_KEY, "W", launchOrFocusApp("Terminal"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "E", launchOrFocusWarpApp("lf"))
hs.hotkey.bind(WINDOW_SUBLAYER_KEY, "E", launchOrFocusApp("Finder"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "A", launchOrFocusApp("Arc"))
hs.hotkey.bind(WINDOW_SUBLAYER_KEY, "A", launchOrFocusApp("Safari"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "S", launchOrFocusApp("Spotify"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "D", launchOrFocusApp("Cursor"))
hs.hotkey.bind(WINDOW_SUBLAYER_KEY, "D", launchOrFocusApp("Visual Studio Code"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "Z", launchOrFocusApp("Figma"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "X", launchOrFocusApp("Insomnia"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "C", launchOrFocusApp("Discord"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "R", launchOrFocusApp("System Settings"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "V", launchOrFocusWarpApp("btop"))
hs.hotkey.bind(WINDOW_SUBLAYER_KEY, "V", launchOrFocusApp("Activity Monitor"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "B", launchOrFocusApp("Bitwarden"))
hs.hotkey.bind({ "ctrl", "shift" }, "escape", launchOrFocusApp("Activity Monitor"))

-- ================== Utilities ==================

hs.window.animationDuration = 0
