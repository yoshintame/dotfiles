{ config, myLib, ... }:
myLib.mkModule config "serena" {
  nixDotbot.links = {
    "~/.serena/serena_config.yml" = "modules/home/serena/serena_config.yml";
  };
}
