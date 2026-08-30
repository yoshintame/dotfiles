{ config, myLib, ... }:
myLib.mkModule config "worktrunk" {
  nixDotbot.links = {
    "~/.config/worktrunk/config.toml" = "modules/home/worktrunk/config/config.toml";
  };
}
