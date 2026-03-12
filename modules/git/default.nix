{pkgs, ...}: {
  home.packages = [
    pkgs.git
  ];

  nixDotbot.links = {
    "~/.config/git" = "modules/git/config";
    "~/.local/bin/" = {
      path = "modules/git/bin/**";
      glob = true;
    };
  };
}
