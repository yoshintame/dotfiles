{ config, myLib, ... }:
myLib.mkModule config "op" {
  nixLink.links = {
    "~/.config/1Password/ssh/agent.toml" = "modules/home/op/config/agent.toml";
  };
}
