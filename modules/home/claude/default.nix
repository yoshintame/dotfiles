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
    "~/.claude/agents" = "modules/home/claude/config/agents";
    "~/Development/CLAUDE.md" = "modules/home/claude/config/dev/CLAUDE.md";
    "~/.local/share/worktrees/CLAUDE.md" = "modules/home/claude/config/dev/CLAUDE.md";
    "~/.paseo/worktrees/CLAUDE.md" = "modules/home/claude/config/dev/CLAUDE.md";
    "~/.claude/hooks/" = {
      path = "modules/home/agents-shared/config/hooks/**";
      glob = true;
    };
    "~/.local/bin/chrome-agent" = "modules/home/agents-shared/config/chrome-agent/cli.ts";
    "~/.local/bin/chrome-cdp" = "modules/home/agents-shared/config/chrome-cdp/cli.ts";
    "~/.local/bin/chrome-devtools" = "modules/home/agents-shared/config/bin/chrome-devtools";
    "~/.config/cd4a/config.json" = "modules/home/agents-shared/config/chrome-cdp/cd4a.json";
    "~/.local/bin/cc-fork-recover" = "modules/home/agents-shared/config/bin/cc-fork-recover";
    "~/.local/bin/clean-session-log" = "modules/home/agents-shared/config/bin/clean-session-log";
    "~/.local/bin/extract-images" = "modules/home/agents-shared/config/bin/extract-images";
  };
}
