local clipboard = require("features.clipboard-history")
local keycodes = require("engine.keycodes")
local timer = require("engine.timer")

local M = {}

local COPY_POLL = 0.02
local COPY_TIMEOUT = 0.5
local SELECT_ALL_SETTLE = 0.05
local BUSY_TIMEOUT = 2

local TEXT_ROLES = {
    AXTextField = true,
    AXTextArea = true,
    AXComboBox = true,
    AXSearchField = true,
}

local busySince = nil

local function command(key)
    return pcall(hs.eventtap.keyStroke, { "cmd" }, keycodes.US_ANSI[key], 0)
end

local function accessibleSelection()
    local element = hs.uielement.focusedElement()
    if not element then return nil end
    local text = element:selectedText()
    if text and text ~= "" then return text end
    if text == "" and TEXT_ROLES[element:role()] then return "" end
    return nil
end

local function restore(saved)
    if saved and next(saved) then
        hs.pasteboard.writeAllData(saved)
    else
        hs.pasteboard.clearContents()
    end
end

local function copySelection(done)
    local before = hs.pasteboard.changeCount()
    local saved = hs.pasteboard.readAllData()
    clipboard.suspend()
    if not command("c") then
        clipboard.resume()
        return done(nil)
    end

    local deadline = hs.timer.absoluteTime() + COPY_TIMEOUT * 1e9
    timer.waitUntil(function()
        return hs.pasteboard.changeCount() ~= before or hs.timer.absoluteTime() > deadline
    end, function()
        local copied = hs.pasteboard.changeCount() ~= before
        local text = copied and hs.pasteboard.readString() or nil
        if copied then restore(saved) end
        clipboard.resume()
        done(text)
    end, COPY_POLL)
end

local function readSelection(done)
    local ok, text = pcall(accessibleSelection)
    if ok and text ~= nil then return done(text ~= "" and text or nil) end
    copySelection(done)
end

local function selectAll(done)
    command("a")
    timer.after(SELECT_ALL_SETTLE, done)
end

local function exclusive(start)
    return function()
        local now = hs.timer.secondsSinceEpoch()
        if busySince and now - busySince < BUSY_TIMEOUT then return end
        busySince = now
        local function release() busySince = nil end
        local ok, err = pcall(start, release)
        if not ok then
            release()
            print("selection: " .. tostring(err))
        end
    end
end

function M.withText(fn)
    return exclusive(function(release)
        readSelection(function(text)
            if text then
                release()
                return fn(text)
            end
            selectAll(function()
                readSelection(function(all)
                    release()
                    if all and all:match("%S") then fn(all) end
                end)
            end)
        end)
    end)
end

function M.withSelected(fn)
    return exclusive(function(release)
        readSelection(function(text)
            if text then
                release()
                return fn()
            end
            selectAll(function()
                release()
                fn()
            end)
        end)
    end)
end

return M
