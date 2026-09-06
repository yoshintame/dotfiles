{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "claude" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    ccr = "bun ~/.claude/skills/reset-sessions/scripts/reset-sessions.ts --all";
  };

  nixLink.links = {
    "~/.claude/settings.json" = "modules/home/claude/config/settings.json";
    "~/.claude/CLAUDE.md" = "modules/home/agents-shared/config/AGENTS.md";
    "~/.claude/hooks/" = {
      path = "modules/home/agents-shared/config/hooks/**";
      glob = true;
    };
    "~/.local/bin/chrome-agent" = "modules/home/agents-shared/config/chrome-agent/cli.ts";
    "~/.local/bin/chrome-cdp" = "modules/home/agents-shared/config/chrome-cdp/cli.ts";
    "~/.local/bin/cc-fork-recover" = "modules/home/agents-shared/config/bin/cc-fork-recover";
    "~/.local/bin/clean-session-log" = "modules/home/agents-shared/config/bin/clean-session-log";
    "~/.local/bin/extract-images" = "modules/home/agents-shared/config/bin/extract-images";
    "~/.local/bin/search-reddit" = "modules/home/agents-shared/config/bin/search-reddit";
    "~/.local/bin/search-hn" = "modules/home/agents-shared/config/bin/search-hn";
    "~/.local/bin/search-github" = "modules/home/agents-shared/config/bin/search-github";
  };
}
