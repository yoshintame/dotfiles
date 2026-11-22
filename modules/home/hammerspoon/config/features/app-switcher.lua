local chord = require("engine.chord")
local keycodes = require("engine.keycodes")
local timer = require("engine.timer")

local M = {}

local REGULAR_APP = 1

local config = nil
local focusFilter = nil
local appWatcher = nil
local quitModal = nil
local icons = {}
local armed = false
local committedAt = nil
local session = nil

local function now()
    return hs.timer.absoluteTime() / 1e9
end

local function regularApps()
    local seen, list = {}, {}
    local function add(app)
        if #list >= config.maxApps or not app or app:kind() ~= REGULAR_APP then return end
        local pid = app:pid()
        if seen[pid] then return end
        seen[pid] = true
        list[#list + 1] = app
    end
    add(hs.application.frontmostApplication())
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

local function layout(count)
    local c = config
    local inset = c.margin + c.highlightInset
    local labelY = inset + c.iconSize + c.highlightInset + c.labelGap
    local function icon(i)
        return { x = inset + (i - 1) * (c.iconSize + c.gap), y = inset, w = c.iconSize, h = c.iconSize }
    end
    return {
        width = inset * 2 + count * c.iconSize + (count - 1) * c.gap,
        height = labelY + c.labelHeight + c.margin,
        labelY = labelY,
        icon = icon,
        slot = function(i)
            local f = icon(i)
            return { x = f.x - c.highlightInset, y = f.y - c.highlightInset, w = f.w + c.highlightInset * 2, h = f.h + c.highlightInset * 2 }
        end,
    }
end

local function draw()
    local c, s = config, session
    local geo = layout(#s.apps)
    s.canvas:frame({
        x = s.screen.x + (s.screen.w - geo.width) / 2,
        y = s.screen.y + (s.screen.h - geo.height) / 2,
        w = geo.width,
        h = geo.height,
    })
    local elements = {
        {
            type = "rectangle",
            action = "fill",
            fillColor = c.background,
            roundedRectRadii = { xRadius = c.radius, yRadius = c.radius },
        },
        {
            type = "rectangle",
            action = "fill",
            fillColor = c.highlight,
            roundedRectRadii = { xRadius = c.radius / 2, yRadius = c.radius / 2 },
            frame = geo.slot(s.index),
        },
    }
    s.targets = {}
    for i, app in ipairs(s.apps) do
        local image = iconFor(app)
        if image then
            local id = "app" .. i
            s.targets[id] = i
            elements[#elements + 1] = {
                id = id,
                type = "image",
                image = image,
                trackMouseEnterExit = true,
                trackMouseMove = true,
                frame = geo.icon(i),
            }
        end
    end
    elements[#elements + 1] = {
        type = "text",
        text = s.apps[s.index]:name() or "",
        textAlignment = "center",
        textColor = c.text,
        textSize = c.textSize,
        frame = { x = 0, y = geo.labelY, w = geo.width, h = c.labelHeight },
    }
    s.canvas:replaceElements(elements)
end

local function close()
    if not session then return end
    timer.cancel(session.showTimer)
    timer.cancel(session.idleTimer)
    session.canvas:delete()
    quitModal:exit()
    session = nil
end

local function expire()
    armed = false
    close()
end

local function touch()
    timer.cancel(session.idleTimer)
    session.idleTimer = timer.after(config.idleCloseSeconds, expire)
end

local function selectSlot(i)
    session.index = i
    draw()
end

local function anchorMouse()
    session.mouseOrigin = hs.mouse.absolutePosition()
    session.mouseMoved = false
end

local function mouseMoved()
    if session.mouseMoved then return true end
    local pos, origin = hs.mouse.absolutePosition(), session.mouseOrigin
    session.mouseMoved = math.abs(pos.x - origin.x) + math.abs(pos.y - origin.y) >= config.hoverDistance
    return session.mouseMoved
end

local function onMouse(_, message, id)
    local target = session and session.targets[id]
    if not target or target == session.index then return end
    if (message == "mouseEnter" or message == "mouseMove") and mouseMoved() then
        selectSlot(target)
        touch()
    end
end

local function show()
    session.showTimer = nil
    session.canvas:show()
    quitModal:enter()
end

local function open(apps, index)
    local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = 1 })
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:clickActivating(false)
    canvas:mouseCallback(onMouse)
    session = { apps = apps, index = index, canvas = canvas, screen = hs.screen.mainScreen():frame() }
    anchorMouse()
    draw()
    session.showTimer = timer.after(config.showDelaySeconds, show)
    touch()
end

local function step(delta)
    if session then
        anchorMouse()
        selectSlot((session.index - 1 + delta) % #session.apps + 1)
        return touch()
    end
    if not armed and committedAt and now() - committedAt < config.lateTapSeconds then return end
    local apps = regularApps()
    if #apps == 0 then return end
    local index = delta > 0 and math.min(2, #apps) or #apps
    if armed then return open(apps, index) end
    apps[index]:activate()
end

local function quitSelected()
    session.apps[session.index]:kill()
    touch()
end

local function dropTerminated(_, event)
    if not session or event ~= hs.application.watcher.terminated then return end
    local kept, before = {}, 0
    for i, app in ipairs(session.apps) do
        if app:isRunning() then
            kept[#kept + 1] = app
            if i < session.index then before = before + 1 end
        end
    end
    if #kept == #session.apps then return end
    if #kept == 0 then return close() end
    session.apps = kept
    anchorMouse()
    selectSlot(math.min(before + 1, #kept))
end

function M.next() step(1) end
function M.prev() step(-1) end

function M.arm()
    armed = true
end

function M.commit()
    armed = false
    if not session then return end
    local app = session.apps[session.index]
    close()
    committedAt = now()
    app:activate()
end

function M.start(settings)
    config = settings
    focusFilter = hs.window.filter.new():setDefaultFilter({})
    focusFilter:subscribe(hs.window.filter.windowFocused, function() end)
    local mods, key = chord.parse(config.quit)
    quitModal = hs.hotkey.modal.new()
    quitModal:bind(mods, keycodes.resolve(key), quitSelected)
    appWatcher = hs.application.watcher.new(dropTerminated):start()
    return M
end

function M.stop()
    expire()
    if appWatcher then appWatcher:stop() end
    if quitModal then quitModal:delete() end
    if focusFilter then focusFilter:unsubscribeAll() end
    appWatcher, quitModal, focusFilter = nil, nil, nil
end

return M
