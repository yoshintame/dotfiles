local M = {}

local MESSAGES_DIR = (os.getenv("HOME") or "") .. "/Library/Messages/"
local DB_PATH = MESSAGES_DIR .. "chat.db"
local APPLE_EPOCH = 978307200
local MAX_AGE = 300
local DEBOUNCE = 0.3

local KEYWORDS = {
    "code", "otp", "passcode", "password", "pin", "verification",
    "код", "Код", "КОД", "пароль", "Пароль",
    "รหัส",
}

local UNITS = { "baht", "บาท", "บ.", "thb", "฿", "руб", "р.", "₽", "бонус", "%", "gb", "гб", "mb", "мб", ".-" }

local function isDigit(ch)
    return ch ~= "" and ch:match("%d") ~= nil
end

local function attachedToNumber(text, s, e)
    local before, after = text:sub(s - 1, s - 1), text:sub(e, e)
    if before:match("[%a%*%+#%$/&%?_]") or after:match("[%a%*/=&_]") then return true end
    if before:match("[%.,%-]") and isDigit(text:sub(s - 2, s - 2)) then return true end
    if after:match("[%.,%-]") and isDigit(text:sub(e + 1, e + 1)) then return true end
    return false
end

local function isQuantity(lower, s, e)
    if lower:sub(math.max(1, s - 12), s - 1):find("ref", 1, true) then return true end
    local tail = lower:match("^%s*(.*)", e)
    for _, unit in ipairs(UNITS) do
        if tail:sub(1, #unit) == unit then return true end
    end
    return false
end

local function wordStart(text, s)
    if text:byte(s) == 0xE0 then return true end
    return s == 1 or not text:sub(s - 1, s - 1):match("[%w\128-\255]")
end

local function keywordSpans(text)
    local lower = text:lower()
    local spans = {}
    for _, word in ipairs(KEYWORDS) do
        local init = 1
        while true do
            local s, e = lower:find(word, init, true)
            if not s then
                s, e = text:find(word, init, true)
            end
            if not s then break end
            if wordStart(text, s) then spans[#spans + 1] = { s, e } end
            init = e + 1
        end
    end
    return spans
end

function M.extract(text)
    if not text or text == "" then return nil end
    local spans = keywordSpans(text)
    if #spans == 0 then return nil end
    local lower = text:lower()
    local best, bestDistance
    for s, digits, e in text:gmatch("()(%d+)()") do
        if #digits >= 4 and #digits <= 8 and not attachedToNumber(text, s, e)
            and not isQuantity(lower, s, e) then
            for _, span in ipairs(spans) do
                local distance = math.max(span[1] - e, s - span[2], 0)
                if not bestDistance or distance < bestDistance then
                    best, bestDistance = digits, distance
                end
            end
        end
    end
    return best
end

function M.decodeAttributedBody(blob)
    if not blob then return nil end
    local i = blob:find("NSString", 1, true)
    if not i then return nil end
    local p = i + #"NSString" + 5
    local length = blob:byte(p)
    if not length then return nil end
    p = p + 1
    if length == 0x81 then
        length = string.unpack("<I2", blob, p)
        p = p + 2
    elseif length == 0x82 then
        length = string.unpack("<I4", blob, p)
        p = p + 4
    end
    return blob:sub(p, p + length - 1)
end

local lastRowId
local warned = false
local watcher
local check

local function warnOnce(message)
    if warned then return end
    warned = true
    hs.notify.new({ title = "SMS OTP", informativeText = message }):send()
end

local function query(sql)
    local db, _, err = hs.sqlite3.open(DB_PATH, hs.sqlite3.OPEN_READONLY)
    if not db then return nil, err end
    local rows = {}
    local ok, failure = pcall(function()
        for row in db:nrows(sql) do rows[#rows + 1] = row end
    end)
    local message = db:errmsg()
    db:close()
    if not ok then return nil, message ~= "not an error" and message or failure end
    return rows
end

local function initRowId()
    local rows, err = query("SELECT MAX(ROWID) AS id FROM message")
    if not rows then
        warnOnce("Нет доступа к chat.db — выдай Hammerspoon Full Disk Access (" .. tostring(err) .. ")")
        return false
    end
    lastRowId = tonumber(rows[1] and rows[1].id) or 0
    return true
end

local function sentAt(date)
    date = tonumber(date) or 0
    if date > 1e12 then date = date / 1e9 end
    return date + APPLE_EPOCH
end

local function deliver(code, sender, text)
    hs.pasteboard.setContents(code)
    hs.notify.new({
        title = "Код " .. code .. " скопирован",
        subTitle = sender,
        informativeText = text,
        withdrawAfter = 30,
    }):send()
end

local function scan()
    if not lastRowId and not initRowId() then return end
    local rows, err = query(string.format([[
        SELECT m.ROWID AS id, m.date AS date, m.text AS text,
               m.attributedBody AS body, h.id AS sender
        FROM message m LEFT JOIN handle h ON h.ROWID = m.handle_id
        WHERE m.ROWID > %d AND m.is_from_me = 0
        ORDER BY m.ROWID
    ]], lastRowId))
    if not rows then
        warnOnce("Не читается chat.db: " .. tostring(err))
        return
    end
    local now = os.time()
    for _, row in ipairs(rows) do
        lastRowId = math.max(lastRowId, tonumber(row.id))
        if now - sentAt(row.date) <= MAX_AGE then
            local text = row.text
            if not text or text == "" then text = M.decodeAttributedBody(row.body) end
            local code = M.extract(text)
            if code then deliver(code, row.sender or "", text) end
        end
    end
end

function M.start()
    check = hs.timer.delayed.new(DEBOUNCE, scan)
    watcher = hs.pathwatcher.new(MESSAGES_DIR, function() check:start() end):start()
    initRowId()
    return M
end

return M
