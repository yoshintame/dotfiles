{ config, myLib, ... }:
myLib.mkModule config "kitty" {
  nixDotbot.links = {
    "~/.config/kitty" = "modules/home/kitty/config";
  };
}
