ipc = require("hs.ipc")
ipc.cliInstall()

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = { os.getenv("HOME") .. "/.dotfiles/modules/hammerspoon" }
spoon.ReloadConfiguration:start()

local ok, err = pcall(dofile, hs.configdir .. "/main.lua")
if not ok then
    hs.notify.new({ title = "Hammerspoon config error", informativeText = tostring(err) }):send()
    hs.console.printStyledtext("Hammerspoon config error: " .. tostring(err))
end


