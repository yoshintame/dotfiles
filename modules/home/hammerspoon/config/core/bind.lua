local chord = require("core.chord")
local keys = require("core.keys")

local M = {}

local scoped = {}
local watcher = nil

local function normalize(trigger)
    local mods, key = chord.parse(trigger)
    local sorted = {}
    for i, mod in ipairs(mods) do sorted[i] = mod:lower() end
    table.sort(sorted)
    return table.concat(sorted, "+") .. "+" .. key:lower(), mods, key
end

local function sync(app)
    local bundleID = app and app:bundleID()
    for _, entry in ipairs(scoped) do
        if entry.app == bundleID then
            entry.hotkey:enable()
        else
            entry.hotkey:disable()
        end
    end
end

local function validate(rows, reserved)
    local global, perApp, parsed = {}, {}, {}
    for _, trigger in ipairs(reserved or {}) do
        global[(normalize(trigger))] = trigger
    end
    for i, row in ipairs(rows) do
        local trigger, action, app = row[1], row[2], row.app
        if type(trigger) ~= "string" or type(action) ~= "function" then
            error(("bind: row #%d needs a chord string and an action"):format(i), 0)
        end
        local id, mods, key = normalize(trigger)
        local code = keys.code(key)
        if not code then error(("bind: %q has an unknown key"):format(trigger), 0) end
        local clash = global[id] or (app and perApp[id .. "@" .. app]) or (not app and perApp[id])
        if clash then error(("bind: %q collides with %q"):format(trigger, clash), 0) end
        if app then
            perApp[id .. "@" .. app] = trigger
            perApp[id] = perApp[id] or trigger
        else
            global[id] = trigger
        end
        parsed[#parsed + 1] = { mods = mods, code = code, action = action, app = app }
    end
    return parsed
end

function M.direct(rows, reserved)
    for _, row in ipairs(validate(rows, reserved)) do
        if row.app then
            scoped[#scoped + 1] = { app = row.app, hotkey = hs.hotkey.new(row.mods, row.code, row.action) }
        else
            hs.hotkey.bind(row.mods, row.code, row.action)
        end
    end
    if #scoped > 0 and not watcher then
        watcher = hs.application.watcher.new(function(_, event, app)
            if event == hs.application.watcher.activated then sync(app) end
        end)
        watcher:start()
    end
    sync(hs.application.frontmostApplication())
end

return M
