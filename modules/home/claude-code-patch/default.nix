{ config, myLib, ... }:
myLib.mkModule config "claude-code-patch" {
  nixDotbot.links = {
    "~/.local/bin/claude-code-patch" = "modules/home/claude-code-patch/config/patch.py";
  };
}
