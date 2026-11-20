return {
    meeting = {
        scriptsDir = os.getenv("HOME") .. "/Documents/obsidian/yoshintame/_scripts",
        script = "meeting-note.ts",
        openNoteAfterMeeting = true,
        joinHintSeconds = 150,
    },

    ["coffee-lid"] = {
        lowBatteryPercent = 20,
        indicatorPosition = 300,
    },

    ["afk-indicator"] = {
        warnBeforeSeconds = 30,
        size = 12,
        margin = 8,
        colors = {
            warn = { red = 1, green = 0.6, blue = 0, alpha = 0.9 },
            afk = { white = 0.6, alpha = 0.7 },
        },
    },

    ["clipboard-history"] = {
        size = 9,
    },

    ["downloads-copy-path"] = {
        dir = os.getenv("HOME") .. "/Downloads",
        debounceSeconds = 0.5,
        alertSeconds = 1.5,
        ignoreSuffixes = { ".crdownload", ".download", ".part", ".partial", ".tmp", ".opdownload" },
    },

    ["app-switcher"] = {
        iconSize = 72,
        gap = 16,
        padding = 24,
        highlightInset = 8,
        radius = 18,
        labelHeight = 28,
        textSize = 15,
        maxApps = 12,
        lateStepSeconds = 0.15,
        idleCloseSeconds = 8,
        external = {
            commit = { mods = { "cmd", "alt", "shift" }, key = "f18" },
            commitDelaySeconds = 0.15,
        },
        background = { white = 0.12, alpha = 0.92 },
        highlight = { white = 1, alpha = 0.18 },
        text = { white = 1, alpha = 0.9 },
    },

    ["onepassword-focus-guard"] = {},
    ["sms-otp"] = {},
    ["hyper-setup"] = {},

    ["raycast-nav"] = {
        keys = {
            { key = "j",      mods = { "ctrl" },          toKey = "b" },
            { key = "l",      mods = { "ctrl" },          toKey = "l" },
            { key = "left",   mods = { "ctrl" },          toKey = "b" },
            { key = "right",  mods = { "ctrl" },          toKey = "l" },
            { key = "d",      mods = { "ctrl", "shift" }, toKey = "d" },
            { key = "y",      mods = { "ctrl", "shift" }, toKey = "y" },
            { key = "c",      mods = { "ctrl", "shift" }, toKey = "c" },
            { key = "v",      mods = { "ctrl", "shift" }, toKey = "v" },
            { key = "u",      mods = { "ctrl", "shift" }, toKey = "u" },
            { key = "space",  mods = { "ctrl", "shift" }, toKey = "space" },
            { key = "return", mods = { "ctrl", "shift" }, toKey = "return" },
        },
    },
}
