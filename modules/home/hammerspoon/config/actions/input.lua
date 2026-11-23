local chord = require("engine.chord")

local M = {}

function M.shortcut(keystroke)
    local mods, key = chord.hotkey(keystroke)
    return function() hs.eventtap.keyStroke(mods, key) end
end

function M.text(s)
    return function()
        local out = s
        if type(s) == "function" then
            out = s()
        end
        if out == nil then out = "" end
        hs.eventtap.keyStrokes(tostring(out))
    end
end

function M.date(fmt)
    return M.text(function()
        return (os.date(fmt):gsub("^%s+", ""))
    end)
end

function M.unixTime()
    return M.text(function() return tostring(os.time()) end)
end

return M
