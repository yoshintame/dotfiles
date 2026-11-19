local M = {}

function M.parse(chord)
    local mods = {}
    for token in chord:gmatch("%S+") do
        mods[#mods + 1] = token
    end
    local key = table.remove(mods)
    return mods, key
end

return M
