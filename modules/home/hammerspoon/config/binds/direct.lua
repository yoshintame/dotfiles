local apps = require("actions.apps")
local finder = require("actions.finder")
local open = require("actions.open")
local windows = require("actions.windows")
local clipboard = require("features.clipboard-history")
local proxy = require("generated.proxy-bindings")

local ABC = { layout = "ABC" }

return {
    { "alt 1", apps.focus("1password", ABC) },

    { "alt q", apps.focus("Telegram") },
    { "alt w", apps.focus("Warp", ABC) },
    { "alt r", apps.warpTab("yazi", ABC) },
    { "alt b", apps.warpTab("btop", ABC) },
    { "alt shift w", apps.focus("Terminal", ABC) },
    { "alt e", apps.focus("Zed", ABC) },
    { "alt shift e", apps.focus("Finder", ABC) },

    { "alt a", apps.focus("Dia") },
    { "alt shift a", apps.focus("Safari") },
    { "alt s", apps.focus("Spotifast") },
    { "alt shift s", apps.focus("Spark Mail") },
    { "alt d", apps.focus("Paseo") },
    { "alt shift d", apps.focus("Jira") },
    { "alt x", apps.focus("Fork") },

    { "alt t", apps.focus("TickTick") },
    { "alt z", apps.focus("Claude") },
    { "alt g", apps.focus("yaak") },
    { "alt c", apps.focus("Discord") },
    { "alt v", apps.focus("Activity Monitor") },
    { "alt escape", apps.focus("Activity Monitor") },
    { "ctrl shift escape", apps.focus("Activity Monitor") },

    { "alt ,", apps.focus("System Settings") },

    { "alt f", windows.toggleFloatMaximize },
    { "alt n", open.draft },

    { "cmd shift c", finder.copySelectedPath, app = "com.apple.finder" },

    { proxy.paste_history1, clipboard.pasteAt(1) },
    { proxy.paste_history2, clipboard.pasteAt(2) },
    { proxy.paste_history3, clipboard.pasteAt(3) },
    { proxy.paste_history4, clipboard.pasteAt(4) },
    { proxy.paste_history5, clipboard.pasteAt(5) },
}
