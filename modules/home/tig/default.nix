{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "tig" {
  home.packages = [
    pkgs.tig
  ];

  nixLink.links = {
    "~/.config/tig/config" = "modules/home/tig/config/tigrc";
  };
}
