{ config, myLib, ... }:
myLib.mkModule config "yabai" {
  nixDotbot.links = {
    "~/.config/yabai/yabairc" = "modules/home/yabai/config/yabairc";
  };
}
