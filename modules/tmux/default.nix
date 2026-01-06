{pkgs, ...}: {
  home.packages = [
    pkgs.tmux
  ];

  nixDotbot.links = {
    "~/.config/tmux/" = {
      path = "modules/tmux/config/**";
      glob = true;
    };
  };
}
