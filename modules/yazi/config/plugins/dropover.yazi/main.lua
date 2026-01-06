local function notify_error(title, content)
    ya.notify {
        title = title,
        content = content,
        timeout = 5,
        level = "error",
    }
end

local function file_or_dir_exists(name)
    local result = os.execute('test -L "' .. name .. '"')
    return result ~= nil
end

local function ensure_dir(path)
    return os.execute("mkdir -p " .. path)
end

local function create_link(original, link)
    return os.execute("ln -s " .. tostring(original) .. " " .. tostring(link))
end

local function create_links(urls)
    for _, url in ipairs(urls) do
        local success, error = create_link(url.original, url.link)
        if not success then
            notify_error("Failed to create link", error)
        end
    end
end

local function add_index_to_name(url, index)
    local name = url:stem()
    local ext = url:name():sub(#name + 1)

    return Url(url:parent() .. "/" .. name .. "_" .. index .. ext)
end

local function get_unique_path(url)
    url = Url(url)

    if not file_or_dir_exists(url) then
        return url
    end

    local index = 1
    local new_url = add_index_to_name(url, index)

    while file_or_dir_exists(new_url) do
        index = index + 1
        new_url = add_index_to_name(url, index)
    end

    return new_url
end

local get_watch_dir = ya.sync(function(state) return state._watch_dir end)

local get_selected_or_hovered = ya.sync(function()
    local tab, paths = cx.active, {}
    for _, u in pairs(tab.selected) do
        paths[#paths + 1] = u
    end
    if #paths == 0 and tab.current.hovered then
        paths[1] = tab.current.hovered.url
    end
    return paths
end)

local function exit_visual_mode()
    ya.manager_emit("escape", { visual = true })
end

local function schedule_cleanup(watch_dir)
    ya.err('echo "rm -rf ' .. watch_dir ..'/*" | at now + 1 minute > /dev/null 2>&1')

    return os.execute('echo "rm -rf ' .. watch_dir ..'/*" | at now + 1 minute > /dev/null 2>&1')
end

return {
    entry = function()
        local watch_dir = get_watch_dir()

        local success, error = ensure_dir(watch_dir)
        if not success then
            notify_error("Failed to ensure watched directory", error)
        end

        exit_visual_mode()

        local urls = get_selected_or_hovered()

        for i, path in ipairs(urls) do
            urls[i] = { original = path, link = get_unique_path(watch_dir .. "/" .. path:name()) }
        end

        create_links(urls)
        local success, error = schedule_cleanup(watch_dir)
        if not success then
            notify_error("Failed to schedule wathed directory cleanup", error)
        end
    end,
    setup = function(state, args)
        state._watch_dir = args.watch_dir
    end
}
