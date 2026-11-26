local timer = require("engine.timer")

local M = {}

local cache = {}

local function thumbnail(image, width)
    local size = image:size()
    local frame = { x = 0, y = 0, w = width, h = width * size.h / size.w }
    local canvas = hs.canvas.new(frame)
    canvas:appendElements({ type = "image", image = image, imageScaling = "scaleToFit", frame = frame })
    local small = canvas:imageFromCanvas()
    canvas:delete()
    return small
end

function M.get(id)
    return cache[id]
end

function M.forget(id)
    cache[id] = nil
end

function M.prune(alive)
    for id in pairs(cache) do
        if not alive[id] then cache[id] = nil end
    end
end

function M.refresh(entries, settings, onUpdate)
    local queue = {}
    for _, entry in ipairs(entries) do
        local cached = cache[entry.id]
        if not cached or timer.now() - cached.at > settings.maxAgeSeconds then queue[#queue + 1] = entry end
    end
    local pending = nil
    local function captureNext()
        local entry = table.remove(queue, 1)
        if not entry then
            pending = nil
            return
        end
        local cached = cache[entry.id] or {}
        local image = entry.win:snapshot()
        if image then
            cached.image = thumbnail(image, settings.width)
            cached.cornerRatio = settings.radius / math.max(entry.win:frame().w, 1)
            image = nil
            collectgarbage()
        end
        cached.at = timer.now()
        cache[entry.id] = cached
        onUpdate()
        pending = timer.after(0, captureNext)
    end
    pending = timer.after(0, captureNext)
    return function() timer.cancel(pending) end
end

return M
