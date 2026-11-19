local bin = require("engine.bin")
local process = require("engine.process")

local M = {}

local function systemEvents(command)
    return function() hs.osascript.applescript('tell application "System Events" to ' .. command) end
end

local function asAdmin(shellCommand)
    return function()
        process.run(bin.osascript, { "-e", 'do shell script "' .. shellCommand .. '" with administrator privileges' })
    end
end

M.restart = systemEvents("restart")
M.shutdown = systemEvents("shut down")
M.logout = systemEvents("log out")
M.hardRestart = asAdmin("shutdown -r now")
M.hardShutdown = asAdmin("shutdown -h now")

function M.lock()
    hs.caffeinate.lockScreen()
end

function M.sleep()
    hs.caffeinate.systemSleep()
end

return M
