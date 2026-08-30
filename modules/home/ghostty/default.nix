{ config, myLib, ... }:
myLib.mkModule config "ghostty" {
  nixDotbot.links = {
    "~/.config/ghostty" = "modules/home/ghostty/config";
  };
}
