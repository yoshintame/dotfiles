{ config, myLib, ... }:
myLib.mkModule config "wezterm" {
  nixLink.links = {
    "~/.config/wezterm" = "modules/home/wezterm/config";
  };
}
