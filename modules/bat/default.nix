{pkgs, ...}: {
  home.packages = [
    pkgs.bat
  ];

  nixDotbot.links = {
    "~/.config/bat" = "modules/bat/config";
  };
}
