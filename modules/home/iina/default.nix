{ config, myLib, ... }:
myLib.mkModule config "iina" {
  nixLink.links = {
    "~/Library/Application Support/com.colliderli.iina/" = {
      path = "modules/home/iina/config/**";
      glob = true;
    };
  };
}
