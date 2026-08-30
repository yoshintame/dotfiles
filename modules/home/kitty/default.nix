{ config, myLib, ... }:
myLib.mkModule config "kitty" {
  nixLink.links = {
    "~/.config/kitty" = "modules/home/kitty/config";
  };
}
