{ config, myLib, ... }:
myLib.mkModule config "op" {
  nixDotbot.links = {
    "~/.config/1Password/ssh/agent.toml" = "modules/home/op/config/agent.toml";
  };
}
