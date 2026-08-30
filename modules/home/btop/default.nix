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

  nixDotbot.links = {
    "~/.config/btop" = "modules/home/btop/config";
  };
}
