local MODULES = {
    "features.raycast-nav",
    "features.onepassword-focus-guard",
    "features.afk-indicator",
    "features.coffee-lid",
    "features.sms-otp",
    "features.finder-copy-path",
    "features.clipboard-history",
    "features.meeting-notes",
}

local started, failed = {}, {}

local function run(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        failed[#failed + 1] = name
        print(name .. " failed to start: " .. tostring(err))
    end
    return ok
end

for _, name in ipairs(MODULES) do
    if run(name, function() require(name).start() end) then
        started[#started + 1] = name
    end
end

run("main", function() dofile(hs.configdir .. "/main.lua") end)

if #failed > 0 then
    hs.notify.new({ title = "Hammerspoon", informativeText = "Не стартовали: " .. table.concat(failed, ", ") }):send()
end

hs.shutdownCallback = function()
    for i = #started, 1, -1 do
        local module = package.loaded[started[i]]
        if module.stop then pcall(module.stop) end
    end
end
