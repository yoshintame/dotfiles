local deeplink = require("engine.deeplink")
local process = require("engine.process")
local timer = require("engine.timer")

local M = {}

local REOPEN_DELAY = 0.8

local function switchLayout(layout)
    if layout then hs.keycodes.setLayout(layout) end
end

function M.focus(name, opts)
    local layout = opts and opts.layout
    return function()
        hs.application.launchOrFocus(name)
        switchLayout(layout)
    end
end

function M.launcher(rows)
    local binds = {}
    for _, row in ipairs(rows) do
        local name, mods, key = row[1], row[2], row[3]
        local opts = { layout = row.layout }
        binds[#binds + 1] = { mods, key, row.warp and M.warpTab(name, opts) or M.focus(name, opts) }
    end
    return binds
end

function M.warpTab(name, opts)
    local layout = opts and opts.layout
    return function()
        local warp = hs.application.get("Warp")
        local window = warp and warp:findWindow(name)
        if window then
            window:focus()
        else
            process.open("warp://launch/" .. name)
        end
        switchLayout(layout)
    end
end

function M.killAndReopen(bundleID)
    local app = hs.application.get(bundleID)
    if app then app:kill9() end
    timer.after(REOPEN_DELAY, function()
        hs.application.launchOrFocusByBundleID(bundleID)
    end)
end

function M.restart(bundleID)
    return function() M.killAndReopen(bundleID) end
end

function M.killFront()
    local app = hs.application.frontmostApplication()
    if app then app:kill9() end
end

function M.reopenFront()
    local app = hs.application.frontmostApplication()
    if not app then return end
    local bundleID = app:bundleID()
    if bundleID then
        M.killAndReopen(bundleID)
    else
        app:kill9()
    end
end

function M.switchWindows()
    local app = hs.application.frontmostApplication()
    local bundleID = app and app:bundleID()
    if not bundleID then return end
    process.open(deeplink.raycast("extensions/yoshintame/raycast-app-switcher/app-windows-by-id", {
        arguments = { appIdentifier = bundleID },
    }), { background = true })
end

return M
