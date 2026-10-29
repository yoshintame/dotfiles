{ config, myLib, ... }:
myLib.mkModule config "app-state" {
  nixLink.links = {
    "~/.config/app-state" = "modules/home/app-state/config";
  };
}
