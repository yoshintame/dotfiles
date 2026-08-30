{ config, myLib, ... }:
myLib.mkModule config "warp" {
  nixLink.links = {
    "~/.warp/" = {
      path = "modules/home/warp/config/**";
      glob = true;
    };
  };
}
