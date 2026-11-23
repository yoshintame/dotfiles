local deeplink = require("engine.deeplink")
local process = require("engine.process")

local M = {}

function M.editor(binary)
    return function(path)
        local expanded = tostring(path):gsub("^~", os.getenv("HOME"))
        return function() process.run(binary, { expanded }) end
    end
end

function M.url(url)
    return function() process.open(url) end
end

function M.search(template)
    return function(text)
        local query = hs.http.encodeForQuery((text:match("^%s*(.-)%s*$"):gsub("%s+", " ")))
        process.open((template:gsub("%%s", function() return query end)))
    end
end

function M.raycast(path, params)
    local url = deeplink.raycast(path, params)
    -- open in background to preserve focus for pasting etc.
    return function() process.open(url, { background = true }) end
end

function M.changeCase(name)
    return M.raycast("extensions/erics118/change-case/change-case", { context = { case = name .. " Case" } })
end

function M.launch(app)
    return function() hs.application.launchOrFocus(app) end
end

function M.draft(opts)
    local dir = opts.dir:gsub("^~", os.getenv("HOME"))
    return function()
        hs.fs.mkdir(dir)
        local path = dir .. "/draft-" .. os.date("%Y-%m-%d--%H-%M-%S") .. ".md"
        local f = io.open(path, "w")
        if f then f:close() end
        process.open(path, { app = opts.app })
    end
end

return M
