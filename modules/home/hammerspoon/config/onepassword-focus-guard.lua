local M = {}

local ONEPASSWORD_BUNDLE = "com.1password.1password"
local GUARD_SECONDS = 1.5

local log = hs.logger.new("1p-focus", "info")

local lastApp = nil
local target = nil
local guardUntil = 0
local appWatcher = nil
local windowFilter = nil

local function isOnePassword(app)
    return app ~= nil and app:bundleID() == ONEPASSWORD_BUNDLE
end

local function restore(stolenBy)
    if not target or not target:isRunning() then return end
    local win = target:focusedWindow() or target:mainWindow()
    log.i(("restoring %s (stolen by %s)"):format(target:name(), stolenBy:name()))
    if win then win:focus() else target:activate() end
end

function M.start()
    local front = hs.application.frontmostApplication()
    if not isOnePassword(front) then lastApp = front end

    appWatcher = hs.application.watcher.new(function(_, eventType, app)
        if eventType ~= hs.application.watcher.activated or not app or isOnePassword(app) then return end
        if target and hs.timer.secondsSinceEpoch() < guardUntil and app:pid() ~= target:pid() then
            guardUntil = 0
            restore(app)
            return
        end
        lastApp = app
    end)
    appWatcher:start()

    windowFilter = hs.window.filter.new(false):setAppFilter("1Password", { allowRoles = "*" })
    windowFilter:subscribe(hs.window.filter.windowCreated, function(win)
        log.i(("popup created: %s [%s]"):format(win:title(), win:subrole()))
        target = lastApp
        guardUntil = 0
    end)
    windowFilter:subscribe(hs.window.filter.windowDestroyed, function(win)
        log.i(("popup destroyed: %s"):format(win:title()))
        if target then guardUntil = hs.timer.secondsSinceEpoch() + GUARD_SECONDS end
    end)
end

function M.stop()
    if appWatcher then appWatcher:stop() end
    if windowFilter then windowFilter:unsubscribeAll() end
end

return M
