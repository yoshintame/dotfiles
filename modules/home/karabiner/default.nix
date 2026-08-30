{ config, myLib, ... }:
myLib.mkModule config "karabiner" {
  nixDotbot.links = {
    "~/.config/karabiner/karabiner.json" = "modules/home/karabiner/config/build/karabiner.json";
  };
}
