local bin = require("core.bin")
local sys = require("core.sys")

local M = {}

local SCRIPTS_DIR = os.getenv("HOME") .. "/Documents/obsidian/yoshintame/_scripts"
local SCRIPT = SCRIPTS_DIR .. "/meeting-note.ts"
local AUTO_OPEN_AFTER_MEETING = true
local HINT_TTL = 150

local pendingHint = nil
local currentMeeting = nil
local outcomeChooser = nil
local inMeeting = false

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function runScript(args, onDone)
    local full = { SCRIPT }
    for _, a in ipairs(args) do table.insert(full, a) end
    sys.run(bin.bun, full, { cwd = SCRIPTS_DIR, onExit = onDone })
end

local function openNote(path)
    if not path or path == "" then return end
    sys.open("obsidian://open?path=" .. hs.http.encodeForQuery(path))
end

local function consumeHint()
    local mtype = "ad-hoc"
    if pendingHint and (hs.timer.secondsSinceEpoch() - pendingHint.at) <= HINT_TTL then
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
        if AUTO_OPEN_AFTER_MEETING then openNote(meeting.path) end
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

function M.join(link, mtype)
    return function()
        pendingHint = { type = mtype, at = hs.timer.secondsSinceEpoch() }
        sys.open(link)
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

function M.start()
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
