{ config, myLib, ... }:
myLib.mkModule config "apm" {
  nixLink.links = {
    "~/.apm/apm.yml" = "modules/home/apm/config/apm.yml";
  };
}
