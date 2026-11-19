local M = {}

function M.start()
    hs.loadSpoon("SmsOtp")
    spoon.SmsOtp:start()
    return M
end

return M
