local log = hs.logger.new('yabai', 'info')

function yabaiSendMessage(args, completion, await)
    local yabai_output = ""
    local yabai_error = ""

    table.insert(args, 1, "-m")

    local yabai_task = hs.task.new("/opt/homebrew/bin/yabai", nil, function(task, stdout, stderr)
        log.i("stdout:" .. stdout, "stderr:" .. stderr)

        if stdout ~= nil then yabai_output = yabai_output .. stdout end
        if stderr ~= nil then yabai_error = yabai_error .. stderr end
        return true
    end, args)

    if type(completion) == "function" then
        yabai_task:setCallback(function() completion(yabai_output, yabai_error) end)
    end

    yabai_task:start()

    if await then
        yabai_task:waitUntilExit()
        return yabai_output
    end
end

function yabaiSplit()
    local output = yabaiSendMessage({ "query", "--spaces", "--space" }, nil, true)
    local currentSpace = hs.json.decode(output).index

    if currentSpace == 1 then
        yabaiSendMessage({ "space", "--create" }, nil, true)
        yabaiSendMessage({ "window", "--space", "last" }, nil, true)
        yabaiSendMessage({ "space", "--focus", "last" }, nil, true)

        local output = yabaiSendMessage({ "query", "--spaces", "--space" }, nil, true)
        currentSpace = hs.json.decode(output).index
    end

    YABAI_PENDING_SPACE = currentSpace

    yabaiSendMessage(
        { "signal", "--add", "label=active-split-pending", "event=window_focused",
            "action='/Users/yoshintame/yabai/scripts/window-split-signal-hs.sh " .. YABAI_PENDING_SPACE .. "'" }, nil,
        true)
end

function yabaiUnsplit()
    local output = yabaiSendMessage({ "query", "--spaces", "--space" }, nil, true)
    local currentSpace = hs.json.decode(output).index

    if currentSpace ~= 1 then
        output = yabaiSendMessage({ "query", "--spaces", "--space" }, nil, true)
        local windowsCount = hs.json.decode(output).windows

        print(hs.inspect(#windowsCount))

        if #windowsCount <= 2 then
            yabaiSendMessage({ "space", "--destroy" }, nil, true)
        else
            yabaiSendMessage({ "window", "--space", "first" }, nil, true)
        end
    end

    YABAI_PENDING_SPACE = nil
end

yabaidirectcall = {
    set_yabai_pending_to_false = function()
        log.i("set_yabai_pending_to_false call")
        hs.alert("Call!")
        YABAI_PENDING_SPACE = nil
    end
}
