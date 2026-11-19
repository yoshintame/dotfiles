local bin = require("core.bin")
local sys = require("core.sys")

local M = {}

local SETTINGS_KEY = "Coffee"
local LOW_BATTERY = 20
local INDICATOR = "CoffeeActive"
local INDICATOR_POSITION = 300

local applied
local indicator

local function sessionEnd()
    local session = (hs.settings.get(SETTINGS_KEY) or {}).session
    if session == nil or (session ~= 0 and session <= os.time()) then return nil end
    return session
end

local function formatClock(seconds)
    local hours = seconds // 3600
    local minutes = seconds % 3600 // 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
    end
    return string.format("%d:%02d", minutes, seconds % 60)
end

local function indicatorTitle()
    local session = sessionEnd()
    if not session or session == 0 then return "●" end
    return "● " .. formatClock(math.max(0, session - os.time()))
end

local ticker = nil

local function seedIndicatorPosition()
    if hs.settings.get("HSNSStatusItem Preferred Position " .. INDICATOR) ~= nil then return end
    hs.settings.set("NSStatusItem Preferred Position " .. INDICATOR, INDICATOR_POSITION)
    hs.settings.set("HSNSStatusItem Preferred Position " .. INDICATOR, INDICATOR_POSITION)
end

local function updateIndicator(session)
    if not session then
        ticker:stop()
        if indicator then
            indicator:delete()
            indicator = nil
        end
        return
    end

    if not indicator then
        seedIndicatorPosition()
        indicator = hs.menubar.new(true, INDICATOR)
        indicator:setMenu({
            { title = "Остановить", fn = function() spoon.Coffee:endSession() end },
        })
    end
    indicator:setTitle(indicatorTitle())

    if session == 0 then
        ticker:stop()
    else
        ticker:start()
    end
end

local function setSleepDisabled(disabled)
    if applied == disabled then return end
    applied = disabled
    sys.run(bin.sudo, { "-n", bin.pmset, "-a", "disablesleep", disabled and "1" or "0" }, {
        onExit = function(code, _, stderr)
            if code ~= 0 then
                applied = nil
                hs.notify.new({
                    title = "Coffee",
                    informativeText = "pmset disablesleep failed: " .. stderr,
                }):send()
            end
        end,
    })
end

local function sync()
    local session = sessionEnd()
    setSleepDisabled(session ~= nil)
    updateIndicator(session)
end

function M.toggle()
    if sessionEnd() then
        spoon.Coffee:endSession()
        hs.alert.show("Сон включён")
    else
        spoon.Coffee:startSession()
        hs.alert.show("Сон отключён без срока")
    end
end

function M.awakeFor(hours)
    return function()
        spoon.Coffee:startSession(hours * 60)
        hs.alert.show("Сон отключён до " .. os.date("%H:%M", os.time() + hours * 3600))
    end
end

function M.start()
    if hs.settings.get(SETTINGS_KEY) == nil then
        hs.settings.set(SETTINGS_KEY, { endOnLowBattery = true })
    end

    hs.loadSpoon("Coffee")
    spoon.Coffee.lowBatteryThreshold = LOW_BATTERY
    spoon.Coffee:start()

    ticker = hs.timer.new(1, function()
        if indicator then indicator:setTitle(indicatorTitle()) end
    end)

    hs.settings.watchKey("coffee-lid", SETTINGS_KEY, sync)
    sync()

    return M
end

function M.stop()
    sys.detach("/bin/sleep 5; /usr/bin/pgrep -x Hammerspoon >/dev/null || "
        .. bin.sudo .. " -n " .. bin.pmset .. " -a disablesleep 0")
end

return M
