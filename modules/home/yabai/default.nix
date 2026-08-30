{ config, myLib, ... }:
myLib.mkModule config "yabai" {
  nixLink.links = {
    "~/.config/yabai/yabairc" = "modules/home/yabai/config/yabairc";
  };
}
