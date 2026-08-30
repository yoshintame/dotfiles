{ config, myLib, ... }:
myLib.mkModule config "iina" {
  nixDotbot.links = {
    "~/Library/Application Support/com.colliderli.iina/" = {
      path = "modules/home/iina/config/**";
      glob = true;
    };
  };
}
