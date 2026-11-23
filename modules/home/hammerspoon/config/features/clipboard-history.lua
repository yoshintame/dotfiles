local keycodes = require("engine.keycodes")
local timer = require("engine.timer")

local M = {}

local POLL = 0.2
local RESTORE_DELAY = 0.3

local config = nil
local history = {}
local lastChange = nil
local watcher = nil
local restoring = false

local PRIVATE_TYPES = {
    ["org.nspasteboard.ConcealedType"] = true,
    ["org.nspasteboard.TransientType"] = true,
}

local function isPrivate()
    for _, uti in ipairs(hs.pasteboard.contentTypes() or {}) do
        if PRIVATE_TYPES[uti] then return true end
    end
    return false
end

local function snapshot()
    if isPrivate() then return nil end
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
    while #history > config.size do
        table.remove(history)
    end
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
    hs.eventtap.keyStroke({ "cmd" }, keycodes.US_ANSI.v)
end

function M.pasteAt(n)
    return function() pasteIndex(n) end
end

function M.pasteTransformed(transform)
    return function()
        if restoring then return end
        local text = hs.pasteboard.readString()
        if not text or text == "" then return end
        local saved = hs.pasteboard.readAllData()
        M.suspend()
        restoring = true
        hs.pasteboard.setContents(transform(text))
        pcall(hs.eventtap.keyStroke, { "cmd" }, keycodes.US_ANSI.v, 0)
        timer.after(RESTORE_DELAY, function()
            hs.pasteboard.writeAllData(saved)
            restoring = false
            M.resume()
        end)
    end
end

function M.suspend()
    if watcher then watcher:stop() end
end

function M.resume()
    lastChange = hs.pasteboard.changeCount()
    if watcher then watcher:start() end
end

function M.start(settings)
    config = settings
    lastChange = hs.pasteboard.changeCount()
    record()
    watcher = hs.timer.new(POLL, function()
        local cc = hs.pasteboard.changeCount()
        if cc == lastChange then return end
        lastChange = cc
        record()
    end)
    watcher:start()
    return M
end

return M
