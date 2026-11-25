local apps = require("actions.apps")
local input = require("actions.input")
local maintenance = require("actions.maintenance")
local network = require("actions.network")
local open = require("actions.open")
local power = require("actions.power")
local coffee = require("features.coffee-lid")
local hyperSetup = require("features.hyper-setup")
local meeting = require("features.meeting")
local raycastNav = require("features.raycast-nav")
local proxy = require("generated.proxy-bindings")
local fromPrivate = require("actions.private").value

local shortcut = input.shortcut
local text = input.text
local date = input.date
local unixTime = input.unixTime
local url = open.url
local raycast = open.raycast
local changeCase = open.changeCase
local editor = open.editor("/opt/homebrew/bin/zed")
local launch = open.launch

local AEROSPACE = "bobko.aerospace"
local RAYCAST = "com.raycast.macos"
local CLEANSHOT = "com.getcleanshot.app-setapp"
local COLOR_PICKER = "io.sipapp.Sip-setapp"

return {
    trigger = "f18",
    escape = { "escape" },
    abortOnMouseClick = true,
    columns = 3,
    style = {
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
    },

    tree = {
        { "t", "[text]",        {
            { "t", "Translator", raycast("extensions/isfeng/easydict/easydict", { arguments = { queryText = "" } }) },
        }},

        { "c", "Case",          {
            { "k", "Kebab",    changeCase("Kebab") },
            { "s", "Snake",    changeCase("Snake") },
            { "c", "Camel",    changeCase("Camel") },
            { "u", "Upper",    changeCase("Upper") },
            { "l", "Lower",    changeCase("Lower") },
            { "o", "Constant", changeCase("Constant") },
        }},

        { "p", "Passwords",     shortcut(proxy.passwords) },

        { "m", "[model]",       {
            { "m", "Opus 5.5 1M", text("/model claude-opus-5-5[1m]") },
            { "o", "Opus 5",      text("/model claude-opus-5") },
            { "f", "Fable 5",     text("/model claude-fable-5") },
            { "s", "Sonnet 5",    text("/model claude-sonnet-5") },
            { "h", "Haiku 4.5",   text("/model claude-haiku-4-5") },
        }},

        { "u", "[utils]",       {
            { "m", "Menu Bar Picker",   shortcut(proxy.ice_menu_item_picker) },
            { "c", "Color Picker",      shortcut(proxy.color_picker) },
            { "r", "Roulette",          shortcut(proxy.roulette) },
            { "x", "Roulette Clear",    shortcut(proxy.roulette_clear) },
            { "e", "Emojis",            raycast("extensions/raycast/emoji-symbols/search-emoji-symbols") },
            { "k", "Kill Process",      raycast("extensions/rolandleth/kill-process/index") },
            { "h", "Hyper Setup ⇄",     hyperSetup.toggle },
            { "l", "keySwitcher log ⇄", maintenance.toggleKeySwitcherLog },
            { "w", "Phone Hotspot",     network.joinHotspot("lasthaze-phone") },
        }},

        { "l", "[links]",       {
            { "g", "github.com/yoshintame", url("https://github.com/yoshintame") },
            { "s", "senate-exchange repos", url("https://github.com/orgs/senate-exchange/repositories") },
            { "y", "youtube.com",           url("https://youtube.com") },
            { "m", "google.com/maps",       url("https://www.google.com/maps") },
            { "d", "Senate daily",          fromPrivate("zoomSenateDaily", meeting.join("daily")) },
            { "w", "Senate weekly",         fromPrivate("zoomSenateWeekly", meeting.join("weekly")) },
            { "h", "Homelab Services",      raycast("extensions/yoshintame/raycast-homelab/list") },
            { "l", "[localhost]",           {
                { "c", "CRM",     url("http://localhost:4003") },
                { "t", "TG-Mini", url("http://localhost:8004") },
                { "4", "404",     url("http://localhost:4040") },
            }},
        }},

        { "v", "[meeting]",     {
            { "o", "Open current note", meeting.openCurrent },
            { "r", "Mark re-listen",    meeting.markRelisten },
        }},

        { "r", "[ru snippets]", {
            { "f", "Full Name",          text("Иванов Михаил Андреевич") },
            { "n", "First Name",         text("Михаил") },
            { "l", "Last Name",          text("Иванов") },
            { "i", "Name with initials", text("Иванов М.А.") },
            { "p", "Phone",              fromPrivate("phoneRu", text) },
        }},

        { "e", "[snippets]",    {
            { "f", "Full Name",          text("Mikhail Ivanov Andreevich") },
            { "n", "First Name",         text("Mikhail") },
            { "l", "Last Name",          text("Ivanov") },
            { "i", "Name with initials", text("Ivanov M.A.") },
            { "u", "Username",           text("yoshintame") },
            { "p", "Phone",              fromPrivate("phone", text) },
            { "s", "Intr. Passport",     fromPrivate("passport", text) },
            { "b", "Birthday",           fromPrivate("birthday", text) },
            { "a", "Address",            fromPrivate("address", text) },

            { "d", "[dates]",            {
                { "d", "ISO date",       date("%Y-%m-%d") },
                { "s", "ISO datetime",   date("%Y-%m-%dT%H:%M:%S") },
                { "i", "ISO dt (space)", date("%Y-%m-%d %H:%M:%S") },
                { "f", "Filename-safe",  date("%Y-%m-%d_%H-%M-%S") },
                { "r", "RU dotted",      date("%d.%m.%Y") },
                { "u", "US slash",       date("%m/%d/%Y") },
                { "l", "Long",           date("%e %B %Y") },
                { "w", "ISO week",       date("%G-W%V") },
                { "t", "Time",           date("%H:%M") },
                { "T", "Time w/ sec",    date("%H:%M:%S") },
                { "n", "Unix timestamp", unixTime() },
                { "h", "Short human",    date("%e %b %Y") },
            }},

            { "k", "[keys]",             {
                { "s",     "⇧",  text("⇧") },
                { "c",     "⌃",  text("⌃") },
                { "o",     "⌥",  text("⌥") },
                { "m",     "⌘",  text("⌘") },
                { "f",     "fn", text("fn") },
                { "l",     "⇪",  text("⇪") },
                { "left",  "←",  text("←") },
                { "right", "→",  text("→") },
                { "up",    "↑",  text("↑") },
                { "down",  "↓",  text("↓") },
                { "e",     "⎋",  text("⎋") },
            }},

            { "m", "[emails]",           {
                { "m", "Main",  text("m.ivanov0427@gmail.com") },
                { "u", "Ursus", fromPrivate("emailUrsus", text) },
                { "v", "Vbirf", fromPrivate("emailVbirf", text) },
            }},
        }},

        { "f", "Downloads Nav", raycastNav.openDownloads },

        { "d", "[development]", {
            { "g", "Git Repos",           raycast("extensions/moored/git-repos/list") },
            { "d", "VSCode Windows",      raycast("extensions/yoshintame/raycast-app-switcher/app-windows-by-id", { arguments = { appIdentifier = "com.microsoft.VSCode" } }) },

            { "c", "CRM",                 editor("~/Development/work/senate/senate@crm-frontend") },
            { "f", "dotfiles",            editor("~/.dotfiles") },
            { "k", "karabiner",           editor("~/Development/yoshintame/karabiner-config") },
            { "h", "hammerspoon",         editor("~/.dotfiles/modules/home/hammerspoon/config") },
            { "v", "vscode",              editor("~/.dotfiles/modules/home/vscode/config") },
            { "s", "obsidian/yoshintame", editor("~/Documents/obsidian/yoshintame") },
        }},

        { "s", "[screenshots]", {
            { "s", "Area",       shortcut(proxy.screenshot_area) },
            { "w", "Window",     shortcut(proxy.screenshot_window) },
            { "f", "Fullscreen", shortcut(proxy.screenshot_full) },
            { "o", "Text (OCR)", shortcut(proxy.screenshot_ocr) },
            { "r", "Video",      shortcut(proxy.screenshot_video) },
            { "l", "Scroll",     shortcut(proxy.screenshot_scroll) },
            { "h", "History",    shortcut(proxy.screenshot_history) },
        }},

        { "a", "[AI]",          {
            { "a", "Fix",              shortcut(proxy.fix) },
            { "g", "ChatGPT",          launch("ChatGPT") },
            { "s", "Claude Spotlight", shortcut(proxy.claude_spotlight) },
        }},

        { "q", "[quit app]",    {
            { "q", "Hard Close (kill)", apps.killFront },
            { "d", "Force Quit dialog", shortcut("cmd alt escape") },
            { "r", "Hard Reopen",       apps.reopenFront },
        }},

        { "o", "[power]",       {
            { "r", "Restart",       power.restart },
            { "R", "Hard Restart",  power.hardRestart },
            { "s", "Shutdown",      power.shutdown },
            { "S", "Hard Shutdown", power.hardShutdown },
            { "o", "Log Out",       power.logout },
            { "l", "Lock",          power.lock },
            { "z", "Sleep",         power.sleep },
        }},

        { "w", "[awake]",       {
            { "w", "Toggle",  coffee.toggle },
            { "1", "1 hour",  coffee.awakeFor(1) },
            { "2", "2 hours", coffee.awakeFor(2) },
            { "4", "4 hours", coffee.awakeFor(4) },
            { "8", "8 hours", coffee.awakeFor(8) },
        }},

        { "k", "[restart]",     {
            { "k", "Karabiner",         maintenance.kickstartKarabiner },
            { "s", "AeroSpace",         apps.restart(AEROSPACE) },
            { "r", "Raycast",           apps.restart(RAYCAST) },
            { "c", "CleanShot X",       apps.restart(CLEANSHOT) },
            { "p", "Color Picker",      apps.restart(COLOR_PICKER) },
            { "e", "Paseo daemon",      maintenance.restartPaseoDaemon },
            { "h", "Hammerspoon",       maintenance.reload },
            { "a", "All",               maintenance.restartStack({ AEROSPACE, RAYCAST, CLEANSHOT, COLOR_PICKER }) },
            { "d", "Reset CC Sessions", maintenance.resetClaudeSessions },
        }},

        { "h", "[hammerspoon]", {
            { "r", "reload", maintenance.reload },
        }},
    }
}
