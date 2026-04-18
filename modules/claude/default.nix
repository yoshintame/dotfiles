{...}: {
  nixDotbot.links = {
    "~/.claude/settings.json" = "modules/claude/config/settings.json";
    "~/.claude/CLAUDE.md" = "modules/agents-shared/config/AGENTS.md";
    "~/.claude/hooks/" = {
      path = "modules/agents-shared/config/hooks/**";
      glob = true;
    };
    "~/.claude/skills/git-commit/" = {
      path = "modules/agents-shared/config/skills/git-commit/**";
      glob = true;
    };
    "~/.claude/skills/fetch-reddit/" = {
      path = "modules/agents-shared/config/skills/fetch-reddit/**";
      glob = true;
    };
    "~/.claude/skills/vscode-marketplace/" = {
      path = "modules/agents-shared/config/skills/vscode-marketplace/**";
      glob = true;
    };
    "~/.claude/skills/brew-cask/" = {
      path = "modules/agents-shared/config/skills/brew-cask/**";
      glob = true;
    };
    "~/.claude/skills/" = {
      path = "modules/claude/config/skills/**";
      glob = true;
    };
    "~/.local/bin/search-reddit" = "modules/agents-shared/config/bin/search-reddit";
    "~/.local/bin/search-hn" = "modules/agents-shared/config/bin/search-hn";
    "~/.local/bin/search-github" = "modules/agents-shared/config/bin/search-github";
  };
}
