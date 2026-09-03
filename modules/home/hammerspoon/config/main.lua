hs.loadSpoon("AppLauncher")
spoon.AppLauncher:bindHotkeys({
    ["1password"]          = { { "alt"                  }, "1", keyboardLayout = "ABC" },

    ["Telegram"]           = { { "alt"                  }, "Q" },
    ["Warp"]               = { { "alt"                  }, "W", keyboardLayout = "ABC" },
    ["yazi"]               = { { "alt"                  }, "R", isWarp = true, keyboardLayout = "ABC" },
    ["btop"]               = { { "alt"                  }, "B", isWarp = true, keyboardLayout = "ABC" },
    ["Kitty"]              = { { "alt", "shift"         }, "W", keyboardLayout = "ABC" },
    ["Finder"]             = { { "alt", "shift"         }, "E", keyboardLayout = "ABC" },

    ["Arc"]                = { { "alt"                  }, "A" },
    ["Spotify"]            = { { "alt"                  }, "S" },
    ["Spark Mail"]         = { { "alt", "shift"         }, "S" },
    ["Visual Studio Code"] = { { "alt"                  }, "D" },
    ["Jira"]               = { { "alt", "shift"         }, "D" },

    ["TickTick"]           = { { "alt"                  }, "T" },
    ["Claude"]             = { { "alt"                  }, "Z" },
    ["yaak"]               = { { "alt"                  }, "X" },
    ["Discord"]            = { { "alt"                  }, "C" },
    ["Activity Monitor"]   = { { { "alt"                }, "V" },
                               { { "alt"                }, "escape" },
                               { { "shift", "ctrl"      }, "escape" } },

    ["System Settings"]    = { { "alt"                  }, "," },
})

local hyperSetup = false
local tabHeld = false
local hyperTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(e)
    local tabCode = hs.keycodes.map["tab"]
    local eventType = e:getType()

    if e:getKeyCode() == tabCode then
        tabHeld = (eventType == hs.eventtap.event.types.keyDown)
        return true
    end

    if tabHeld and eventType == hs.eventtap.event.types.keyDown then
        e:setFlags({ cmd = true, alt = true, ctrl = true, shift = true })
    end
    return false
end)

local function toggleHyperSetup()
    hyperSetup = not hyperSetup
    if hyperSetup then
        hyperTap:start()
        hs.alert.show("Hyper Setup ON — Tab = ⌃⌥⇧⌘")
    else
        hyperTap:stop()
        hs.alert.show("Hyper Setup OFF")
    end
end

hs.loadSpoon("LeaderFlow")

local proxy = require("generated.proxy-bindings")
local shortcut = spoon.LeaderFlow.actions.shortcut
local text = spoon.LeaderFlow.actions.text
local currentDate = spoon.LeaderFlow.actions.currentDate
local date = spoon.LeaderFlow.actions.date
local url = spoon.LeaderFlow.actions.openURL
local raycast = spoon.LeaderFlow.actions.raycast
local code = spoon.LeaderFlow.actions.code
local launch = spoon.LeaderFlow.actions.launch
local reload = spoon.LeaderFlow.actions.reload

local function dotmod(name) return code("~/.dotfiles/modules/home/" .. name .. "/config") end

local function hardCloseFront()
    local app = hs.application.frontmostApplication()
    if app then app:kill9() end
end

local function hardReopenFront()
    local app = hs.application.frontmostApplication()
    if not app then return end
    local bundleID = app:bundleID()
    app:kill9()
    if bundleID then
        hs.timer.doAfter(0.8, function()
            hs.application.launchOrFocusByBundleID(bundleID)
        end)
    end
end

local restartUid = (hs.execute("id -u") or "501"):gsub("%s+", "")

local function killAndReopen(bundleID)
    local app = hs.application.get(bundleID)
    if app then app:kill9() end
    hs.timer.doAfter(0.8, function()
        hs.application.launchOrFocusByBundleID(bundleID)
    end)
end

local function restartApp(bundleID)
    return function() killAndReopen(bundleID) end
end

local function karabinerKickstartTask()
    hs.task.new("/bin/launchctl", nil,
        { "kickstart", "-k", "gui/" .. restartUid .. "/org.pqrs.service.agent.karabiner_console_user_server" }):start()
end

local function kickstartKarabiner()
    karabinerKickstartTask()
    hs.alert.show("⌨︎ Karabiner console_user_server kickstarted")
end

local restartStack = {
    "bobko.aerospace",
    "com.raycast.macos",
    "com.getcleanshot.app-setapp",
    "io.sipapp.Sip-setapp",
}

local function restartAll()
    karabinerKickstartTask()
    for i, bundleID in ipairs(restartStack) do
        hs.timer.doAfter((i - 1) * 0.15, function()
            killAndReopen(bundleID)
        end)
    end
    hs.alert.show("♻︎ Restarting tool stack…")
