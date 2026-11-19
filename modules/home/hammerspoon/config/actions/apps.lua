local deeplink = require("core.deeplink")
local sys = require("core.sys")

local M = {}

local REOPEN_DELAY = 0.8

function M.killAndReopen(bundleID)
    local app = hs.application.get(bundleID)
    if app then app:kill9() end
    sys.after(REOPEN_DELAY, function()
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
    sys.open(deeplink.raycast("extensions/yoshintame/raycast-app-switcher/app-windows-by-id", {
        arguments = { appIdentifier = bundleID },
    }), { background = true })
end

return M
