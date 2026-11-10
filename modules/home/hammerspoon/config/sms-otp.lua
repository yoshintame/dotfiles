local otp = require("otp-extract")

local M = {}

local DB_PATH = (os.getenv("HOME") or "") .. "/Library/Messages/chat.db"
local APPLE_EPOCH = 978307200
local MAX_AGE = 300
local POLL_INTERVAL = 1.5
local BUSY_TIMEOUT_MS = 200
local CLEAR_AFTER = 90
local CONCEALED = "org.nspasteboard.ConcealedType"
local TRANSIENT = "org.nspasteboard.TransientType"

local lastRowId
local startedAt
local warned = {}
local poller
local clearTimer

local function warn(kind, message)
    if warned[kind] then return end
    warned[kind] = true
    hs.notify.new({ title = "SMS OTP", informativeText = message }):send()
end

local function query(sql)
    local db, _, err = hs.sqlite3.open(DB_PATH, hs.sqlite3.OPEN_READONLY)
    if not db then return nil, err end
    db:busy_timeout(BUSY_TIMEOUT_MS)
    local rows = {}
    local ok, failure = pcall(function()
        for row in db:nrows(sql) do rows[#rows + 1] = row end
    end)
    db:close()
    if not ok then return nil, failure end
    return rows
end

local function appleNanoseconds(unixSeconds)
    return math.floor((unixSeconds - APPLE_EPOCH) * 1e9)
end

local function initCursor()
    local rows, err = query(string.format(
        "SELECT COALESCE(MAX(ROWID), 0) AS id FROM message WHERE date < %d",
        appleNanoseconds(startedAt)))
    if not rows then
        warn("access", "Нет доступа к chat.db — выдай Hammerspoon Full Disk Access (" .. tostring(err) .. ")")
        return false
    end
    lastRowId = tonumber(rows[1].id)
    return true
end

local function copyConcealed(code)
    hs.pasteboard.writeAllData({
        ["public.utf8-plain-text"] = code,
        [CONCEALED] = "",
        [TRANSIENT] = "",
    })
    local written = hs.pasteboard.changeCount()
    if clearTimer then clearTimer:stop() end
    clearTimer = hs.timer.doAfter(CLEAR_AFTER, function()
        if hs.pasteboard.changeCount() == written then hs.pasteboard.clearContents() end
    end)
end

local function deliver(code, sender)
    copyConcealed(code)
    hs.notify.new({
        title = "Код " .. code .. " скопирован",
        subTitle = sender,
        withdrawAfter = 30,
    }):send()
end

local function scan()
    if not lastRowId and not initCursor() then return end
    local rows, err = query(string.format([[
        SELECT m.ROWID AS id, m.date AS date, m.text AS text,
               m.attributedBody AS body, h.id AS sender
        FROM message m LEFT JOIN handle h ON h.ROWID = m.handle_id
        WHERE m.ROWID > %d AND m.is_from_me = 0
          AND m.associated_message_type = 0 AND m.item_type = 0
          AND m.cache_roomnames IS NULL
        ORDER BY m.ROWID
    ]], lastRowId))
    if not rows then
        warn("read", "Не читается chat.db: " .. tostring(err))
        return
    end
    warned = {}
    local freshSince = appleNanoseconds(os.time() - MAX_AGE)
    for _, row in ipairs(rows) do
        if (tonumber(row.date) or 0) >= freshSince then
            local text = row.text
            if not text or text == "" then text = otp.decodeAttributedBody(row.body) end
            local code = otp.code(text)
            if code then deliver(code, row.sender) end
        end
        lastRowId = tonumber(row.id)
    end
end

function M.start()
    startedAt = os.time()
    initCursor()
    poller = hs.timer.doEvery(POLL_INTERVAL, scan)
    return M
end

return M
