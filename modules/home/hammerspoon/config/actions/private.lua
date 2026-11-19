local M = {}

local loaded, values = pcall(require, "private")
if not loaded then
    print("private.lua is not rendered: " .. tostring(values))
    values = {}
end

function M.value(key, build)
    local value = values[key]
    if value then return build(value) end
    return function() hs.alert.show("No value for " .. key .. ": private.lua is not rendered") end
end

return M
