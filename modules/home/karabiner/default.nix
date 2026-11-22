{ config, myLib, ... }:
myLib.mkModule config "karabiner" {
  nixLink.links."~/.config/karabiner/karabiner.json" = {
    root = "karabiner-config";
    path = "build/karabiner.json";
  };
}
