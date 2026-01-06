local changed = ya.sync(function(st, new)
	local b = st.last ~= new
	st.last = new
	return b or not cx.active.finder
end)

local AVAILABLE_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789."
local escape = function(s) return s == "." and "\\." or s end

local function create_char_input()
	local candidates = {}
	for i = 1, #AVAILABLE_CHARS do
		candidates[#candidates + 1] = { on = AVAILABLE_CHARS:sub(i, i) }
	end

	return function()
		local idx = ya.which { cands = candidates, silent = true }
		if not idx then
			return nil
		end

		return escape(candidates[idx].on)
	end
end

local input_char = create_char_input()


local function entry()
    local kw = input_char()
    if not kw then
        return
    end

    if changed(kw) then
        ya.manager_emit("find_do", { "^" .. kw })
    else
        ya.manager_emit("find_arrow", {})
    end
end

return { entry = entry }
