local M = {}

local CONFIG = os.getenv("HOME") .. "/Library/Application Support/activitywatch/aw-watcher-afk/aw-watcher-afk.toml"
local DEFAULT_TIMEOUT = 180
local POLL = 2

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

local config = nil
local timeout = DEFAULT_TIMEOUT
local state = nil
local dot = nil
local timer = nil

local function createDot()
    dot = hs.canvas.new({ x = 0, y = 0, w = config.size, h = config.size })
    dot:level(hs.canvas.windowLevels.overlay)
    dot:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
    dot[1] = { type = "circle", action = "fill", fillColor = config.colors.warn }
end

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
    dot:frame({ x = f.x + f.w - config.size - config.margin, y = f.y + config.margin, w = config.size, h = config.size })
    dot[1].fillColor = config.colors[next]
    dot:show()
end

local function tick()
    local idle = hs.host.idleTime()
    if idle < timeout - config.warnBeforeSeconds or suppressed() then
        show(nil)
    elseif idle < timeout then
        show("warn")
    else
        show("afk")
    end
end

function M.start(settings)
    config = settings
    timeout = readTimeout()
    createDot()
    timer = hs.timer.new(POLL, tick)
    timer:start()
    return M
end

return M
