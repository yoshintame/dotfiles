local M = {}

local ONEPASSWORD_BUNDLE = "com.1password.1password"
local ONEPASSWORD_NAME = "1Password"
local POPUP_TITLES = { "^Quick Access", "^1Password$" }
local AEROSPACE = "/opt/homebrew/bin/aerospace"
local GUARD_SECONDS = 1.5
local INPUT_GRACE_SECONDS = 0.3

local log = hs.logger.new("1p-focus", "warning")

local lastApp = nil
local guardApp = nil
local lastInputAt = 0
local expiry = nil
local appWatcher = nil
local popupFilter = nil
local mainWindowFilter = nil
local inputTap = nil

local function now()
    return hs.timer.secondsSinceEpoch()
end

local function isOnePassword(app)
    return app ~= nil and app:bundleID() == ONEPASSWORD_BUNDLE
end

local function disarm()
    guardApp = nil
    if expiry then expiry:stop() end
    inputTap:stop()
end

local function pinAerospaceFocus(app)
    local win = app:focusedWindow() or app:mainWindow()
    if not win then return end
    hs.task.new(AEROSPACE, nil, { "focus", "--window-id", tostring(win:id()) }):start()
end

local function arm()
    if not lastApp then return end
    disarm()
    guardApp = lastApp
    lastInputAt = 0
    inputTap:start()
    expiry = hs.timer.doAfter(GUARD_SECONDS, disarm)
    pinAerospaceFocus(guardApp)
end

local function restore(target, stolenBy)
    if not target:isRunning() then return end
    local win = target:focusedWindow() or target:mainWindow()
    if not win then return end
    log.w(("restoring %s (stolen by %s)"):format(target:name(), stolenBy:name()))
    win:focus()
end

local function intercept(stolenBy)
    if not guardApp or stolenBy:pid() == guardApp:pid() then return end
    local target = guardApp
    disarm()
    if now() - lastInputAt > INPUT_GRACE_SECONDS then restore(target, stolenBy) end
end

function M.start()
    local front = hs.application.frontmostApplication()
    if not isOnePassword(front) then lastApp = front end

    inputTap = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.flagsChanged,
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.rightMouseDown,
    }, function()
        lastInputAt = now()
        return false
    end)

    appWatcher = hs.application.watcher.new(function(_, eventType, app)
        if eventType ~= hs.application.watcher.activated or not app or isOnePassword(app) then return end
        intercept(app)
        lastApp = app
    end)
    appWatcher:start()

    popupFilter = hs.window.filter.new(false):setAppFilter(ONEPASSWORD_NAME, { allowTitles = POPUP_TITLES })
    popupFilter:subscribe(hs.window.filter.windowDestroyed, arm)

    mainWindowFilter = hs.window.filter.new(false):setAppFilter(ONEPASSWORD_NAME, { allowTitles = 1, rejectTitles = POPUP_TITLES })
    mainWindowFilter:subscribe(hs.window.filter.windowFocused, function(win)
        intercept(win:application())
    end)
end

function M.stop()
    if inputTap then disarm() end
    if appWatcher then appWatcher:stop() end
    if popupFilter then popupFilter:unsubscribeAll() end
    if mainWindowFilter then mainWindowFilter:unsubscribeAll() end
end

return M
