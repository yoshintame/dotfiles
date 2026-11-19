local bin = require("core.bin")

local M = {}

local held = {}

local function hold(object)
    held[object] = true
    return object
end

local function release(object)
    held[object] = nil
end

function M.run(path, args, opts)
    opts = opts or {}
    local task
    task = hs.task.new(path, function(code, out, err)
        release(task)
        if opts.onExit then opts.onExit(code, out or "", err or "") end
    end, args or {})
    if opts.env then task:setEnvironment(opts.env) end
    if opts.cwd then task:setWorkingDirectory(opts.cwd) end
    hold(task)
    if not task:start() then
        release(task)
        if opts.onExit then opts.onExit(-1, "", "failed to start " .. path) end
    end
    return task
end

function M.after(seconds, fn)
    local timer
    timer = hs.timer.doAfter(seconds, function()
        release(timer)
        fn()
    end)
    return hold(timer)
end

function M.waitUntil(predicate, fn, interval)
    local timer
    timer = hs.timer.waitUntil(predicate, function()
        release(timer)
        fn()
    end, interval)
    return hold(timer)
end

function M.cancel(timer)
    if not timer then return end
    timer:stop()
    release(timer)
end

function M.open(target, opts)
    opts = opts or {}
    local args = {}
    if opts.background then args[#args + 1] = "-g" end
    if opts.app then
        args[#args + 1] = "-a"
        args[#args + 1] = opts.app
    end
    if opts.bundle then
        args[#args + 1] = "-b"
        args[#args + 1] = opts.bundle
    end
    if target then args[#args + 1] = target end
    return M.run(bin.open, args)
end

function M.detach(command)
    hs.execute("(" .. command .. ") >/dev/null 2>&1 &")
end

return M
