local chord = require("engine.chord")
local input = require("actions.input")

local M = {}

local STATUS_LAYER = 25

local config = nil
local keys = nil
local session = nil
local keyTap = nil
local navigationCodes = nil
local closingCodes = nil

local function codes(names)
    local set = {}
    for _, name in ipairs(names) do
        local _, code = chord.hotkey(name)
        set[code] = true
    end
    return set
end

local function manager()
    return hs.application.get(config.bundleID)
end

local function isOpen()
    local app = manager()
    if not app then return false end
    local pid = app:pid()
    for _, info in ipairs(hs.window.list(true) or {}) do
        local layer = info.kCGWindowLayer or 0
        if info.kCGWindowOwnerPID == pid and info.kCGWindowIsOnscreen and layer > 0 and layer ~= STATUS_LAYER then
            return true
        end
    end
    return false
end

local function begin()
    session = { navigated = false }
    keyTap:start()
end

function M.cancel()
    if keyTap then keyTap:stop() end
    session = nil
end

local function onKey(event)
    if not session then return false end
    local code = event:getKeyCode()
    if closingCodes[code] then
        M.cancel()
    elseif navigationCodes[code] and isOpen() then
        session.navigated = true
    end
    return false
end

function M.trigger()
    if not manager() then return end
    if isOpen() then
        if not session then begin() end
        session.navigated = true
        keys.next()
        return
    end
    begin()
    keys.open()
end

function M.commit()
    if not session then return end
    local navigated = session.navigated
    M.cancel()
    if navigated and isOpen() then keys.select() end
end

function M.start(settings)
    config = settings
    keys = {
        open = input.shortcut(config.keys.open, 0),
        next = input.shortcut(config.keys.next, 0),
        select = input.shortcut(config.keys.select, 0),
    }
    navigationCodes = codes(config.navigationKeys)
    closingCodes = codes(config.closingKeys)
    keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onKey)
    return M
end

function M.stop()
    M.cancel()
    keyTap = nil
end

return M
