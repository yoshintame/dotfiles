{ config, myLib, ... }:
myLib.mkModule config "wezterm" {
  nixDotbot.links = {
    "~/.config/wezterm" = "modules/home/wezterm/config";
  };
}
