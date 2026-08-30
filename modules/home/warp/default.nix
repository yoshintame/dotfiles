{ config, myLib, ... }:
myLib.mkModule config "warp" {
  nixDotbot.links = {
    "~/.warp/" = {
      path = "modules/home/warp/config/**";
      glob = true;
    };
  };
}
