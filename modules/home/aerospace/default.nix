{ config, myLib, ... }:
myLib.mkModule config "aerospace" {
  nixLink.links = {
    "~/.config/aerospace" = "modules/home/aerospace/config";
  };
}
