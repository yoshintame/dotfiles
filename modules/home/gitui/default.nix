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

  nixLink.links = {
    "~/.config/gitui" = "modules/home/gitui/config";
  };
}
