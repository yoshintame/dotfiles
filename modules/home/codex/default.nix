{ config, myLib, ... }:
myLib.mkModule config "codex" {
  nixLink.links = {
    "~/.codex/AGENTS.md" = "modules/home/agents-shared/config/AGENTS.md";
    "~/.codex/config.toml" = "modules/home/codex/config/config.toml";
  };
}
