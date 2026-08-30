{ config, myLib, ... }:
myLib.mkModule config "codex" {
  nixLink.links = {
    "~/.codex/AGENTS.md" = "modules/home/agents-shared/config/AGENTS.md";
    "~/.codex/config.toml" = "modules/home/codex/config/config.toml";
    "~/.agents/skills/git-commit" = "modules/home/agents-shared/config/skills/git-commit";
    "~/.agents/skills/fetch-reddit" = "modules/home/agents-shared/config/skills/fetch-reddit";
    "~/.agents/skills/vscode-marketplace" =
      "modules/home/agents-shared/config/skills/vscode-marketplace";
  };
}
