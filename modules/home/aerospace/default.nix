{ config, myLib, ... }:
myLib.mkModule config "aerospace" {
  nixDotbot.links = {
    "~/.config/aerospace" = "modules/home/aerospace/config";
  };
}
