local chord = require("engine.chord")

local M = {}

function M.shortcut(keystroke, delay)
    local mods, key = chord.hotkey(keystroke)
    return function() hs.eventtap.keyStroke(mods, key, delay) end
end

function M.codeBlock(text)
    local newline = text:sub(-1) == "\n" and "" or "\n"
    return "```\n" .. text .. newline .. "```"
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
