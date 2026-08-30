{ config, myLib, ... }:
myLib.mkModule config "ouch" {
  home.shellAliases = {
    ad = "ouch decompress";
    al = "ouch list";
    ma = "ouch compress";
  };
}
