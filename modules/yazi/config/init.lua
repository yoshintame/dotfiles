function Manager:render(area)
	local chunks = self:layout(area)

	return ya.flat {
		-- Parent
        Parent:render(chunks[1]:padding(ui.Padding.xy(1))),
		-- Current
        Current:render(chunks[2]:padding(ui.Padding.y(1))),
		-- Preview
        Preview:render(chunks[3]:padding(ui.Padding.xy(1))),
	}
end

require("zoxide"):setup { update_db = true }
require("starship"):setup()
