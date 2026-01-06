{pkgs, ...}: {
  nixDotbot.links = {
    "~/.config/karabiner/karabiner.json" = "modules/karabiner/config/build/karabiner.json";
  };
}
