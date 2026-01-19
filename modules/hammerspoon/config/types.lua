---@meta

---@class hs
---@field application table
---@field hotkey table
---@field keycodes table
---@field pathwatcher table
---@field console hs.console
---@field notify hs.notify
---@field execute fun(command: string, with_user_env?: boolean): any
---@field reload function
---@field configdir string
---@field spoons table
---@field fnutils table
---@field urlevent table
---@field ipc table
---@field eventtap hs.eventtap
---@field loadSpoon fun(name: string): boolean
hs = {}

---@class hs.console
---@field printStyledtext fun(text: any)
---@field clearConsole fun()
hs.console = {}

---@class hs.eventtap
---@field keyStroke fun(mods: string[]|table, key: string, delay?: number)
---@field keyStrokes fun(text: string)
hs.eventtap = {}

---@class hs.notify
---@field new fun(opts: { title?: string, informativeText?: string }): hs.notify.object
hs.notify = {}

---@class hs.notify.object
---@field send fun(self: hs.notify.object)
local _hs_notify_object = {}

---@class spoon
---@field ReloadConfiguration ReloadConfiguration
---@field AppLauncher AppLauncher
---@field RecursiveBinder RecursiveBinder
---@field LeaderFlow LeaderFlow
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

---@class RecursiveBinder
---@field escapeKey any
---@field helperEntryEachLine number
---@field helperEntryLengthInChar number
---@field helperFormat table
---@field showBindHelper boolean
---@field helperModifierMapping table
---@field singleKey fun(key: string, name: string): any
---@field recursiveBind fun(keymap: table, modals?: any[]): fun()
local RecursiveBinder = {}

---@class LeaderFlow
---@field actions table
---@field setup fun(self: LeaderFlow, cfg: table)
local LeaderFlow = {}

---@class ipc
---@field cliInstall fun()
ipc = {}

keyNone = nil

