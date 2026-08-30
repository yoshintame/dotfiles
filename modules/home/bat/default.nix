{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "bat" {
  home.packages = [
    pkgs.bat
  ];

  nixDotbot.links = {
    "~/.config/bat" = "modules/home/bat/config";
  };
}
