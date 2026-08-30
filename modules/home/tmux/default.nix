{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "tmux" {
  home.packages = [
    pkgs.tmux
  ];

  nixDotbot.links = {
    "~/.config/tmux/" = {
      path = "modules/home/tmux/config/**";
      glob = true;
    };
  };
}
