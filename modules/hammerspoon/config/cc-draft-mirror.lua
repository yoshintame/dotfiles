local M = {}

local VSCODE_BUNDLE = "com.microsoft.VSCode"
local INPUT_DESC = "Message input"

local function expandHome(p)
    if p:sub(1, 1) == "~" then
        return os.getenv("HOME") .. p:sub(2)
    end
    return p
end

local function ensureDir(path)
    hs.fs.mkdir(path)
end

local function armAccessibility(app)
    local axapp = hs.axuielement.applicationElement(app)
    if not axapp then return end
    pcall(function() axapp:setAttributeValue("AXManualAccessibility", true) end)
end

local function focusedInputValue(app)
    local axapp = hs.axuielement.applicationElement(app)
    if not axapp then return nil end
    local fe = axapp:attributeValue("AXFocusedUIElement")
    if not fe then
        pcall(function() axapp:setAttributeValue("AXManualAccessibility", true) end)
        return nil
    end
    if fe:attributeValue("AXRole") ~= "AXTextArea" then return nil end
    if fe:attributeValue("AXDescription") ~= INPUT_DESC then return nil end
    local v = fe:attributeValue("AXValue")
    if type(v) ~= "string" then return nil end
    return v
end

function M.start(opts)
    opts = opts or {}
    local dir = expandHome(opts.dir or "~/cc-drafts")
    local historyPath = dir .. "/history.md"
    local interval = opts.interval or 1.5
    local settleSeconds = opts.settleSeconds or 4
    local shrinkMin = opts.shrinkMin or 40
    local maxBytes = opts.maxBytes or 3 * 1024 * 1024

    ensureDir(dir)

    local pending = nil
    local pendingSince = 0
    local appendedPending = false
    local lastAppended = nil

    local function rotateIfNeeded()
        local attr = hs.fs.attributes(historyPath)
        if attr and attr.size and attr.size > maxBytes then
            os.rename(historyPath, dir .. "/history-" .. os.date("%Y%m%d-%H%M%S") .. ".md")
        end
    end

    local function appendEntry(text)
        if not text or text == "" or text == lastAppended then return end
        rotateIfNeeded()
        local f = io.open(historyPath, "a")
        if not f then return end
        f:write("## " .. os.date("%Y-%m-%d %H:%M:%S") .. "  ·  " .. #text .. " bytes\n\n")
        f:write(text)
        f:write("\n\n")
        f:close()
        lastAppended = text
    end

    local function flushPending()
        if pending and not appendedPending then
            appendEntry(pending)
        end
        pending = nil
        appendedPending = false
    end

    local running = hs.application.get(VSCODE_BUNDLE)
    if running then armAccessibility(running) end

    M._appWatcher = hs.application.watcher.new(function(_, event, appObj)
        if not appObj or appObj:bundleID() ~= VSCODE_BUNDLE then return end
        if event == hs.application.watcher.launched or event == hs.application.watcher.activated then
            armAccessibility(appObj)
        end
    end)
    M._appWatcher:start()

    M._timer = hs.timer.new(interval, function()
        local front = hs.application.frontmostApplication()
        if not front or front:bundleID() ~= VSCODE_BUNDLE then
            flushPending()
            return
        end
        local v = focusedInputValue(front)
        if v == nil then
            flushPending()
            return
        end
        local now = hs.timer.secondsSinceEpoch()
        if v ~= "" then
            if pending == nil or v ~= pending then
                if pending ~= nil and #pending >= shrinkMin
                    and (#v < #pending * 0.5 or #pending - #v >= 200) then
                    appendEntry(pending)
                end
                pending = v
                pendingSince = now
                appendedPending = false
            elseif not appendedPending and (now - pendingSince) >= settleSeconds then
                appendEntry(pending)
                appendedPending = true
            end
        else
            flushPending()
        end
    end)
    M._timer:start()

    return M
end

return M
