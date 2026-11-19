ipc = require("hs.ipc")
ipc.cliInstall()

hs.keycodes.log.setLogLevel("error")
hs.hotkey.setLogLevel("warning")

local resolvedInit = hs.fs.pathToAbsolute(hs.configdir .. "/init.lua")
configWatcher = hs.pathwatcher.new(resolvedInit and resolvedInit:match("^(.*)/") or hs.configdir, hs.reload):start()

local ok, err = pcall(dofile, hs.configdir .. "/main.lua")
if not ok then
    hs.notify.new({ title = "Hammerspoon config error", informativeText = tostring(err) }):send()
    hs.console.printStyledtext("Hammerspoon config error: " .. tostring(err))
end
