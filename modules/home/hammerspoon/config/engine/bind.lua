local chord = require("engine.chord")
local keycodes = require("engine.keycodes")

local M = {}

local scoped = {}
local watcher = nil

local function identify(mods, key)
    local list = {}
    for mod in mods:gmatch("%S+") do list[#list + 1] = mod:lower() end
    table.sort(list)
    return table.concat(list, "+") .. "+" .. key:lower(), list
end

local function describe(mods, key)
    return mods == "" and key or (mods .. " " .. key)
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
        local mods, key = chord.parse(trigger)
        global[(identify(table.concat(mods, " "), key))] = trigger
    end
    for i, row in ipairs(rows) do
        local mods, key, action, app = row[1], row[2], row[3], row.app
        if type(mods) ~= "string" or type(key) ~= "string" or type(action) ~= "function" then
            error(("bind: row #%d needs modifiers, a key and an action"):format(i), 0)
        end
        local name = describe(mods, key)
        local id, modList = identify(mods, key)
        local code = keycodes.resolve(key)
        if not code then error(("bind: %q has an unknown key"):format(name), 0) end
        local clash = global[id] or (app and perApp[id .. "@" .. app]) or (not app and perApp[id])
        if clash then error(("bind: %q collides with %q"):format(name, clash), 0) end
        if app then
            perApp[id .. "@" .. app] = name
            perApp[id] = perApp[id] or name
        else
            global[id] = name
        end
        parsed[#parsed + 1] = { mods = modList, code = code, action = action, app = app }
    end
    return parsed
end

function M.fromChords(rows)
    local out = {}
    for _, row in ipairs(rows) do
        local mods, key = chord.parse(row[1])
        out[#out + 1] = { table.concat(mods, " "), key, row[2], app = row.app }
    end
    return out
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
