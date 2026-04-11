{...}: {
  nixDotbot.links = {
    "~/.codex/AGENTS.md" = "modules/agents-shared/config/AGENTS.md";
    "~/.codex/config.toml" = "modules/codex/config/config.toml";
    "~/.agents/skills/git-commit" = "modules/agents-shared/config/skills/git-commit";
    "~/.agents/skills/fetch-reddit" = "modules/agents-shared/config/skills/fetch-reddit";
    "~/.agents/skills/vscode-marketplace" = "modules/agents-shared/config/skills/vscode-marketplace";
  };
}
