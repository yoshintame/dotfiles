{pkgs, ...}: {
  nixDotbot.links = {
    "~/.config/kitty" = "modules/kitty/config";
  };
}
