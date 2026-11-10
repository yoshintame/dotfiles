local obj = {}
obj.__index = obj

obj.name = "SmsOtp"
obj.version = "0.1"
obj.author = "Mikhail Ivanov <m.ivanov0427@gmail.com>"

obj.dbPath = (os.getenv("HOME") or "") .. "/Library/Messages/chat.db"
obj.pollInterval = 1.5
obj.maxAge = 300
obj.clearAfter = 90
obj.busyTimeoutMs = 200

local APPLE_EPOCH = 978307200
local CONCEALED = "org.nspasteboard.ConcealedType"
local TRANSIENT = "org.nspasteboard.TransientType"

local otp = dofile(hs.spoons.resourcePath("otp-extract.lua"))

local function appleNanoseconds(unixSeconds)
    return math.floor((unixSeconds - APPLE_EPOCH) * 1e9)
end

function obj:init()
    self.code = otp.new(hs.json.read(hs.spoons.resourcePath("rules.json")))
    self.warned = {}
end

function obj:warn(kind, message)
    if self.warned[kind] then return end
    self.warned[kind] = true
    hs.notify.new({ title = "SMS OTP", informativeText = message }):send()
end

function obj:query(sql)
    local db, _, err = hs.sqlite3.open(self.dbPath, hs.sqlite3.OPEN_READONLY)
    if not db then return nil, err end
    db:busy_timeout(self.busyTimeoutMs)
    local rows = {}
    local ok, failure = pcall(function()
        for row in db:nrows(sql) do rows[#rows + 1] = row end
    end)
    db:close()
    if not ok then return nil, failure end
    return rows
end

function obj:initCursor()
    local rows, err = self:query(string.format(
        "SELECT COALESCE(MAX(ROWID), 0) AS id FROM message WHERE date < %d",
        appleNanoseconds(self.startedAt)))
    if not rows then
        self:warn("access", "Нет доступа к chat.db — выдай Hammerspoon Full Disk Access (" .. tostring(err) .. ")")
        return false
    end
    self.lastRowId = tonumber(rows[1].id)
    return true
end

function obj:copyConcealed(code)
    hs.pasteboard.writeAllData({
        ["public.utf8-plain-text"] = code,
        [CONCEALED] = "",
        [TRANSIENT] = "",
    })
    local written = hs.pasteboard.changeCount()
    if self.clearTimer then self.clearTimer:stop() end
    self.clearTimer = hs.timer.doAfter(self.clearAfter, function()
        if hs.pasteboard.changeCount() == written then hs.pasteboard.clearContents() end
    end)
end

function obj:deliver(code, sender)
    self:copyConcealed(code)
    hs.notify.new({
        title = "Код " .. code .. " скопирован",
        subTitle = sender,
        withdrawAfter = 30,
    }):send()
end

function obj:scan()
    if not self.lastRowId and not self:initCursor() then return end
    local rows, err = self:query(string.format([[
        SELECT m.ROWID AS id, m.date AS date, m.text AS text,
               m.attributedBody AS body, h.id AS sender
        FROM message m LEFT JOIN handle h ON h.ROWID = m.handle_id
        WHERE m.ROWID > %d AND m.is_from_me = 0
          AND m.associated_message_type = 0 AND m.item_type = 0
          AND m.cache_roomnames IS NULL
        ORDER BY m.ROWID
    ]], self.lastRowId))
    if not rows then
        self:warn("read", "Не читается chat.db: " .. tostring(err))
        return
    end
    self.warned = {}
    local freshSince = appleNanoseconds(os.time() - self.maxAge)
    for _, row in ipairs(rows) do
        if (tonumber(row.date) or 0) >= freshSince then
            local text = row.text
            if not text or text == "" then text = otp.decodeAttributedBody(row.body) end
            local code = self.code(text)
            if code then self:deliver(code, row.sender) end
        end
        self.lastRowId = tonumber(row.id)
    end
end

function obj:start()
    self.startedAt = os.time()
    self.lastRowId = nil
    self:initCursor()
    if self.poller then self.poller:stop() end
    self.poller = hs.timer.doEvery(self.pollInterval, function() self:scan() end)
    return self
end

function obj:stop()
    if self.poller then self.poller:stop() end
    self.poller = nil
    return self
end

return obj
