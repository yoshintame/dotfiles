--- @sync entry

local function fail(content)
    return ya.notify { title = "Sort by Added Time", content = content, timeout = 5, level = "error" }
end

return {
  entry = function(self, job)
    local folder = cx.active.current.cwd


    if not folder then
        return fail("No active folder")
    end

    local cwd = tostring(folder)
    local shell_cmd = string.format(
        [[mdls -n kMDItemFSName -n kMDItemDateAdded -raw %q/* | xargs -0 -n2 | sort -rk2 | awk '{print $1}']],
        cwd
    )

    ya.dbg(string.format("cwd: %s", shell_cmd))

    local output, err = Command("mdls")
        :cwd(cwd)
        :arg({ "-c", shell_cmd })
        :output()

    ya.dbg(string.format("output: %s", output))

    if err then
        return fail("Failed to run mdls: " .. err)
    elseif output and not output.status.success then
        return fail("mdls failed: " .. (output.stderr or "unknown error"))
    end

    local sorted_names = {}
    for filename in output.stdout:gmatch("[^\r\n]+") do
        sorted_names[#sorted_names + 1] = filename
    end

    local files_map = {}
    for _, f in ipairs(folder.files) do
        files_map[tostring(f.url)] = f
    end

    local new_order = {}
    for _, name in ipairs(sorted_names) do
        local full_path = cwd .. "/" .. name
        if files_map[full_path] then
            table.insert(new_order, files_map[full_path])
        end
    end
    for _, f in ipairs(folder.files) do
        local found = false
        for _, nf in ipairs(new_order) do
            if nf == f then
                found = true
                break
            end
        end
        if not found then
            table.insert(new_order, f)
        end
    end

    local op = fs.op("reorder", { files = new_order })
    ya.emit("update_files", { op = op })
    ya.emit("redraw")
  end,
}
