{pkgs, ...}: {
  nixDotbot.links = {
    "~/.config/wezterm" = "modules/wezterm/config";
  };
}
