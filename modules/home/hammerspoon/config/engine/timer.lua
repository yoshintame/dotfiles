local M = {}

local pending = {}

function M.after(seconds, fn)
    local timer
    timer = hs.timer.doAfter(seconds, function()
        pending[timer] = nil
        fn()
    end)
    pending[timer] = true
    return timer
end

function M.waitUntil(predicate, fn, interval)
    local timer
    timer = hs.timer.waitUntil(predicate, function()
        pending[timer] = nil
        fn()
    end, interval)
    pending[timer] = true
    return timer
end

function M.cancel(timer)
    if not timer then return end
    timer:stop()
    pending[timer] = nil
end

return M
