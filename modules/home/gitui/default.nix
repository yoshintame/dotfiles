{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "gitui" {
  home.packages = [
    pkgs.gitui
  ];

  nixDotbot.links = {
    "~/.config/gitui" = "modules/home/gitui/config";
  };
}
