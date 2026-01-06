{pkgs, ...}: {
  nixDotbot.links = {
    "~/.config/yabai/yabairc" = "modules/yabai/config/yabairc";
  };
}
