{ config, myLib, ... }:
myLib.mkModule config "zed" {
  nixLink.links = {
    "~/.config/zed/settings.json" = "modules/home/zed/config/settings.json";
    "~/.config/zed/keymap.json" = "modules/home/zed/config/keymap.json";
    "~/.config/zed/themes" = "modules/home/zed/config/themes";
  };
}
