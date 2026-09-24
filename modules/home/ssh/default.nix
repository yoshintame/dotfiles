{ config, myLib, ... }:
myLib.mkModule config "ssh" {
  nixLink.links = {
    "~/.ssh/config" = "modules/home/ssh/config/config";
    "~/.ssh/senate.conf" = "modules/home/ssh/config/senate.conf";
  };
}
