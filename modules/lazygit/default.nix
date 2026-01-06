{pkgs, ...}: {
  home.packages = [
    pkgs.lazygit
  ];

  nixDotbot.links = {
    "~/.config/lazygit" = "modules/lazygit/config";
  };
}
