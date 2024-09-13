local M = {}
M.__index = M

M.name = "WindowsManager"
M.version = "0.1"
M.author = "Mikhail Ivanov <m.ivanov0427@gmail.com>"

M.log = hs.logger.new('WindowsManager')

function M:setLogLevel(level)
    M.log.setLogLevel(level)
    return self
end

function M:logWindowInfo(window)
    local frame = window:frame()
    local role = window:role()
    local subrole = window:subrole()
    local appName = window:application():name()
    local title = window:title()

    local windowInfo = string.format(
        "App Name: %s, Title: %s, Role: %s, Subrole: %s, Position: (%d, %d), Size: (%d x %d)",
        appName, title, role, subrole, frame.x, frame.y, frame.w, frame.h
    )
    self.log.i(windowInfo)
end

function M:maximizeWindow(window)
    self.log.i(window:role())
    if window:role() ~= "AXDialog" and window:subrole() ~= "AXSystemDialog" and window:subrole() ~= "AXDialog" then
        hs.grid.maximizeWindow(window)
    end
end

function M:hideAllOtherWindows(currentWindow)
    local allWindows = hs.window.allWindows()
    for _, window in ipairs(allWindows) do
        if window:id() ~= currentWindow:id() then
            window:application():hide()
        end
    end
end

function M:handleWindowEvent(window)
    if window then
        self:maximizeWindow(window)
        self:logWindowInfo(window)
        -- self:hideAllOtherWindows(window)
    end
end

function M:moveWindowToLeftHalf(window)
    if not window then return end

    hs.grid.set(window, { x = 0, y = 0, w = hs.grid.GRIDWIDTH / 2, h = hs.grid.GRIDHEIGHT })
end

function M:start()
    hs.window.animationDuration = 0
    hs.window.setShadows(false)
    hs.grid.setGrid('2x2') -- Set the grid size to 2x2 for simplicity

    self:setLogLevel("info")

    local windowFilter = hs.window.filter.new()
    windowFilter:subscribe(
        { hs.window.filter.windowCreated, hs.window.filter.windowFocused, hs.window.filter.windowMoved },
        function(window)
            local screen = window:screen()
            local spaces = hs.spaces.spacesForScreen(screen)
            local currentSpace = hs.spaces.focusedSpace()

            if currentSpace == spaces[1] then
                self:handleWindowEvent(window)
            end
        end
    )

    hs.hotkey.bind({ "alt" }, "f", function()
        local window = hs.window.focusedWindow()
        if window then
            local screen = window:screen()
            local spaces = hs.spaces.spacesForScreen(screen)
            if #spaces > 1 then
                hs.spaces.moveWindowToSpace(window:id(), spaces[2])
                hs.spaces.gotoSpace(spaces[2])
            end
            self:moveWindowToLeftHalf(window)
        end
    end)

    hs.hotkey.bind({ "alt", "shift" }, "f", function()
        local window = hs.window.focusedWindow()
        if window then
            local screen = window:screen()
            local spaces = hs.spaces.spacesForScreen(screen)
            if #spaces > 1 then
                hs.spaces.moveWindowToSpace(window:id(), spaces[1])
                hs.spaces.gotoSpace(spaces[1])
            end
        end
    end)
end


-- hs.window.filter._showCandidates()
local w_to_ignores = {
    "WindowManager", "Control Centre", "Wallpaper", "talagent",
    "Notification Centre", "Dock Extra", "Stats", "TextInputMenuAgent",
    "SecretAgent", "Adobe Content Synchronizer Finder Extension",
    "Shortcuts Events", "Karabiner-NotificationWindow", "Universal Control",
    "Mail Networking", "Mail Graphics and Media", "universalAccessAuthWarn",
    "UserNotificationCenter", "com.apple.hiservices-xpcservice",
    "MobileDeviceUpdater", "AutoFillPanelService", "Mail (Finder) Networking",
    "Adobe Content Synchronizer Finder Extension",
    "Google Chrome Helper (Plugin)", "Safari Graphics and Media",
    "AXVisualSupportAgent", "CoreLocationAgent",
    "SoftwareUpdateNotificationManager", "Single Sign-On", "coreautha",
    "TextInputSwitcher", "DockHelper", "OSDUIHelper",
    "Safari Service Worker (skiff.com)", "Tailscale",
    "AccessibilityVisualsAgent", "Safari Web Content (Prewarmed)",
    "Dash Networking", "Dash Web Content", "Dash Graphics and Media",
    "Safari Web Content (Cached)", "com.apple.WebKit.WebContent",
    "Safari Web Content"
}

for _, name in pairs(w_to_ignores) do hs.window.filter.ignoreAlways[name] = true end


return M
