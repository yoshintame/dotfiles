local M = {}

local function open(target, background)
    local args = {}
    if background then table.insert(args, "-g") end
    table.insert(args, target)
    hs.task.new("/usr/bin/open", nil, args):start()
end

local resolvedEditorPath = (function()
    local editor = hs.execute("/bin/sh -lc 'echo $VISUAL'"):match("^%S+") or "code"
    local abs = hs.execute("/bin/sh -lc 'command -v " .. editor .. "'"):match("^%S+")
    return abs or editor
end)()

function M.code(path)
    return function()
        local expanded = tostring(path):gsub("^~", os.getenv("HOME"))
        hs.task.new(resolvedEditorPath, nil, { expanded }):start()
    end
end

function M.url(url)
    return function() open(url, false) end
end

function M.raycast(url)
    -- open in background to preserve focus for pasting etc.
    return function() open(url, true) end
end

function M.launch(app)
    return function() hs.application.launchOrFocus(app) end
end

return M
