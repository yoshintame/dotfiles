---@meta

---@class hs
---@field application table
---@field hotkey table
---@field keycodes table
---@field pathwatcher table
---@field reload function
---@field configdir string
---@field spoons table
---@field fnutils table
---@field urlevent table
---@field ipc table
---@field loadSpoon fun(name: string): boolean
hs = {}

---@class spoon
---@field ReloadConfiguration ReloadConfiguration
---@field AppLauncher AppLauncher
---@field Hammerflow Hammerflow
spoon = {}

---@class ReloadConfiguration
---@field watch_paths string[]
---@field start fun(self: ReloadConfiguration): ReloadConfiguration
---@field bindHotkeys fun(self: ReloadConfiguration, mapping: table)
local ReloadConfiguration = {}

---@class AppLauncher
---@field bindHotkeys fun(self: AppLauncher, mapping: table)
---@field launchOrFocusApp fun(self: AppLauncher, name: string)
---@field launchOrFocusWarpApp fun(self: AppLauncher, name: string)
local AppLauncher = {}

---@class Hammerflow
---@field auto_reload boolean
---@field loadFirstValidTomlFile fun(paths: string[])
---@field registerFunctions fun(...: any)
---@field registerFormat fun(opts: table)
local Hammerflow = {}

---@class ipc
---@field cliInstall fun()
ipc = {}

