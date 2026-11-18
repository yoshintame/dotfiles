local M = {}

local SUDO = "/usr/bin/sudo"
local PMSET = "/usr/bin/pmset"
local SETTINGS_KEY = "Coffee"
local LOW_BATTERY = 20

local applied

local function sessionActive()
    local session = (hs.settings.get(SETTINGS_KEY) or {}).session
    return session ~= nil and (session == 0 or session > os.time())
end

local function setSleepDisabled(disabled)
    if applied == disabled then return end
    applied = disabled
    hs.task.new(SUDO, function(code, _, stderr)
        if code ~= 0 then
            applied = nil
            hs.notify.new({
                title = "Coffee",
                informativeText = "pmset disablesleep failed: " .. (stderr or ""),
            }):send()
        end
    end, { "-n", PMSET, "-a", "disablesleep", disabled and "1" or "0" }):start()
end

local function sync()
    setSleepDisabled(sessionActive())
end

function M.start()
    if hs.settings.get(SETTINGS_KEY) == nil then
        hs.settings.set(SETTINGS_KEY, { endOnLowBattery = true })
    end

    hs.loadSpoon("Coffee")
    spoon.Coffee.lowBatteryThreshold = LOW_BATTERY
    spoon.Coffee:start()

    hs.settings.watchKey("coffee-lid", SETTINGS_KEY, sync)
    sync()

    hs.shutdownCallback = function()
        hs.execute(SUDO .. " -n " .. PMSET .. " -a disablesleep 0")
    end

    return M
end

return M
