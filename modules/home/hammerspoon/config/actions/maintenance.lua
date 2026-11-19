local apps = require("actions.apps")
local bin = require("core.bin")
local sys = require("core.sys")

local M = {}

local KEYSWITCHER = "com.granin.keyswitcher"
local STACK_STAGGER = 0.15

local keySwitcherRestart = nil

local function kickstartKarabinerAgent()
    sys.run(bin.sh, { "-c", "exec /bin/launchctl kickstart -k gui/$(/usr/bin/id -u)/org.pqrs.service.agent.karabiner_console_user_server" })
end

function M.kickstartKarabiner()
    kickstartKarabinerAgent()
    hs.alert.show("⌨︎ Karabiner console_user_server kickstarted")
end

function M.restartStack(bundleIDs)
    return function()
        kickstartKarabinerAgent()
        for i, bundleID in ipairs(bundleIDs) do
            sys.after((i - 1) * STACK_STAGGER, function()
                apps.killAndReopen(bundleID)
            end)
        end
        hs.alert.show("♻︎ Restarting tool stack…")
    end
end

function M.resetClaudeSessions()
    local home = os.getenv("HOME")
    hs.alert.show("♻︎ Resetting Claude Code sessions…")
    sys.run(bin.bun, { home .. "/.claude/skills/reset-sessions/scripts/reset-sessions.ts", "--all" }, {
        env = { HOME = home, PATH = "/usr/bin:/bin:/usr/sbin:/sbin" },
        onExit = function(exitCode, stdOut)
            local summary = stdOut:match("Убито:[^\n]*") or stdOut:match("Нечего убивать[^\n]*")
            if exitCode == 0 and summary then
                hs.alert.show("✅ " .. summary)
            elseif exitCode == 0 then
                hs.alert.show("✅ Claude Code sessions reset")
            else
                hs.alert.show("⚠️ reset-sessions failed (exit " .. tostring(exitCode) .. ")")
            end
        end,
    })
end

function M.restartPaseoDaemon()
    hs.alert.show("♻︎ Restarting Paseo daemon…")
    sys.run(bin.paseo, { "daemon", "restart" }, {
        env = { HOME = os.getenv("HOME"), PATH = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" },
        onExit = function(exitCode)
            if exitCode == 0 then
                hs.alert.show("✅ Paseo daemon restarted")
            else
                hs.alert.show("⚠️ paseo daemon restart failed (exit " .. tostring(exitCode) .. ")")
            end
        end,
    })
end

local function restartKeySwitcher(label)
    local app = hs.application.get(KEYSWITCHER)
    if not app then
        hs.alert.show(label .. " — со следующего запуска")
        return
    end
    app:kill()
    local deadline = hs.timer.secondsSinceEpoch() + 5
    keySwitcherRestart = sys.waitUntil(function()
        return hs.application.get(KEYSWITCHER) == nil or hs.timer.secondsSinceEpoch() > deadline
    end, function()
        keySwitcherRestart = nil
        if hs.application.get(KEYSWITCHER) then
            hs.alert.show("keySwitcher не закрылся, флаг сменится после перезапуска")
            return
        end
        sys.open(nil, { background = true, bundle = KEYSWITCHER })
        hs.alert.show(label)
    end, 0.2)
end

function M.toggleKeySwitcherLog()
    if keySwitcherRestart then
        hs.alert.show("keySwitcher ещё перезапускается")
        return
    end
    keySwitcherRestart = true
    sys.run(bin.defaults, { "read", KEYSWITCHER, "QKBVerboseLogging" }, {
        onExit = function(_, out)
            local verbose = out:match("1") ~= nil
            local args = verbose and { "delete", KEYSWITCHER, "QKBVerboseLogging" }
                or { "write", KEYSWITCHER, "QKBVerboseLogging", "-bool", "YES" }
            sys.run(bin.defaults, args, {
                onExit = function()
                    keySwitcherRestart = nil
                    restartKeySwitcher(verbose and "keySwitcher: журнал обезличенный"
                        or "keySwitcher: журнал ПОДРОБНЫЙ (текст открыто)")
                end,
            })
        end,
    })
end

function M.reload()
    hs.reload()
    hs.console.clearConsole()
end

return M
