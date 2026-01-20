hs.loadSpoon("AppLauncher")
spoon.AppLauncher:bindHotkeys({
    ["1password"]          = { { "alt"                  }, "1", keyboardLayout = "ABC" },

    ["Telegram"]           = { { "alt"                  }, "Q" },
    ["Warp"]               = { { "alt"                  }, "W", keyboardLayout = "ABC" },
    ["Kitty"]              = { { "alt", "shift"         }, "W", keyboardLayout = "ABC" },
    ["Tana"]               = { { "alt"                  }, "E" },
    ["Finder"]             = { { "alt", "shift"         }, "E", keyboardLayout = "ABC" },

    ["Arc"]                = { { "alt"                  }, "A" },
    ["ChatGPT"]            = { { "alt", "shift"         }, "A" },
    ["Spotify"]            = { { "alt"                  }, "S" },
    ["Spark Mail"]         = { { "alt", "shift"         }, "S" },
    ["Cursor"]             = { { "alt"                  }, "D" },
    ["Jira"]               = { { "alt", "shift"         }, "D" },

    ["Figma"]              = { { "alt"                  }, "Z" },
    ["Insomnia"]           = { { "alt"                  }, "X" },
    ["Discord"]            = { { "alt"                  }, "C" },
    ["Activity Monitor"]   = { { { "alt"                }, "V" },
                               { { "alt"                }, "escape" },
                               { { "shift", "ctrl"      }, "escape" } },

    ["System Settings"]    = { { "alt"                  }, "," },
})

hs.loadSpoon("LeaderFlow")

local shortcut = spoon.LeaderFlow.actions.shortcut
local text = spoon.LeaderFlow.actions.text
local currentDate = spoon.LeaderFlow.actions.currentDate
local url = spoon.LeaderFlow.actions.openURL
local raycast = spoon.LeaderFlow.actions.raycast
local code = spoon.LeaderFlow.actions.code
local launch = spoon.LeaderFlow.actions.launch
local reload = spoon.LeaderFlow.actions.reload

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
        { "p", "Passwords", shortcut("cmd shift space") },
        { "t", "Translator", raycast("raycast://extensions/isfeng/easydict/easydict?arguments=%7B%22queryText%22%3A%22%22%7D") },

        { "u", "[utils]", {
            { "c", "Color Picker", shortcut("cmd alt ctrl p") },
            { "r", "Roulette", shortcut("cmd alt ctrl o") },
            { "e", "Emojis", raycast("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols") },
        }},

        { "l", "[links]", {
            { "g", "github.com/yoshintame", url("https://github.com/yoshintame") },
            { "y", "youtube.com", url("https://youtube.com") },
            { "m", "google.com/maps", url("https://www.google.com/maps") },
        }},

        { "r", "[ru snippets]", {
            { "f", "Full Name", text("Иванов Михаил Андреевич") },
            { "n", "First Name", text("Михаил") },
            { "l", "Last Name", text("Иванов") },
            { "i", "Name with initials", text("Иванов М.А.") },
            { "p", "Phone", text("79162999311") },
        }},

        { "e", "[snippets]", {
            { "f", "Full Name", text("Mikhail Ivanov Andreevich") },
            { "n", "First Name", text("Mikhail") },
            { "l", "Last Name", text("Ivanov") },
            { "i", "Name with initials", text("Ivanov M.A.") },
            { "u", "Username", text("yoshintame") },
            { "p", "Phone", text("79162999311") },
            { "s", "Intr. Passport", text("770867661") },
            { "d", "Birthday", text("24.08.2001") },
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

            { "o", "Open Project", {
                { "c", "CRM", code("~/Development/work/senat-exchange/crm-frontend") },
                { "d", "dotfiles", code("~/.dotfiles") },
                { "k", "karabiner", code("~/.dotfiles/modules/karabiner/config") },
                { "h", "hammerspoon", code("~/.dotfiles/modules/hammerspoon/config") },
                { "f", "fish", code("~/.dotfiles/modules/fish/config") },
                { "v", "vscode", code("~/.dotfiles/modules/vscode/config") },
            } },
        }},

        { "s", "[screenshots]", {
            { "s", "Area", shortcut("cmd shift 2") },
            { "w", "Window", shortcut("cmd shift 3") },
            { "f", "Fullscreen", shortcut("cmd shift 1") },
            { "c", "Text (OCR)", shortcut("cmd shift 4") },
            { "r", "Record", shortcut("cmd shift 5") },
            { "l", "Scroll", shortcut("cmd shift 6") },
        }},

        { "a", "[AI]", {
            { "a", "Overlay", shortcut("alt space") },
            { "g", "ChatGPT", launch("ChatGPT") },
        }},

        { "h", "[hammerspoon]", {
            { "r", "reload", reload() },
        }},
    }
})


