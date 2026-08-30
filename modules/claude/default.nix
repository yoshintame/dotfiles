_: {
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
    "~/.claude/skills/extract/" = {
      path = "modules/agents-shared/config/skills/extract/**";
      glob = true;
    };
    "~/.claude/skills/actualize/" = {
      path = "modules/agents-shared/config/skills/actualize/**";
      glob = true;
    };
    "~/.claude/skills/rewrite/" = {
      path = "modules/agents-shared/config/skills/rewrite/**";
      glob = true;
    };
    "~/.claude/skills/rewrite-audit/" = {
      path = "modules/agents-shared/config/skills/rewrite-audit/**";
      glob = true;
    };
    "~/.claude/skills/done/" = {
      path = "modules/agents-shared/config/skills/done/**";
      glob = true;
    };
    "~/.claude/skills/paused/" = {
      path = "modules/agents-shared/config/skills/paused/**";
      glob = true;
    };
    "~/.claude/skills/senate-vault/" = {
      path = "modules/agents-shared/config/skills/senate-vault/**";
      glob = true;
    };
    "~/.claude/skills/state-reconstruction/" = {
      path = "modules/agents-shared/config/skills/state-reconstruction/**";
      glob = true;
    };
    "~/.claude/skills/" = {
      path = "modules/claude/config/skills/**";
      glob = true;
    };
    "~/.claude/commands/" = {
      path = "modules/claude/config/commands/**";
      glob = true;
    };
    "~/.local/bin/chrome-agent" = "modules/agents-shared/config/chrome-agent/cli.ts";
    "~/.local/bin/chrome-cdp" = "modules/agents-shared/config/chrome-cdp/cli.ts";
    "~/.local/bin/cc-fork-recover" = "modules/agents-shared/config/bin/cc-fork-recover";
    "~/.local/bin/clean-session-log" = "modules/agents-shared/config/bin/clean-session-log";
    "~/.local/bin/extract-images" = "modules/agents-shared/config/bin/extract-images";
    "~/.local/bin/search-reddit" = "modules/agents-shared/config/bin/search-reddit";
    "~/.local/bin/search-hn" = "modules/agents-shared/config/bin/search-hn";
    "~/.local/bin/search-github" = "modules/agents-shared/config/bin/search-github";
  };
}
