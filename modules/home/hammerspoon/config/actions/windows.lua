local M = {}

local previousFrames = {}

local function isMaximized(frame, screenFrame)
    return frame.x <= screenFrame.x + 8
        and frame.y <= screenFrame.y + 8
        and frame.w >= screenFrame.w - 16
        and frame.h >= screenFrame.h - 16
end

function M.floatMaximize(compact)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end
        local screenFrame = win:screen():frame()
        local frame = win:frame()
        if isMaximized(frame, screenFrame) then
            local prev = previousFrames[win:id()]
            if prev then
                win:setFrame(prev)
            else
                local h = math.min(compact.maxHeight, screenFrame.h - 60)
                win:setFrame({
                    x = screenFrame.x + (screenFrame.w - compact.width) / 2,
                    y = screenFrame.y + (screenFrame.h - h) / 2,
                    w = compact.width,
                    h = h,
                })
            end
        else
            previousFrames[win:id()] = frame
            win:setFrame(screenFrame)
        end
    end
end

return M
