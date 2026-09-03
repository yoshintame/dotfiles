ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
local resolvedInit = hs.fs.pathToAbsolute(hs.configdir .. "/init.lua")
spoon.ReloadConfiguration.watch_paths = { resolvedInit and resolvedInit:match("^(.*)/") or hs.configdir }
spoon.ReloadConfiguration:start()

local ok, err = pcall(dofile, hs.configdir .. "/main.lua")
if not ok then
    hs.notify.new({ title = "Hammerspoon config error", informativeText = tostring(err) }):send()
    hs.console.printStyledtext("Hammerspoon config error: " .. tostring(err))
end


