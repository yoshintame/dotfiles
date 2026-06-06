local M = {}

local MAX = 9
local POLL = 0.2

local history = {}
local lastChange = hs.pasteboard.changeCount()

local function snapshot()
    local img = hs.pasteboard.readImage()
    if img then
        return { kind = "image", data = img }
    end
    local str = hs.pasteboard.readString()
    if str and str ~= "" then
        return { kind = "text", data = str }
    end
    return nil
end

local function record()
    local item = snapshot()
    if not item then return end
    table.insert(history, 1, item)
    while #history > MAX do
        table.remove(history)
    end
end

local function parseChord(chord)
    local mods, key = {}, nil
    for token in string.gmatch(chord, "%S+") do
        if token == "cmd" or token == "alt" or token == "ctrl" or token == "shift" then
            table.insert(mods, token)
        else
            key = token
        end
    end
    return mods, key
end

local function pasteIndex(n)
    local item = history[n]
    if not item then
        hs.alert.show("Clipboard history: empty slot " .. n)
        return
    end
    if item.kind == "image" then
        hs.pasteboard.writeObjects(item.data)
    else
        hs.pasteboard.setContents(item.data)
    end
    lastChange = hs.pasteboard.changeCount()
    hs.eventtap.keyStroke({ "cmd" }, "v")
end

local watcher = hs.timer.new(POLL, function()
    local cc = hs.pasteboard.changeCount()
    if cc == lastChange then return end
    lastChange = cc
    record()
end)

function M.start(chords)
    record()
    watcher:start()
    for i, chord in ipairs(chords) do
        local mods, key = parseChord(chord)
        hs.hotkey.bind(mods, key, function() pasteIndex(i) end)
    end
    return M
end

return M
