{ config, myLib, ... }:
myLib.mkModule config "data-exports" {
  nixLink.links = {
    "~/.local/bin/data-export-import" = "modules/home/data-exports/config/bin/data-export-import";
  };
}
