ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()


-- ================== Window Switcher ==================

YABAI_PENDING_SPACE = nil
YABAI_PATH = "/opt/homebrew/bin/yabai "
JQ_PATH = "/opt/homebrew/bin/jq "

HYPER_KEY = { "alt", "shift", "ctrl", "cmd" }
WINDOW_LAYER_KEY = { "alt" }
WINDOW_SUBLAYER_KEY = { "alt", "shift" }

require('yabai')
yabaiSendMessage({ "signal", "--remove", "active-split-pending" }, nil, true)


-- TODO: add yabai pending handling
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
        if YABAI_PENDING_SPACE then
            yabaiSendMessage({ "signal", "--remove", "active-split-pending" }, nil, true)

            local output = yabaiSendMessage({ "query", "--windows" }, nil, true)
            local windows = hs.json.decode(output)
            local windowId = nil

            for _, window in pairs(windows) do
                if window.app == name then
                    print(window.app)
                    windowId = window.id
                    break
                end
            end

            yabaiSendMessage({ "window", tostring(windowId), "--space", tostring(YABAI_PENDING_SPACE) }, nil, true)
            YABAI_PENDING_SPACE = nil
        else
            hs.application.launchOrFocus(name)
        end
    end
end

-- ================== Binds ==================

hs.hotkey.bind({ "shift", "ctrl" }, "s", function() yabaiSplit() end)
hs.hotkey.bind({ "shift", "ctrl" }, "d", function() yabaiUnsplit() end)

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
hs.hotkey.bind(WINDOW_LAYER_KEY, "Z", launchOrFocusApp("Things3"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "X", launchOrFocusApp("Craft"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "C", launchOrFocusApp("Discord"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "R", launchOrFocusApp("System Settings"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "V", launchOrFocusWarpApp("btop"))
hs.hotkey.bind(WINDOW_SUBLAYER_KEY, "V", launchOrFocusApp("Activity Monitor"))
hs.hotkey.bind(WINDOW_LAYER_KEY, "B", launchOrFocusApp("Bitwarden"))
hs.hotkey.bind({ "ctrl", "shift" }, "escape", launchOrFocusApp("Activity Monitor"))

-- ================== Utilities ==================

hs.window.animationDuration = 0
