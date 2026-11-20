local M = {}

local settings = nil
local focusFilter = nil
local canvas = nil
local apps = {}
local index = 0
local icons = {}
local HIGHLIGHT = 2
local label = nil

local function regularApps()
    local seen, list = {}, {}
    local function add(app)
        if not app or app:kind() ~= 1 then return end
        local pid = app:pid()
        if seen[pid] then return end
        seen[pid] = true
        list[#list + 1] = app
    end
    for _, win in ipairs(focusFilter:getWindows(hs.window.filter.sortByFocusedLast)) do
        add(win:application())
    end
    for _, app in ipairs(hs.application.runningApplications()) do add(app) end
    return list
end

local function iconFor(app)
    local id = app:bundleID()
    if not id then return nil end
    if icons[id] == nil then icons[id] = hs.image.imageFromAppBundle(id) or false end
    return icons[id] or nil
end

local function slotFrame(i)
    local s = settings
    return {
        x = s.padding + (i - 1) * (s.iconSize + s.gap) - s.highlightInset,
        y = s.padding - s.highlightInset,
        w = s.iconSize + s.highlightInset * 2,
        h = s.iconSize + s.highlightInset * 2,
    }
end

local function render()
    local s = settings
    local count = math.min(#apps, s.maxApps)
    local width = s.padding * 2 + count * s.iconSize + (count - 1) * s.gap
    local height = s.padding * 2 + s.iconSize + s.labelHeight
    local screen = hs.screen.mainScreen():frame()
    canvas = hs.canvas.new({
        x = screen.x + (screen.w - width) / 2,
        y = screen.y + (screen.h - height) / 2,
        w = width,
        h = height,
    })
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = s.background,
        roundedRectRadii = { xRadius = s.radius, yRadius = s.radius },
    }, {
        type = "rectangle",
        action = "fill",
        fillColor = s.highlight,
        roundedRectRadii = { xRadius = s.radius / 2, yRadius = s.radius / 2 },
        frame = slotFrame(index),
    })
    for i = 1, count do
        local image = iconFor(apps[i])
        if image then
            canvas:appendElements({
                type = "image",
                image = image,
                frame = {
                    x = s.padding + (i - 1) * (s.iconSize + s.gap),
                    y = s.padding,
                    w = s.iconSize,
                    h = s.iconSize,
                },
            })
        end
    end
    canvas:appendElements({
        type = "text",
        text = apps[index]:name() or "",
        textAlignment = "center",
        textColor = s.text,
        textSize = s.textSize,
        frame = { x = 0, y = s.padding + s.iconSize + 6, w = width, h = s.labelHeight },
    })
    label = #canvas
    canvas:show()
end

local function choose(i)
    index = i
    canvas[HIGHLIGHT].frame = slotFrame(index)
    canvas[label].text = apps[index]:name() or ""
end

local function step(delta)
    if canvas then
        local count = math.min(#apps, settings.maxApps)
        choose((index - 1 + delta) % count + 1)
        return
    end
    apps = regularApps()
    if #apps == 0 then return end
    local count = math.min(#apps, settings.maxApps)
    index = delta > 0 and math.min(2, count) or count
    render()
end

function M.next() step(1) end
function M.prev() step(-1) end

function M.commit()
    if not canvas then return end
    local app = apps[index]
    canvas:delete()
    canvas = nil
    apps = {}
    if app then app:activate() end
end

function M.start(config)
    settings = config
    focusFilter = hs.window.filter.new():setDefaultFilter({})
    focusFilter:subscribe(hs.window.filter.windowFocused, function() end)
    return M
end

function M.stop()
    if canvas then canvas:delete() end
    canvas = nil
    if focusFilter then focusFilter:unsubscribeAll() end
    focusFilter = nil
end

return M
