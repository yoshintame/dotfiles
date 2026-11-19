local bin = require("engine.bin")
local process = require("engine.process")

local M = {}

local config = nil
local pendingHint = nil
local currentMeeting = nil
local outcomeChooser = nil
local inMeeting = false

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function runScript(args, onDone)
    local full = { config.scriptsDir .. "/" .. config.script }
    for _, a in ipairs(args) do table.insert(full, a) end
    process.run(bin.bun, full, { cwd = config.scriptsDir, onExit = onDone })
end

local function openNote(path)
    if not path or path == "" then return end
    process.open("obsidian://open?path=" .. hs.http.encodeForQuery(path))
end

local function consumeHint()
    local mtype = "ad-hoc"
    if pendingHint and (hs.timer.secondsSinceEpoch() - pendingHint.at) <= config.joinHintSeconds then
        mtype = pendingHint.type
    end
    pendingHint = nil
    return mtype
end

local function onMeetingStart()
    local mtype = consumeHint()
    runScript({ "create", "--type", mtype }, function(code, out, err)
        if code == 0 then
            local path = trim(out)
            currentMeeting = { path = path }
            hs.alert.show("📝 " .. (path:match("([^/]+)%.md$") or "заметка митинга создана"))
        else
            hs.alert.show("⚠️ meeting-note create failed")
            print("[meeting] create error: " .. err)
        end
    end)
end

local function onMeetingEnd()
    local meeting = currentMeeting
    currentMeeting = nil
    if not meeting then return end

    local function finish(status)
        runScript({ "set-status", meeting.path, status }, function(code, _, err)
            if code ~= 0 then print("[meeting] set-status error: " .. err) end
        end)
        if config.openNoteAfterMeeting then openNote(meeting.path) end
    end

    outcomeChooser = hs.chooser.new(function(choice)
        outcomeChooser = nil
        finish((choice and choice.status) or "completed")
    end)
    outcomeChooser:placeholderText("Что с митингом?")
    outcomeChooser:choices({
        { text = "🔴 Важное — надо переслушать", subText = "status: needs-review", status = "needs-review" },
        { text = "✓ Ничего особенного", subText = "status: completed", status = "completed" },
    })
    outcomeChooser:rows(2)
    outcomeChooser:show()
end

function M.join(mtype)
    return function(link)
        return function()
            pendingHint = { type = mtype, at = hs.timer.secondsSinceEpoch() }
            process.open(link)
        end
    end
end

function M.openCurrent()
    if currentMeeting and currentMeeting.path then
        openNote(currentMeeting.path)
    else
        hs.alert.show("Нет активного митинга")
    end
end

function M.markRelisten()
    if not (currentMeeting and currentMeeting.path) then
        hs.alert.show("Нет активного митинга")
        return
    end
    runScript({ "set-status", currentMeeting.path, "needs-review" })
    hs.alert.show("🔴 Помечено: переслушать")
end

function M.start(settings)
    config = settings
    hs.loadSpoon("Zoom")
    spoon.Zoom:setStatusCallback(function()
        local now = spoon.Zoom:inMeeting()
        if now and not inMeeting then
            onMeetingStart()
        elseif inMeeting and not now then
            onMeetingEnd()
        end
        inMeeting = now
    end)
    spoon.Zoom:start()
    return M
end

return M
