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

  nixLink.links = {
    "~/.config/tmux/" = {
      path = "modules/home/tmux/config/**";
      glob = true;
    };
  };
}
