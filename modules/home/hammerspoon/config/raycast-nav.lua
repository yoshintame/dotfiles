local M = {}

local ESCAPE_KEYCODE = 53

local modal = hs.hotkey.modal.new()
local isNavMode = false
local searchModeActive = false
local escapeTap = nil
local appWatcher = nil

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

local function enterNavMode()
    if isNavMode then return end
    modal:enter()
    isNavMode = true
    searchModeActive = false
    hs.alert.show("NAV", nil, nil, 0.4)
end

local function exitNavMode(reason)
    if not isNavMode then return end
    modal:exit()
    isNavMode = false
    if reason ~= "silent" then
        hs.alert.show("SEARCH", nil, nil, 0.4)
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
        if e:getKeyCode() == ESCAPE_KEYCODE and searchModeActive then
            enterNavMode()
            return true
        end
        return false
    end)
    escapeTap:start()

    appWatcher = hs.application.watcher.new(function(appName, eventType, app)
        if eventType == hs.application.watcher.activated then
            local bundle = app and app:bundleID() or "nil"
            if bundle ~= "com.raycast.macos" then
                print("[raycast-nav] other app activated: " .. (appName or "nil") .. " (" .. bundle .. ") -> deactivate")
                forceDeactivate()
            end
        elseif eventType == hs.application.watcher.deactivated then
            local bundle = app and app:bundleID() or "nil"
            if bundle == "com.raycast.macos" then
                print("[raycast-nav] Raycast deactivated -> deactivate")
                forceDeactivate()
            end
        end
    end)
    appWatcher:start()

    print("[raycast-nav] started")
end

function M.stop()
    forceDeactivate()
    if escapeTap then escapeTap:stop() end
    if appWatcher then appWatcher:stop() end
end

return M