end

local function resetClaudeSessions()
    local home = os.getenv("HOME")
    local bun = home .. "/.local/share/mise/shims/bun"
    local script = home .. "/.claude/skills/reset-sessions/scripts/reset-sessions.ts"
    hs.alert.show("♻︎ Resetting Claude Code sessions…")
    local task = hs.task.new(bun, function(exitCode, stdOut)
        local summary = stdOut and (stdOut:match("Убито:[^\n]*") or stdOut:match("Нечего убивать[^\n]*"))
        if exitCode == 0 and summary then
            hs.alert.show("✅ " .. summary)
        elseif exitCode == 0 then
            hs.alert.show("✅ Claude Code sessions reset")
        else
            hs.alert.show("⚠️ reset-sessions failed (exit " .. tostring(exitCode) .. ")")
        end
    end, { script, "--all" })
    task:setEnvironment({ HOME = home, PATH = "/usr/bin:/bin:/usr/sbin:/sbin" })
    task:start()
end

local function osa(script)
    return function() hs.osascript.applescript(script) end
end

local function osaAdmin(shellCommand)
    return function()
        hs.task.new("/usr/bin/osascript", nil,
            { "-e", 'do shell script "' .. shellCommand .. '" with administrator privileges' }):start()
    end
end

local meetingNotes = require("meeting-notes").setup({ autoOpenAfterMeeting = true })

local function joinMeeting(zoomUrl, mtype)
    return function()
        meetingNotes.expectMeeting(mtype)
        hs.task.new("/usr/bin/open", nil, { zoomUrl }):start()
    end
end

hs.hotkey.bind({ "alt" }, "E", raycast("raycast://extensions/yoshintame/raycast-app-switcher/app-windows-by-id?arguments=%7B%22appIdentifier%22%3A%22com.microsoft.VSCode%22%7D"))

local floatMaximizePrevFrames = {}
local function toggleFloatMaximize()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screenFrame = win:screen():frame()
    local frame = win:frame()
    local isMaximized = frame.x <= screenFrame.x + 8
        and frame.y <= screenFrame.y + 8
        and frame.w >= screenFrame.w - 16
        and frame.h >= screenFrame.h - 16
    if isMaximized then
        local prev = floatMaximizePrevFrames[win:id()]
        if prev then
            win:setFrame(prev)
        else
            local w = 420
            local h = math.min(860, screenFrame.h - 60)
            win:setFrame({
                x = screenFrame.x + (screenFrame.w - w) / 2,
                y = screenFrame.y + (screenFrame.h - h) / 2,
                w = w,
                h = h,
            })
        end
    else
        floatMaximizePrevFrames[win:id()] = frame
        win:setFrame(screenFrame)
    end
end
hs.hotkey.bind({ "alt" }, "F", toggleFloatMaximize)

local function newDraft(ext)
    local dir = os.getenv("HOME") .. "/.local/share/cc-drafts"
    hs.execute("/bin/mkdir -p '" .. dir .. "'")
    local path = dir .. "/draft-" .. os.date("%Y-%m-%d--%H-%M-%S") .. "." .. (ext or "md")
    local f = io.open(path, "w")
    if f then f:close() end
    hs.task.new("/usr/bin/open", nil, { "-a", "Visual Studio Code", path }):start()
end
hs.hotkey.bind({ "alt" }, "N", function() newDraft("md") end)

require("clipboard-history").start({
    proxy.paste_history1,
    proxy.paste_history2,
    proxy.paste_history3,
    proxy.paste_history4,
    proxy.paste_history5,
})

hs.loadSpoon("Zoom")
local meetingDndActive = false
local function setMeetingDnd(active)
    if active == meetingDndActive then return end
    meetingDndActive = active
    hs.task.new("/usr/bin/shortcuts", nil, { "run", active and "DND On" or "DND Off" }):start()
    hs.alert.show(active and "🔕 Zoom meeting → DND on" or "🔔 Meeting ended → DND off")
end
local inMeeting = false
spoon.Zoom:setStatusCallback(function()
    local now = spoon.Zoom:inMeeting()
    setMeetingDnd(now)
    if now and not inMeeting then
        meetingNotes.onMeetingStart()
    elseif inMeeting and not now then
        meetingNotes.onMeetingEnd()
    end
    inMeeting = now
end)
spoon.Zoom:start()

