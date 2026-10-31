{ config, myLib, ... }:
myLib.mkModule config "paseo-enhanced" {
  nixLink.links."~/.config/desvio/paseo-enhanced" = "modules/home/paseo-enhanced/config";
}
