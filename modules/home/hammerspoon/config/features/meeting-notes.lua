local bin = require("core.bin")
local sys = require("core.sys")

local M = {}

local config = {
  scriptsDir = os.getenv("HOME") .. "/Documents/obsidian/yoshintame/_scripts",
  scriptPath = nil,
  autoOpenAfterMeeting = true,
  hintTtl = 150,
}

local pendingHint = nil
local currentMeeting = nil
local outcomeChooser = nil

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function runScript(args, onDone)
  local full = { config.scriptPath }
  for _, a in ipairs(args) do table.insert(full, a) end
  sys.run(bin.bun, full, { cwd = config.scriptsDir, onExit = onDone })
end

local function openNote(path)
  if not path or path == "" then return end
  sys.open("obsidian://open?path=" .. hs.http.encodeForQuery(path))
end

function M.expectMeeting(mtype)
  pendingHint = { type = mtype, at = hs.timer.secondsSinceEpoch() }
end

local function consumeHint()
  local mtype = "ad-hoc"
  if pendingHint and (hs.timer.secondsSinceEpoch() - pendingHint.at) <= config.hintTtl then
    mtype = pendingHint.type
  end
  pendingHint = nil
  return mtype
end

function M.onMeetingStart()
  local mtype = consumeHint()
  runScript({ "create", "--type", mtype }, function(code, out, err)
    if code == 0 then
      local path = trim(out)
      currentMeeting = { path = path }
      hs.alert.show("📝 " .. (path:match("([^/]+)%.md$") or "заметка митинга создана"))
    else
      hs.alert.show("⚠️ meeting-note create failed")
      print("[meeting-notes] create error: " .. err)
    end
  end)
end

function M.onMeetingEnd()
  local meeting = currentMeeting
  currentMeeting = nil
  if not meeting then return end

  local function finish(status)
    runScript({ "set-status", meeting.path, status }, function(code, _, err)
      if code ~= 0 then print("[meeting-notes] set-status error: " .. err) end
    end)
    if config.autoOpenAfterMeeting then openNote(meeting.path) end
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
  config.scriptPath = config.scriptPath or (config.scriptsDir .. "/meeting-note.ts")
  return M
end

return M
