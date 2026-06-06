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
local url = spoon.LeaderFlow.actions.openURL
local raycast = spoon.LeaderFlow.actions.raycast
local code = spoon.LeaderFlow.actions.code
local launch = spoon.LeaderFlow.actions.launch
local reload = spoon.LeaderFlow.actions.reload

hs.hotkey.bind({ "alt" }, "E", raycast("raycast://extensions/yoshintame/raycast-app-switcher/app-windows-by-id?arguments=%7B%22appIdentifier%22%3A%22com.microsoft.VSCode%22%7D"))

require("clipboard-history").start({
    proxy.paste_history1,
    proxy.paste_history2,
    proxy.paste_history3,
    proxy.paste_history4,
    proxy.paste_history5,
})

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

        { "m", "Menu Bar Picker", shortcut(proxy.ice_menu_item_picker) },

        { "u", "[utils]", {
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
            { "l", "[localhost]", {
                    { "c", "CRM", url("http://localhost:4003") },
                    { "t", "TG-Mini", url("http://localhost:8004") },
                    { "4", "404", url("http://localhost:4040") },
                }},
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
            { "t", "Current Date", currentDate() },

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

            { "c", "CRM", code("~/Development/work/senat-exchange/crm-frontend") },
            { "f", "dotfiles", code("~/.dotfiles") },
            { "k", "karabiner", code("~/.dotfiles/modules/karabiner/config") },
            { "h", "hammerspoon", code("~/.dotfiles/modules/hammerspoon/config") },
            { "v", "vscode", code("~/.dotfiles/modules/vscode/config") },
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

        { "h", "[hammerspoon]", {
            { "r", "reload", reload() },
        }},
    }
})


