{ config, myLib, ... }:
myLib.mkModule config "hammerspoon" {
  nixDotbot.links = {
    "~/.hammerspoon/" = {
      path = "modules/home/hammerspoon/config/**";
      glob = true;
    };
  };
}
