local apps = require("actions.apps")
local bind = require("core.bind")
local leader = require("leader")

local M = {}

function M.start()
    local leaderBinds = require("binds.leader")
    leader.start(leaderBinds)
    bind.direct(require("binds.direct"), { leaderBinds.trigger })
    switchCurrentAppWindows = apps.switchWindows
    return M
end

return M
