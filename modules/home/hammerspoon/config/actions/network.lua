local timer = require("engine.timer")

local M = {}

local CONTROL_CENTER = "com.apple.controlcenter"
local MENU_EXTRA = "com.apple.menuextra.controlcenter"
local WIFI_TILE = "controlcenter-wifi"
local NETWORK_PREFIX = "wifi-network-"
local DETAILS_ACTION = "show details"
local STAGE_TIMEOUT = 10
local POLL = 0.15
local PRESS_SETTLE = 0.4
local CLOSED_READS = 3
local CLOSE_PRESSES = 3
local BUSY_TIMEOUT = 2 * STAGE_TIMEOUT + 5

local busySince = nil

local function findById(element, identifier)
    if element:attributeValue("AXIdentifier") == identifier then return element end
    for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
        local found = findById(child, identifier)
        if found then return found end
    end
end

local function menuExtra(app)
    for _, bar in ipairs(app:attributeValue("AXChildren") or {}) do
        if bar:attributeValue("AXRole") == "AXMenuBar" then
            for _, item in ipairs(bar:attributeValue("AXChildren") or {}) do
                if item:attributeValue("AXIdentifier") == MENU_EXTRA then return item end
            end
        end
    end
end

local function performNamed(element, fragment)
    for _, name in ipairs(element:actionNames() or {}) do
        if name:find(fragment, 1, true) then
            element:performAction(name)
            return true
        end
    end
    return false
end

local function poll(probe, timeout, done)
    local deadline = hs.timer.secondsSinceEpoch() + timeout
    local value = nil
    timer.waitUntil(function()
        value = probe()
        return value ~= nil or hs.timer.secondsSinceEpoch() > deadline
    end, function() done(value) end, POLL)
end

local function controlCenter(app, extra)
    local panel = {}

    function panel.isOpen()
        return #(app:attributeValue("AXWindows") or {}) > 0
    end

    function panel.find(identifier)
        return findById(app, identifier)
    end

    function panel.press()
        extra:performAction("AXPress")
    end

    function panel.close(leavingDetails, done)
        local presses = 0
        local closedReads = 0
        local function step()
            if panel.isOpen() then
                if presses >= CLOSE_PRESSES then return done() end
                presses = presses + 1
                closedReads = 0
                panel.press()
                return timer.after(PRESS_SETTLE, step)
            end
            closedReads = closedReads + 1
            if closedReads >= CLOSED_READS then return done() end
            timer.after(POLL, step)
        end
        if leavingDetails then
            presses = 1
            panel.press()
            return timer.after(PRESS_SETTLE, step)
        end
        step()
    end

    return panel
end

local function join(panel, ssid, finish)
    if not panel.isOpen() then panel.press() end
    poll(function() return panel.find(WIFI_TILE) end, STAGE_TIMEOUT, function(tile)
        if not tile then return finish(false, "⚠️ Control Center did not open") end
        if not performNamed(tile, DETAILS_ACTION) then return finish(false, "⚠️ Wi‑Fi details action not found") end

        poll(function() return panel.find(NETWORK_PREFIX .. ssid) end, STAGE_TIMEOUT, function(network)
            if not network then return finish(true, "⚠️ " .. ssid .. " not found in Wi‑Fi list") end
            if network:attributeValue("AXValue") == 1 then return finish(true, "📶 Already on " .. ssid) end
            network:performAction("AXPress")
            finish(true, "📶 Joining " .. ssid .. "…")
        end)
    end)
end

function M.joinHotspot(ssid)
    return function()
        local now = hs.timer.secondsSinceEpoch()
        if busySince and now - busySince < BUSY_TIMEOUT then
            hs.alert.show("📶 Still joining " .. ssid)
            return
        end

        local ccApp = hs.application.get(CONTROL_CENTER)
        local app = ccApp and hs.axuielement.applicationElement(ccApp)
        local extra = app and menuExtra(app)
        if not extra then
            hs.alert.show("⚠️ Control Center menu extra not found")
            return
        end

        busySince = now
        local wifi = hs.wifi.interfaceDetails()
        if wifi and not wifi.power then hs.wifi.setPower(true) end

        local panel = controlCenter(app, extra)
        local ok, err = pcall(join, panel, ssid, function(leavingDetails, message)
            hs.alert.show(message)
            panel.close(leavingDetails, function() busySince = nil end)
        end)
        if not ok then
            busySince = nil
            print("network: " .. tostring(err))
        end
    end
end

return M
