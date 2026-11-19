local M = {}

local COMPACT_WIDTH = 420
local COMPACT_MAX_HEIGHT = 860

local previousFrames = {}

local function isMaximized(frame, screenFrame)
    return frame.x <= screenFrame.x + 8
        and frame.y <= screenFrame.y + 8
        and frame.w >= screenFrame.w - 16
        and frame.h >= screenFrame.h - 16
end

function M.toggleFloatMaximize()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screenFrame = win:screen():frame()
    local frame = win:frame()
    if isMaximized(frame, screenFrame) then
        local prev = previousFrames[win:id()]
        if prev then
            win:setFrame(prev)
        else
            local h = math.min(COMPACT_MAX_HEIGHT, screenFrame.h - 60)
            win:setFrame({
                x = screenFrame.x + (screenFrame.w - COMPACT_WIDTH) / 2,
                y = screenFrame.y + (screenFrame.h - h) / 2,
                w = COMPACT_WIDTH,
                h = h,
            })
        end
    else
        previousFrames[win:id()] = frame
        win:setFrame(screenFrame)
    end
end

return M
