local M = {}

local hotkey
local watcher

local SCRIPT = [[
    tell application "Finder"
        set sel to selection as alias list
        if (count of sel) = 0 then
            try
                return POSIX path of (target of front Finder window as alias)
            on error
                return POSIX path of (desktop as alias)
            end try
        end if
        set paths to {}
        repeat with f in sel
            set end of paths to POSIX path of f
        end repeat
        set AppleScript's text item delimiters to linefeed
        return paths as text
    end tell
]]

local NOT_AUTHORIZED = -1743

local function notify(title, text)
    hs.notify.new({ title = title, informativeText = text }):send()
end

local function copySelectedPath()
    local ok, paths, details = hs.osascript.applescript(SCRIPT)
    if not ok then
        if details and details.OSAScriptErrorNumberKey == NOT_AUTHORIZED then
            notify("Нет доступа к Finder", "Настройки → Конфиденциальность и безопасность → Автоматизация → Hammerspoon → Finder")
        else
            notify("Путь не скопирован", tostring(details and details.OSAScriptErrorBriefMessageKey))
        end
        return
    end
    hs.pasteboard.setContents(paths)
    local count = select(2, paths:gsub("\n", "")) + 1
    notify(count == 1 and "Путь скопирован" or ("Скопировано путей: " .. count), paths)
end

local function isFinder(app)
    return app ~= nil and app:bundleID() == "com.apple.finder"
end

function M.start()
    hotkey = hs.hotkey.new({ "cmd", "shift" }, "C", copySelectedPath)
    watcher = hs.application.watcher.new(function(_, event, app)
        if not isFinder(app) then return end
        if event == hs.application.watcher.activated then
            hotkey:enable()
        elseif event == hs.application.watcher.deactivated then
            hotkey:disable()
        end
    end)
    watcher:start()
    if isFinder(hs.application.frontmostApplication()) then hotkey:enable() end
    return M
end

return M
