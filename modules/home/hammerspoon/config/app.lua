local MODULES = {
    "features.raycast-nav",
    "features.onepassword-focus-guard",
    "features.afk-indicator",
    "features.coffee-lid",
    "features.sms-otp",
    "features.clipboard-history",
    "features.meeting",
    "features.hyper-setup",
    "binds",
}

local started, failed = {}, {}

for _, name in ipairs(MODULES) do
    local ok, err = xpcall(function() require(name).start() end, debug.traceback)
    if ok then
        started[#started + 1] = name
    else
        failed[#failed + 1] = name
        print(name .. " failed to start: " .. tostring(err))
    end
end

if #failed > 0 then
    hs.notify.new({ title = "Hammerspoon", informativeText = "Не стартовали: " .. table.concat(failed, ", ") }):send()
end

hs.shutdownCallback = function()
    for i = #started, 1, -1 do
        local module = package.loaded[started[i]]
        if module.stop then pcall(module.stop) end
    end
end
