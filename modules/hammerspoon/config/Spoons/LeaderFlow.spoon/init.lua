---@diagnostic disable: undefined-global, undefined-field

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "LeaderFlow"
obj.version = "1.0"
obj.author = "yoshintame"
obj.homepage = ""
obj.license = "MIT"

-- action helpers exposed for config files
obj.actions = {}

local function parseKeystroke(keystroke)
  local parts = {}
  for part in keystroke:gmatch("%S+") do
    table.insert(parts, part)
  end
  local key = table.remove(parts)
  return parts, key
end

local function sh_open(target, background)
  local flag = background and "-g " or ""
  hs.execute(string.format("open %s%q", flag, target))
end

function obj.actions.openURL(url)
  return function() sh_open(url, false) end
end

function obj.actions.raycast(url)
  -- open in background to preserve focus for pasting etc.
  return function() sh_open(url, true) end
end

function obj.actions.shortcut(keystroke)
  local mods, key = parseKeystroke(keystroke)
  return function() hs.eventtap.keyStroke(mods, key) end
end

function obj.actions.text(s)
  return function()
    local out = s
    if type(s) == "function" then
      out = s()
    end
    if out == nil then out = "" end
    hs.eventtap.keyStrokes(tostring(out))
  end
end

function obj.actions.currentDate()
  return obj.actions.text(function()
    local t = os.date("*t")
    local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
    return string.format("%d %s %d", t.day, months[t.month], t.year)
  end)
end

function obj.actions.launch(app)
  return function() hs.application.launchOrFocus(app) end
end

function obj.actions.reload()
  return function()
    hs.reload()
    hs.console.clearConsole()
  end
end

-- builder/DSL compiler:
-- spec = {
--   { "p", "Passwords", fn },
--   { "u", "[utils]", {
--     { "c", "Color Picker", fn },
--   }},
-- }
local function compileSpec(spec)
  local out = {}
  for i, entry in ipairs(spec) do
    local key = entry[1]
    local label = entry[2]
    local actionOrChildren = entry[3]

    if type(key) ~= "string" or key == "" then
      error("LeaderFlow: spec entry #" .. tostring(i) .. " has invalid key")
    end
    if type(label) ~= "string" then
      error("LeaderFlow: spec entry #" .. tostring(i) .. " has invalid label")
    end
    if actionOrChildren == nil then
      error("LeaderFlow: spec entry #" .. tostring(i) .. " missing action/children")
    end

    local specKey = spoon.RecursiveBinder.singleKey(key, label)
    if type(actionOrChildren) == "table" then
      out[specKey] = compileSpec(actionOrChildren)
    else
      out[specKey] = actionOrChildren
    end
  end
  return out
end

-- Public API:
-- spoon.LeaderFlow:setup({
--   leader = { mods = {}, key = "F18" },
--   ui = { show = true, escapeKey = { { {}, "F18" }, { {}, "escape" } }, helperEntryEachLine = 3, format = {...} },
--   spec = {...},
-- })
function obj:setup(cfg)
  cfg = cfg or {}

  -- Bundle RecursiveBinder as an internal dependency (same pattern as Hammerflow.spoon)
  package.path = package.path .. ";" .. hs.configdir .. "/Spoons/LeaderFlow.spoon/Spoons/?.spoon/init.lua"
  hs.loadSpoon("RecursiveBinder")

  local ui = cfg.ui or {}
  if ui.show ~= nil then spoon.RecursiveBinder.showBindHelper = ui.show end
  if ui.escapeKey ~= nil then spoon.RecursiveBinder.escapeKey = ui.escapeKey end
  if ui.helperEntryEachLine ~= nil then spoon.RecursiveBinder.helperEntryEachLine = ui.helperEntryEachLine end
  if ui.format ~= nil then spoon.RecursiveBinder.helperFormat = ui.format end

  if cfg.abortOnMouseClick ~= nil then spoon.RecursiveBinder.abortOnMouseClick = cfg.abortOnMouseClick end

  local keys = compileSpec(cfg.spec or {})

  local leader = cfg.leader or {}
  local leaderMods = leader.mods or {}
  local leaderKey = leader.key or "F18"

  -- avoid duplicate binds on reload
  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  self._hotkey = hs.hotkey.bind(leaderMods, leaderKey, spoon.RecursiveBinder.recursiveBind(keys))
end

return obj