spoon.LeaderFlow:setup({
    leader = { mods = {}, key = "F18" },
    abortOnMouseClick = true,

    ui = {
        show = true,
        escapeKey = { { {}, "F18" }, { {}, "escape" } },
        helperEntryEachLine = 3,
        format = {
            atScreenEdge = 0,
            padding = 16,
            radius = 8,
            fillColor = { alpha = .80, hex = "0a0a0a" },
            strokeColor = { alpha = .85, hex = "89b4fa" },
            textColor = { alpha = 1, hex = "cdd6f4" },
            textStyle = {
                paragraphStyle = { lineSpacing = 6 },
                shadow = { offset = { h = -1, w = 1 }, blurRadius = 12, color = { alpha = .60, white = 0 } }
            },
            strokeWidth = 2,
            textFont = "Monaco",
            textSize = 12
        }
    },

    spec = {
        { "t", "[text]", {
            { "t", "Translator", raycast("raycast://extensions/isfeng/easydict/easydict?arguments=%7B%22queryText%22%3A%22%22%7D") },
        }},

        { "c", "Case", {
            { "k", "Kebab", raycast("raycast://extensions/erics118/change-case/change-case?context=%7B%22case%22%3A%22Kebab%20Case%22%7D") },
            { "s", "Snake", raycast("raycast://extensions/erics118/change-case/change-case?context=%7B%22case%22%3A%22Snake%20Case%22%7D") },
            { "c", "Camel", raycast("raycast://extensions/erics118/change-case/change-case?context=%7B%22case%22%3A%22Camel%20Case%22%7D") },
            { "u", "Upper", raycast("raycast://extensions/erics118/change-case/change-case?context=%7B%22case%22%3A%22Upper%20Case%22%7D") },
            { "l", "Lower", raycast("raycast://extensions/erics118/change-case/change-case?context=%7B%22case%22%3A%22Lower%20Case%22%7D") },
            { "o", "Constant", raycast("raycast://extensions/erics118/change-case/change-case?context=%7B%22case%22%3A%22Constant%20Case%22%7D") },
        }},

        { "p", "Passwords", shortcut(proxy.passwords) },

        { "m", "[model]", {
            { "m", "Opus 4.8", text("/model claude-opus-4-8") },
            { "o", "Opus 5", text("/model claude-opus-5") },
            { "f", "Fable 5", text("/model claude-fable-5") },
            { "s", "Sonnet 5", text("/model claude-sonnet-5") },
            { "h", "Haiku 4.5", text("/model claude-haiku-4-5") },
        }},

        { "u", "[utils]", {
            { "m", "Menu Bar Picker", shortcut(proxy.ice_menu_item_picker) },
            { "c", "Color Picker", shortcut(proxy.color_picker) },
            { "r", "Roulette", shortcut(proxy.roulette) },
            { "x", "Roulette Clear", shortcut(proxy.roulette_clear) },
            { "e", "Emojis", raycast("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols") },
            { "k", "Kill Process", raycast("raycast://extensions/rolandleth/kill-process/index") },
            { "h", "Hyper Setup ⇄", toggleHyperSetup },
        }},

        { "l", "[links]", {
            { "g", "github.com/yoshintame", url("https://github.com/yoshintame") },
            { "s", "senate-exchange repos", url("https://github.com/orgs/senate-exchange/repositories") },
            { "y", "youtube.com", url("https://youtube.com") },
            { "m", "google.com/maps", url("https://www.google.com/maps") },
            { "d", "Senate daily", joinMeeting("https://us06web.zoom.us/j/84129720700?pwd=Czei5trGxXmY6TfREpHfjVGiNuLGBH.1&jst=2", "daily") },
            { "w", "Senate weekly", joinMeeting("https://us06web.zoom.us/j/81435225054?pwd=6uR77sp5Oq2hvFtei463Vghub9jpY5.1&jst=2", "weekly") },
            { "l", "[localhost]", {
                    { "c", "CRM", url("http://localhost:4003") },
                    { "t", "TG-Mini", url("http://localhost:8004") },
                    { "4", "404", url("http://localhost:4040") },
                }},
        }},

        { "v", "[meeting]", {
            { "o", "Open current note", function() meetingNotes.openCurrent() end },
            { "r", "Mark re-listen", function() meetingNotes.markRelisten() end },
        }},

        { "r", "[ru snippets]", {
            { "f", "Full Name", text("Иванов Михаил Андреевич") },
            { "n", "First Name", text("Михаил") },
            { "l", "Last Name", text("Иванов") },
            { "i", "Name with initials", text("Иванов М.А.") },
            { "p", "Phone", text("79162999311") },
        }},

        { "e", "[snippets]", {
            -- tg
            { "f", "Full Name", text("Mikhail Ivanov Andreevich") },
            { "n", "First Name", text("Mikhail") },
            { "l", "Last Name", text("Ivanov") },
            { "i", "Name with initials", text("Ivanov M.A.") },
            { "u", "Username", text("yoshintame") },
            { "p", "Phone", text("0991671150") },
            { "s", "Intr. Passport", text("770867661") },
            { "b", "Birthday", text("24.08.2001") },
            { "a", "Address", text("Apt 1115, 1333 The Line Wongsawang") },

            { "d", "[dates]", {
                { "d", "ISO date",       date("%Y-%m-%d") },
                { "s", "ISO datetime",   date("%Y-%m-%dT%H:%M:%S") },
                { "i", "ISO dt (space)", date("%Y-%m-%d %H:%M:%S") },
                { "f", "Filename-safe",  date("%Y-%m-%d_%H-%M-%S") },
                { "r", "RU dotted",      date("%d.%m.%Y") },
                { "u", "US slash",       date("%m/%d/%Y") },
                { "l", "Long",           text(function() return (os.date("%e %B %Y"):gsub("^%s+", "")) end) },
                { "w", "ISO week",       date("%G-W%V") },
                { "t", "Time",           date("%H:%M") },
                { "T", "Time w/ sec",    date("%H:%M:%S") },
                { "n", "Unix timestamp", text(function() return tostring(os.time()) end) },
                { "h", "Short human",    currentDate() },
            }},

            { "k", "[keys]", {
                { "shift", "⇧", text("⇧") },
                { "ctrl", "⌃", text("⌃") },
                { "alt", "⌥", text("⌥") },
                { "cmd", "⌘", text("⌘") },
                { "fn", "fn", text("fn") },
                { "capslock", "⇪", text("⇪") },
                { "left", "←", text("←") },
                { "right", "→", text("→") },
                { "up", "↑", text("↑") },
                { "down", "↓", text("↓") },
                { "escape", "⎋", text("⎋") },
            }},

            { "m", "[emails]", {
                { "m", "Main", text("m.ivanov0427@gmail.com") },
                { "u", "Ursus", text("ursus.michael@gmail.com") },
                { "v", "Vbirf", text("vbirf2001@gmail.com") },
            }},
        }},

        { "d", "[development]", {
            { "g", "Git Repos", raycast("raycast://extensions/moored/git-repos/list") },
            { "d", "VSCode Windows", raycast("raycast://extensions/yoshintame/raycast-app-switcher/app-windows-by-id?arguments=%7B%22appIdentifier%22%3A%22com.microsoft.VSCode%22%7D") },

            { "c", "CRM", code("~/Development/work/senate/senate@crm-frontend") },
            { "f", "dotfiles", code("~/.dotfiles") },
            { "k", "karabiner", dotmod("karabiner") },
            { "h", "hammerspoon", dotmod("hammerspoon") },
            { "v", "vscode", dotmod("vscode") },
            { "s", "obsidian/yoshintame", code("~/Documents/obsidian/yoshintame") },
        }},

        { "s", "[screenshots]", {
            { "s", "Area", shortcut(proxy.screenshot_area) },
            { "w", "Window", shortcut(proxy.screenshot_window) },
            { "f", "Fullscreen", shortcut(proxy.screenshot_full) },
            { "o", "Text (OCR)", shortcut(proxy.screenshot_ocr) },
            { "r", "Video", shortcut(proxy.screenshot_video) },
            { "l", "Scroll", shortcut(proxy.screenshot_scroll) },
            { "h", "History", shortcut(proxy.screenshot_history) },
        }},

        { "a", "[AI]", {
            { "a", "Fix", shortcut(proxy.fix) },
            { "g", "ChatGPT", launch("ChatGPT") },
            { "s", "Claude Spotlight", shortcut(proxy.claude_spotlight) },
        }},

        { "q", "[quit app]", {
            { "q", "Hard Close (kill)", hardCloseFront },
            { "d", "Force Quit dialog", shortcut("cmd alt escape") },
            { "r", "Hard Reopen", hardReopenFront },
        }},

        { "Q", "[power]", {
            { "r", "Restart", osa('tell application "System Events" to restart') },
            { "R", "Hard Restart", osaAdmin("shutdown -r now") },
            { "s", "Shutdown", osa('tell application "System Events" to shut down') },
            { "S", "Hard Shutdown", osaAdmin("shutdown -h now") },
            { "o", "Log Out", osa('tell application "System Events" to log out') },
            { "l", "Lock", function() hs.caffeinate.lockScreen() end },
            { "z", "Sleep", function() hs.caffeinate.systemSleep() end },
        }},

        { "R", "[restart]", {
            { "k", "Karabiner", kickstartKarabiner },
            { "s", "AeroSpace", restartApp("bobko.aerospace") },
            { "r", "Raycast", restartApp("com.raycast.macos") },
            { "c", "CleanShot X", restartApp("com.getcleanshot.app-setapp") },
            { "p", "Color Picker", restartApp("io.sipapp.Sip-setapp") },
            { "h", "Hammerspoon", reload() },
            { "a", "All", restartAll },
            { "d", "Reset CC Sessions", resetClaudeSessions },
        }},

        { "h", "[hammerspoon]", {
            { "r", "reload", reload() },
        }},
    }
})


