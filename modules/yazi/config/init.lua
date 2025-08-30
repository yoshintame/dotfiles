require("zoxide"):setup { update_db = true }
require("starship"):setup()
require("relative-motions"):setup({ show_numbers="relative", show_motion = true })
require("dropover"):setup({ watch_dir="/Users/yoshintame/.local/share/dropover" })

th.git = th.git or {}
th.git.modified = ui.Style():fg("yellow"):bold()
th.git.added = ui.Style():fg("green"):bold()
th.git.untracked = ui.Style():fg("green"):bold()
th.git.ignored = ui.Style():fg("gray"):bold()
th.git.deleted = ui.Style():fg("red"):bold()
th.git.updated = ui.Style():fg("yellow"):bold()

th.git.modified_sign = "M"
th.git.added_sign = "A"
th.git.untracked_sign = "U"
th.git.ignored_sign = "I"
th.git.deleted_sign = "D"
th.git.updated_sign = "U"

require("git"):setup()

local pref_by_location = require("pref-by-location")
pref_by_location:setup({
  prefs = {
    save_path = os.getenv("HOME") .. "/.config/yazi/pref-by-location",
    { location = ".*/Downloads", sort = { "mtime", reverse = true, dir_first = false }, linemode = "size" },
  },
})
