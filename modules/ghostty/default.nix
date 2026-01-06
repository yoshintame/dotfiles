{pkgs, ...}: {
  nixDotbot.links = {
    "~/.config/ghostty" = "modules/ghostty/config";
  };
}
