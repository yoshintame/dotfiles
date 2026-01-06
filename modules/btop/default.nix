{pkgs, ...}: {
  home.packages = [
    pkgs.btop
  ];

  nixDotbot.links = {
    "~/.config/btop" = "modules/btop/config";
  };
}
