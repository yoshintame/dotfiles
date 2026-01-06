{pkgs, ...}: {
  home.packages = [
    pkgs.atuin
  ];

  nixDotbot.links = {
    "~/.config/atuin" = "modules/atuin/config";
  };
}
