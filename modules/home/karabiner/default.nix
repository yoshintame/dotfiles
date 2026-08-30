{ config, myLib, ... }:
myLib.mkModule config "karabiner" {
  nixLink.links = {
    "~/.config/karabiner/karabiner.json" = "modules/home/karabiner/config/build/karabiner.json";
  };
}
