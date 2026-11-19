local M = {}

local function encode(s)
    return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

function M.raycast(path, params)
    local url = "raycast://" .. path
    if not params then return url end
    local query = {}
    for _, name in ipairs({ "arguments", "context" }) do
        if params[name] then query[#query + 1] = name .. "=" .. encode(hs.json.encode(params[name])) end
    end
    return url .. "?" .. table.concat(query, "&")
end

return M
