local M = {}

local active = false
local tabHeld = false
local tap = nil

function M.toggle()
    active = not active
    if active then
        tap:start()
        hs.alert.show("Hyper Setup ON — Tab = ⌃⌥⇧⌘")
    else
        tap:stop()
        hs.alert.show("Hyper Setup OFF")
    end
end

function M.start()
    local types = hs.eventtap.event.types
    tap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(e)
        local eventType = e:getType()

        if e:getKeyCode() == hs.keycodes.map["tab"] then
            tabHeld = (eventType == types.keyDown)
            return true
        end

        if tabHeld and eventType == types.keyDown then
            e:setFlags({ cmd = true, alt = true, ctrl = true, shift = true })
        end
        return false
    end)
    return M
end

return M
