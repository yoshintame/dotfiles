{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "btop" {
  home.packages = [
    pkgs.btop
  ];

  nixLink.links = {
    "~/.config/btop" = "modules/home/btop/config";
  };
}
