{ config, myLib, ... }:
myLib.mkModule config "serena" {
  nixLink.links = {
    "~/.serena/serena_config.yml" = "modules/home/serena/serena_config.yml";
  };
}
