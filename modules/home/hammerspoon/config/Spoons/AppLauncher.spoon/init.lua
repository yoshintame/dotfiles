local M = {}
M.__index = M

M.name = "AppLauncher"
M.version = "0.1"
M.author = "Mikhail Ivanov <m.ivanov0427@gmail.com>"

function M:launchOrFocusWarpApp(name)
    local app = hs.application.get("Warp")
    local window = app:findWindow(name)
    if window ~= nil then
        window:focus()
    else
        hs.urlevent.openURL('warp://launch/' .. name)
    end
end

function M:launchOrFocusApp(name)
    hs.application.launchOrFocus(name)
end

function M:bindHotkeys(mapping)
    for app, keyInfos in pairs(mapping) do
        if type(keyInfos[1][1]) ~= "table" then
            keyInfos = { keyInfos }
        end

        for _, keyInfo in ipairs(keyInfos) do
            local mods = keyInfo[1]
            local key = keyInfo[2]
            local isWarp = keyInfo.isWarp
            local keyboardLayout = keyInfo.keyboardLayout

            hs.hotkey.bind(mods, key, function()
                if isWarp then
                    self:launchOrFocusWarpApp(app)
                else
                    self:launchOrFocusApp(app)
                end

                if keyboardLayout then
                    hs.keycodes.setLayout(keyboardLayout)
                end
            end)
        end
    end
end

return M
