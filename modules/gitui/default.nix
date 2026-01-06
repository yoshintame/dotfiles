{pkgs, ...}: {
  home.packages = [
    pkgs.gitui
  ];

  nixDotbot.links = {
    "~/.config/gitui" = "modules/gitui/config";
  };
}
