require("zoxide"):setup { update_db = true }
require("starship"):setup()
require("relative-motions"):setup({ show_numbers="relative", show_motion = true })
require("dropover"):setup({ watch_dir="/Users/yoshintame/.local/share/dropover" })

th.git = {
  modified = ui.Style():fg("yellow"):bold(),
  added = ui.Style():fg("green"):bold(),
  untracked = ui.Style():fg("green"):bold(),
  ignored = ui.Style():fg("gray"):bold(),
  deleted = ui.Style():fg("red"):bold(),
  updated = ui.Style():fg("yellow"):bold(),

  modified_sign = "M",
  added_sign = "A",
  untracked_sign = "U",
  ignored_sign = "I",
  deleted_sign = "D",
  updated_sign = "U",
}

require("git"):setup()

local pref_by_location = require("pref-by-location")
pref_by_location:setup({
  prefs = {
    save_path = os.getenv("HOME") .. "/.config/yazi/pref-by-location",
    { location = ".*/Downloads", sort = { "mtime", reverse = true, dir_first = false }, linemode = "size" },
  },
})
