local chord = require("core.chord")

local M = {}

function M.shortcut(keystroke)
    local mods, key = chord.parse(keystroke)
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

function M.currentDate()
    return M.text(function()
        local t = os.date("*t")
        local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
        return string.format("%d %s %d", t.day, months[t.month], t.year)
    end)
end

function M.date(fmt)
    return M.text(function()
        return os.date(fmt)
    end)
end

return M
