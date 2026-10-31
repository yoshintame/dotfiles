{ config, myLib, ... }:
myLib.mkModule config "keyswitcher" {
  nixLink.links."~/.config/desvio/keyswitcher" = "modules/home/keyswitcher/config";
}
