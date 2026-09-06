{ config, myLib, ... }:
myLib.mkModule config "apm" {
  nixLink.links = {
    "~/.apm/apm.lock.yaml" = "modules/home/apm/config/apm.lock.yaml";
    "~/.apm/apm.yml" = "modules/home/apm/config/apm.yml";
  };
}
