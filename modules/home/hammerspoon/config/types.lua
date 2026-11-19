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
---@field AppLauncher AppLauncher
---@field SmsOtp SmsOtp
spoon = {}

---@class SmsOtp
---@field dbPath string
---@field pollInterval number
---@field maxAge number
---@field clearAfter number
---@field busyTimeoutMs number
---@field start fun(self: SmsOtp): SmsOtp
---@field stop fun(self: SmsOtp): SmsOtp
local SmsOtp = {}

---@class AppLauncher
---@field bindHotkeys fun(self: AppLauncher, mapping: table)
---@field launchOrFocusApp fun(self: AppLauncher, name: string)
---@field launchOrFocusWarpApp fun(self: AppLauncher, name: string)
local AppLauncher = {}

---@class ipc
---@field cliInstall fun()
ipc = {}
