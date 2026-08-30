{ config, myLib, ... }:
myLib.mkModule config "ghostty" {
  nixLink.links = {
    "~/.config/ghostty" = "modules/home/ghostty/config";
  };
}
