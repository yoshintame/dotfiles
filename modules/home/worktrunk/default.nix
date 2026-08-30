{ config, myLib, ... }:
myLib.mkModule config "worktrunk" {
  nixLink.links = {
    "~/.config/worktrunk/config.toml" = "modules/home/worktrunk/config/config.toml";
  };
}
