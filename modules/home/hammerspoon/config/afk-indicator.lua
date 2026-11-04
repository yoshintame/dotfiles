local M = {}

local CONFIG = os.getenv("HOME") .. "/Library/Application Support/activitywatch/aw-watcher-afk/aw-watcher-afk.toml"
local DEFAULT_TIMEOUT = 180
local WARN_BEFORE = 30
local POLL = 2
local SIZE = 12
local MARGIN = 8

local COLORS = {
    warn = { red = 1, green = 0.6, blue = 0, alpha = 0.9 },
    afk = { white = 0.6, alpha = 0.7 },
}

local function readTimeout()
    local f = io.open(CONFIG, "r")
    if not f then return DEFAULT_TIMEOUT end
    local section
    for line in f:lines() do
        section = line:match("^%s*%[(.-)%]") or section
        local value = section == "aw-watcher-afk" and line:match("^%s*timeout%s*=%s*(%d+)")
        if value then
            f:close()
            return tonumber(value)
        end
    end
    f:close()
    return DEFAULT_TIMEOUT
end

local timeout = DEFAULT_TIMEOUT
local state = nil

local dot = hs.canvas.new({ x = 0, y = 0, w = SIZE, h = SIZE })
dot:level(hs.canvas.windowLevels.overlay)
dot:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
dot[1] = { type = "circle", action = "fill", fillColor = COLORS.warn }

local function suppressed()
    if hs.caffeinate.sessionProperties().CGSSessionScreenIsLocked then return true end
    local output = hs.audiodevice.defaultOutputDevice()
    return output ~= nil and output:inUse()
end

local function show(next)
    if state == next then return end
    state = next
    if not next then
        dot:hide()
        return
    end
    local f = hs.screen.mainScreen():frame()
    dot:frame({ x = f.x + f.w - SIZE - MARGIN, y = f.y + MARGIN, w = SIZE, h = SIZE })
    dot[1].fillColor = COLORS[next]
    dot:show()
end

local function tick()
    local idle = hs.host.idleTime()
    if idle < timeout - WARN_BEFORE or suppressed() then
        show(nil)
    elseif idle < timeout then
        show("warn")
    else
        show("afk")
    end
end

local timer = hs.timer.new(POLL, tick)

function M.start()
    timeout = readTimeout()
    timer:start()
    return M
end

return M
