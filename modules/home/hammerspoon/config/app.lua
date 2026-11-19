local apps = require("actions.apps")
local bind = require("engine.bind")
local leader = require("engine.leader")

local features = require("user.features")
local started, failed = {}, {}

local function run(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        started[#started + 1] = name
    else
        failed[#failed + 1] = name
        print(name .. " failed to start: " .. tostring(err))
    end
end

local enabled = {}
for name in pairs(features) do enabled[#enabled + 1] = name end
table.sort(enabled)

for _, name in ipairs(enabled) do
    run("features." .. name, function() require("features." .. name).start(features[name]) end)
end

run("binds", function()
    local leaderConfig = require("user.leader")
    leader.start(leaderConfig)
    local direct = require("user.direct")
    local rows = apps.launcher(direct.launcher)
    for _, row in ipairs(direct.binds) do rows[#rows + 1] = row end
    for _, row in ipairs(bind.fromChords(direct.proxy)) do rows[#rows + 1] = row end
    bind.direct(rows, { leaderConfig.trigger })
    switchCurrentAppWindows = apps.switchWindows
end)

if #failed > 0 then
    hs.notify.new({ title = "Hammerspoon", informativeText = "Failed to start: " .. table.concat(failed, ", ") }):send()
end

hs.shutdownCallback = function()
    for i = #started, 1, -1 do
        local module = package.loaded[started[i]]
        if module and module.stop then pcall(module.stop) end
    end
end
