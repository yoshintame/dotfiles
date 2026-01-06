{pkgs, ...}: {
  home.packages = [
    pkgs.aerospace
  ];

  nixDotbot.links = {
    "~/.config/aerospace" = "modules/aerospace/config";
  };
}
