{pkgs, ...}: {
  home.packages = [
    pkgs.git
  ];

  nixDotbot.links = {
    "~/.config/git" = "modules/git/config";
  };
}
