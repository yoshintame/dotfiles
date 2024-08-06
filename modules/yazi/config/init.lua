require("zoxide"):setup { update_db = true }
require("starship"):setup()
require("relative-motions"):setup({ show_numbers="relative", show_motion = true })
require("full-border"):setup { type = ui.Border.ROUNDED }
require("dropover"):setup({ watch_dir="/Users/yoshintame/.local/share/dropover" })
