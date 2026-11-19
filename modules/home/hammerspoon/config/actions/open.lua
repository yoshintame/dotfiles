local bin = require("core.bin")
local deeplink = require("core.deeplink")
local sys = require("core.sys")

local M = {}

function M.editor(path)
    return function()
        local expanded = tostring(path):gsub("^~", os.getenv("HOME"))
        sys.run(bin.zed, { expanded })
    end
end

function M.url(url)
    return function() sys.open(url) end
end

function M.raycast(path, params)
    local url = deeplink.raycast(path, params)
    -- open in background to preserve focus for pasting etc.
    return function() sys.open(url, { background = true }) end
end

function M.changeCase(name)
    return M.raycast("extensions/erics118/change-case/change-case", { context = { case = name .. " Case" } })
end

function M.launch(app)
    return function() hs.application.launchOrFocus(app) end
end

function M.draft()
    local dir = os.getenv("HOME") .. "/.local/share/scratchpad"
    hs.fs.mkdir(dir)
    local path = dir .. "/draft-" .. os.date("%Y-%m-%d--%H-%M-%S") .. ".md"
    local f = io.open(path, "w")
    if f then f:close() end
    sys.open(path, { app = "Zed" })
end

return M
