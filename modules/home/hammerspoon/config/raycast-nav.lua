local M = {}

local ESCAPE_KEYCODE = 53
local ARROW_UP_KEYCODE = 126
local ARROW_DOWN_KEYCODE = 125

local modal = hs.hotkey.modal.new()
local isNavMode = false
local searchModeActive = false
local escapeTap = nil
local appWatcher = nil
local windowFilter = nil

local NAV_BINDINGS = {
    { key = "j", mods = { "ctrl" }, toKey = "b" },
    { key = "l", mods = { "ctrl" }, toKey = "l" },
    { key = "left", mods = { "ctrl" }, toKey = "b" },
    { key = "right", mods = { "ctrl" }, toKey = "l" },
    { key = "d", mods = { "ctrl", "shift" }, toKey = "d" },
    { key = "y", mods = { "ctrl", "shift" }, toKey = "y" },
    { key = "c", mods = { "ctrl", "shift" }, toKey = "c" },
    { key = "v", mods = { "ctrl", "shift" }, toKey = "v" },
    { key = "u", mods = { "ctrl", "shift" }, toKey = "u" },
    { key = "space", mods = { "ctrl", "shift" }, toKey = "space" },
    { key = "return", mods = { "ctrl", "shift" }, toKey = "return" },
}

local function sendModeSignal(mode)
    local app = hs.application.find("com.raycast.macos")
    if app then
        hs.eventtap.keyStroke({ "ctrl", "shift" }, mode == "nav" and "[" or "]", nil, app)
    end
end

local function enterNavMode()
    if isNavMode then return end
    modal:enter()
    isNavMode = true
    searchModeActive = false
    sendModeSignal("nav")
end

local function exitNavMode(reason)
    if not isNavMode then return end
    modal:exit()
    isNavMode = false
    if reason ~= "silent" then
        sendModeSignal("search")
    end
end

local function forceDeactivate()
    if isNavMode then
        modal:exit()
        isNavMode = false
    end
    searchModeActive = false
end

for _, binding in ipairs(NAV_BINDINGS) do
    local action = function()
        local app = hs.application.find("com.raycast.macos")
        hs.eventtap.keyStroke(binding.mods, binding.toKey, nil, app)
    end
    modal:bind({}, binding.key, action, nil, action)
end

modal:bind({}, "/", nil, function()
    exitNavMode()
    searchModeActive = true
end)

modal:bind({}, "escape", nil, function()
    exitNavMode("silent")
    searchModeActive = false
    hs.eventtap.keyStroke({}, "escape", 0)
end)

modal:bind({}, "q", nil, function()
    exitNavMode("silent")
    searchModeActive = false
    hs.eventtap.keyStroke({}, "escape", 0)
end)

function M.activate()
    enterNavMode()
end

function M.deactivate()
    forceDeactivate()
end

function M.start()
    escapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
        if not searchModeActive then return false end
        local code = e:getKeyCode()
        if code == ESCAPE_KEYCODE then
            enterNavMode()
            return true
        end
        if code == ARROW_UP_KEYCODE or code == ARROW_DOWN_KEYCODE then
            enterNavMode()
            return false
        end
        if code == hs.keycodes.map["f"] and e:getFlags():containExactly({}) then
            enterNavMode()
            return true
        end
        return false
    end)
    escapeTap:start()

    appWatcher = hs.application.watcher.new(function(_, eventType, app)
        if eventType == hs.application.watcher.activated then
            local bundle = app and app:bundleID() or "nil"
            if bundle ~= "com.raycast.macos" then
                forceDeactivate()
            end
        elseif eventType == hs.application.watcher.deactivated then
            local bundle = app and app:bundleID() or "nil"
            if bundle == "com.raycast.macos" then
                forceDeactivate()
            end
        end
    end)
    appWatcher:start()

    windowFilter = hs.window.filter.new(false):setAppFilter("Raycast")
    windowFilter:subscribe(hs.window.filter.windowDestroyed, function()
        forceDeactivate()
    end)
    windowFilter:subscribe(hs.window.filter.windowUnfocused, function()
        forceDeactivate()
    end)
end

function M.stop()
    forceDeactivate()
    if escapeTap then escapeTap:stop() end
    if appWatcher then appWatcher:stop() end
    if windowFilter then windowFilter:unsubscribeAll() end
end

return M
