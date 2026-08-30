{ config, myLib, ... }:
myLib.mkModule config "hammerspoon" {
  nixLink.links = {
    "~/.hammerspoon/" = {
      path = "modules/home/hammerspoon/config/**";
      glob = true;
    };
  };
}
