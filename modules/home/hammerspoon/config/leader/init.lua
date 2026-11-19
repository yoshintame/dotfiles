local M = {}

local KEYCODES = {
    a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9,
    b = 11, q = 12, w = 13, e = 14, r = 15, y = 16, t = 17,
    ["1"] = 18, ["2"] = 19, ["3"] = 20, ["4"] = 21, ["6"] = 22, ["5"] = 23,
    ["="] = 24, ["9"] = 25, ["7"] = 26, ["-"] = 27, ["8"] = 28, ["0"] = 29,
    ["]"] = 30, o = 31, u = 32, ["["] = 33, i = 34, p = 35, l = 37, j = 38,
    ["'"] = 39, k = 40, [";"] = 41, ["\\"] = 42, [","] = 43, ["/"] = 44,
    n = 45, m = 46, ["."] = 47, ["`"] = 50,
    ["return"] = 36, tab = 48, space = 49, delete = 51, escape = 53,
    left = 123, right = 124, down = 125, up = 126,
}

local KEY_LABELS = { space = "SPC" }

local style, root, current, helper, modal, trigger, mouseTap

local function keycode(name)
    return KEYCODES[name] or hs.keycodes.map[name]
end

local function idOf(shift, code)
    return (shift and "S" or "") .. code
end

local function parse(key)
    if #key == 1 and key:match("%u") then
        return true, key:lower()
    end
    return false, key
end

local function width(s)
    return utf8.len(s) or #s
end

local function render(items, columns)
    local cells, size = {}, 0
    for i, item in ipairs(items) do
        cells[i] = item.key .. " → " .. item.label
        size = math.max(size, width(cells[i]))
    end
    local lines, row = {}, {}
    for i, cell in ipairs(cells) do
        row[#row + 1] = cell .. string.rep(" ", size - width(cell))
        if #row == columns or i == #cells then
            lines[#lines + 1] = (table.concat(row, "  "):gsub("%s+$", ""))
            row = {}
        end
    end
    return table.concat(lines, "\n")
end

local function compile(entries, path, reserved, columns)
    local node = { children = {}, items = {} }
    for i, entry in ipairs(entries) do
        local key, label, target = entry[1], entry[2], entry[3]
        local where = string.format("leader: %s → #%d %q", path, i, tostring(key))
        if type(key) ~= "string" or type(label) ~= "string" then
            error(where .. ": key and label must be strings", 0)
        end
        local shift, name = parse(key)
        local code = KEYCODES[name]
        if not code then error(where .. ": unsupported key", 0) end
        local id = idOf(shift, code)
        if reserved[id] then error(where .. ": reserved for closing the leader", 0) end
        if node.children[id] then error(where .. ": duplicate key", 0) end
        if type(target) == "table" then
            if shift then error(where .. ": group keys must be lowercase", 0) end
            node.children[id] = compile(target, path .. " " .. key, reserved, columns)
        elseif type(target) == "function" then
            node.children[id] = { action = target }
        else
            error(where .. ": expected an action or a group", 0)
        end
        node.items[#node.items + 1] = { key = KEY_LABELS[name] or key, label = label }
    end
    node.text = render(node.items, columns)
    return node
end

local function hideHelper()
    if helper then
        hs.alert.closeSpecific(helper)
        helper = nil
    end
end

local function show(node)
    current = node
    hideHelper()
    helper = hs.alert.show(node.text, style, true)
end

function M.isOpen()
    return current ~= nil
end

function M.close()
    if not current then return end
    current = nil
    modal:exit()
    if mouseTap then mouseTap:stop() end
    hideHelper()
end

function M.open()
    if current then return end
    modal:enter()
    if mouseTap then mouseTap:start() end
    show(root)
end

local function press(id)
    if not current then return end
    local node = current.children[id]
    if not node then
        M.close()
    elseif node.action then
        M.close()
        node.action()
    else
        show(node)
    end
end

function M.start(cfg)
    local triggerCode = keycode(cfg.trigger)
    if not triggerCode then error("leader: unknown trigger key " .. tostring(cfg.trigger), 0) end

    local reserved, escapes = {}, {}
    for _, name in ipairs(cfg.escape or {}) do
        local code = keycode(name)
        if not code then error("leader: unknown escape key " .. tostring(name), 0) end
        escapes[#escapes + 1] = code
        reserved[idOf(false, code)] = true
    end

    root = compile(cfg.tree, cfg.trigger, reserved, cfg.columns or 3)
    style = cfg.style or hs.alert.defaultStyle

    modal = hs.hotkey.modal.new()
    for _, code in pairs(KEYCODES) do
        for _, shift in ipairs({ false, true }) do
            local id = idOf(shift, code)
            if not reserved[id] then
                modal:bind(shift and { "shift" } or {}, code, function() press(id) end)
            end
        end
    end
    for _, code in ipairs(escapes) do
        modal:bind({}, code, M.close)
    end

    if cfg.abortOnMouseClick then
        local types = hs.eventtap.event.types
        mouseTap = hs.eventtap.new({ types.leftMouseDown, types.rightMouseDown, types.otherMouseDown }, function()
            M.close()
            return false
        end)
    end

    trigger = hs.hotkey.bind({}, triggerCode, function()
        if current then M.close() else M.open() end
    end)

    return M
end

return M
