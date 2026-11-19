local obj = {
  name = "LeaderFlow",
  version = "1.0",
  author = "yoshintame",
  homepage = "",
  license = "MIT",
}
obj.__index = obj

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


