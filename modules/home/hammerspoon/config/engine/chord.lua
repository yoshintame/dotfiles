local keycodes = require("engine.keycodes")

local M = {}

function M.parse(chord)
    local mods = {}
    for token in chord:gmatch("%S+") do
        mods[#mods + 1] = token
    end
    local key = table.remove(mods)
    return mods, key
end

function M.hotkey(chord)
    local mods, key = M.parse(chord)
    local code = key and keycodes.resolve(key)
    if not code then error(("chord: unknown key in %q"):format(chord), 0) end
    return mods, code
end

return M
