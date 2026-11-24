local chord = require("engine.chord")
local timer = require("engine.timer")
local windowActions = require("actions.windows")
local previews = require("features.app-switcher.previews")
local view = require("features.app-switcher.view")

local M = {}

local REGULAR_APP = 1

local config = nil
local focusFilter = nil
local appWatcher = nil
local keysModal = nil
local clickTap = nil
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

local function windowsOf(app)
    local pid, list = app:pid(), {}
    for _, win in ipairs(focusFilter:getWindows(hs.window.filter.sortByFocusedLast)) do
        if #list >= config.maxWindows then break end
        local owner, id = win:application(), win:id()
        if id and owner and owner:pid() == pid and win:isStandard() then
            list[#list + 1] = { win = win, id = id, title = win:title() or "" }
        end
    end
    return list
end

local function draw()
    session.targets = view.render(session.canvas, session, config, previews.get)
end

local function stopCapture()
    if session.stopCapture then session.stopCapture() end
    session.stopCapture = nil
end

local function capture()
    stopCapture()
    if not session.column then return end
    session.stopCapture = previews.refresh(session.column.windows, config.preview, function()
        if session then draw() end
    end)
end

local function close()
    if not session then return end
    for _, pending in pairs(session.timers) do timer.cancel(pending) end
    stopCapture()
    session.canvas:delete()
    keysModal:exit()
    clickTap:stop()
    session = nil
end

local function expire()
    armed = false
    close()
end

local function touch()
    timer.cancel(session.timers.idle)
    session.timers.idle = timer.after(config.idleCloseSeconds, expire)
end

local function anchorMouse()
    session.hover = { origin = hs.mouse.absolutePosition(), moved = false }
end

local function mouseMoved()
    local hover = session.hover
    if not hover.moved then
        local pos = hs.mouse.absolutePosition()
        hover.moved = math.abs(pos.x - hover.origin.x) + math.abs(pos.y - hover.origin.y) >= config.hoverDistance
    end
    return hover.moved
end

local function interact(fn)
    anchorMouse()
    fn()
    if session then touch() end
end

local function columnFor(app, keep)
    local windows = windowsOf(app)
    if #windows == 0 then return nil end
    if keep then
        local index = math.min(keep.index, #windows)
        for j, entry in ipairs(windows) do
            if entry.id == keep.id then index = j end
        end
        return { windows = windows, index = index }
    end
    local frontmost = hs.application.frontmostApplication()
    local current = frontmost and frontmost:pid() == app:pid()
    return { windows = windows, index = (current and #windows > 1) and 2 or 1 }
end

local function setColumn(column)
    session.column = column
    capture()
end

local function selectedEntry()
    local column = session.column
    return column and column.windows[column.index]
end

local function refreshColumn()
    local column = session.column
    if not column then return end
    local entry = selectedEntry()
    setColumn(columnFor(session.apps[session.appIndex], { id = entry and entry.id, index = column.index }))
end

local function selectApp(i)
    setColumn(nil)
    session.appIndex = i
    draw()
end

local function selectWindow(j)
    session.column.index = j
    draw()
end

local function moveApp(delta)
    selectApp((session.appIndex - 1 + delta) % #session.apps + 1)
end

local function enterColumn()
    setColumn(columnFor(session.apps[session.appIndex]))
    draw()
end

local function moveWindow(delta)
    local column = session.column
    if not column then return enterColumn() end
    selectWindow((column.index - 1 + delta) % #column.windows + 1)
end

local function quitApp()
    session.apps[session.appIndex]:kill()
end

local function closeWindow()
    local entry = selectedEntry()
    if entry then entry.win:close() end
end

local function onMouse(_, message, id)
    local target = session and session.targets[id]
    if not target or (message ~= "mouseEnter" and message ~= "mouseMove") or not mouseMoved() then return end
    if target.kind == "window" then selectWindow(target.index) else selectApp(target.index) end
    touch()
end

local function clickOutside(event)
    if not session then return false end
    local point, frame = event:location(), session.canvas:frame()
    if point.x >= frame.x and point.x <= frame.x + frame.w and point.y >= frame.y and point.y <= frame.y + frame.h then
        return false
    end
    close()
    return true
end

local function show()
    session.timers.show = nil
    session.canvas:show()
    keysModal:enter()
    clickTap:start()
end

local function prunePreviews()
    local alive = {}
    for _, win in ipairs(focusFilter:getWindows()) do
        local id = win:id()
        if id then alive[id] = true end
    end
    previews.prune(alive)
end

local function open(apps, index, column, mode)
    prunePreviews()
    local canvas = hs.canvas.new({ x = 0, y = 0, w = 1, h = 1 })
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:clickActivating(false)
    canvas:mouseCallback(onMouse)
    session = {
        apps = apps,
        appIndex = index,
        column = column,
        mode = mode,
        canvas = canvas,
        screen = hs.screen.mainScreen():frame(),
        timers = {},
    }
    anchorMouse()
    capture()
    draw()
    session.timers.show = timer.after(config.showDelaySeconds, show)
    touch()
end

local function lateTap()
    return not armed and committedAt and now() - committedAt < config.lateTapSeconds
end

local function focus(app, entry)
    if not entry then return app:activate() end
    windowActions.focusById(entry.id, function()
        app:activate()
        entry.win:focus()
    end)
end

local tapMoves = {
    app = { app = { move = moveApp, delta = 1 }, window = { move = moveApp, delta = -1 } },
    window = { app = { move = moveWindow, delta = -1 }, window = { move = moveWindow, delta = 1 } },
}

local function entry(kind, apps)
    if kind == "window" then
        local column = columnFor(apps[1])
        if column then return "window", 1, column end
    end
    return "app", math.min(2, #apps)
end

local function step(kind)
    if session then
        local tap = tapMoves[session.mode][kind]
        return interact(function() tap.move(tap.delta) end)
    end
    if lateTap() then return end
    local apps = regularApps()
    if #apps == 0 then return end
    local mode, index, column = entry(kind, apps)
    if armed then return open(apps, index, column, mode) end
    if mode ~= kind then return end
    focus(apps[index], column and column.windows[column.index])
end

local function dropTerminated(_, event)
    if not session or event ~= hs.application.watcher.terminated then return end
    local kept, before = {}, 0
    for i, app in ipairs(session.apps) do
        if app:isRunning() then
            kept[#kept + 1] = app
            if i < session.appIndex then before = before + 1 end
        end
    end
    if #kept == #session.apps then return end
    if #kept == 0 then return close() end
    local selectedAlive = session.apps[session.appIndex]:isRunning()
    session.apps = kept
    anchorMouse()
    if selectedAlive then
        session.appIndex = before + 1
        return draw()
    end
    selectApp(math.min(before + 1, #kept))
end

local function windowsChanged(win, _, event)
    if event == hs.window.filter.windowDestroyed then
        local id = win and win:id()
        if id then previews.forget(id) end
    end
    if not session or not session.column then return end
    anchorMouse()
    refreshColumn()
    draw()
end

function M.app() step("app") end
function M.window() step("window") end

function M.whileOpen(fn)
    return function(...)
        if session then return fn(...) end
    end
end

function M.unlessActive(fn)
    return function(...)
        if not session then return fn(...) end
    end
end

function M.arm()
    armed = true
end

function M.commit()
    armed = false
    if not session then return end
    local app, entry = session.apps[session.appIndex], selectedEntry()
    close()
    committedAt = now()
    focus(app, entry)
end

local actions = {
    cancel = { press = close },
    quit = { press = quitApp },
    close = { press = closeWindow },
    left = { press = function() moveApp(-1) end, repeats = true },
    right = { press = function() moveApp(1) end, repeats = true },
    up = { press = function() moveWindow(-1) end, repeats = true },
    down = { press = function() moveWindow(1) end, repeats = true },
}

local function bindKeys()
    keysModal = hs.hotkey.modal.new()
    for role, keys in pairs(config.keys) do
        local action = actions[role]
        if not action then error(("app-switcher: unknown key role %q"):format(role), 0) end
        local mods, code = chord.hotkey(keys)
        local function press()
            if session then interact(action.press) end
        end
        keysModal:bind(mods, code, press, nil, action.repeats and press or nil)
    end
end

function M.start(settings)
    config = settings
    focusFilter = hs.window.filter.new():setDefaultFilter({})
    focusFilter:subscribe({
        [hs.window.filter.windowCreated] = windowsChanged,
        [hs.window.filter.windowDestroyed] = windowsChanged,
    })
    bindKeys()
    local types = hs.eventtap.event.types
    clickTap = hs.eventtap.new({ types.leftMouseDown, types.rightMouseDown }, clickOutside)
    appWatcher = hs.application.watcher.new(dropTerminated):start()
    return M
end

function M.stop()
    expire()
    if appWatcher then appWatcher:stop() end
    if clickTap then clickTap:stop() end
    if keysModal then keysModal:delete() end
    if focusFilter then focusFilter:unsubscribeAll() end
    appWatcher, clickTap, keysModal, focusFilter = nil, nil, nil, nil
end

return M
