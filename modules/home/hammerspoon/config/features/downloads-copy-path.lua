local timer = require("engine.timer")

local M = {}

local log = hs.logger.new("dl-path", "warning")

local dir = nil
local settings = nil
local watcher = nil
local flush = nil
local known = {}
local pending = {}

local function basename(path)
    return path:match("([^/]+)/?$")
end

local function isPartial(name)
    if name:sub(1, 1) == "." then return true end
    for _, suffix in ipairs(settings.ignoreSuffixes) do
        if name:sub(-#suffix) == suffix then return true end
    end
    return false
end

local function isTopLevel(path)
    return path:match("^(.*)/[^/]+/?$") == dir
end

local function snapshot()
    local entries = {}
    for name in hs.fs.dir(dir) do
        if name ~= "." and name ~= ".." then entries[dir .. "/" .. name] = true end
    end
    return entries
end

local function copyPending()
    flush = nil
    local paths = {}
    for _, path in ipairs(pending) do
        if hs.fs.attributes(path) and not known[path] then
            known[path] = true
            paths[#paths + 1] = path
        end
    end
    pending = {}
    if #paths == 0 then return end
    hs.pasteboard.setContents(table.concat(paths, "\n"))
    local label = #paths == 1 and basename(paths[1]) or (#paths .. " items")
    hs.alert.show("Copied path: " .. label, settings.alertSeconds)
end

local function onChange(paths)
    for _, path in ipairs(paths) do
        local clean = path:gsub("/$", "")
        if not isTopLevel(clean) then
        elseif not hs.fs.attributes(clean) then
            known[clean] = nil
        elseif not isPartial(basename(clean)) and not known[clean] then
            pending[#pending + 1] = clean
        end
    end
    if #pending == 0 then return end
    timer.cancel(flush)
    flush = timer.after(settings.debounceSeconds, copyPending)
end

function M.start(config)
    settings = config
    dir = hs.fs.pathToAbsolute(config.dir)
    if not dir then
        log.w("directory not found: " .. config.dir)
        return M
    end
    known = snapshot()
    watcher = hs.pathwatcher.new(dir, onChange):start()
    return M
end

function M.stop()
    timer.cancel(flush)
    flush = nil
    if watcher then watcher:stop() end
    watcher = nil
end

return M
