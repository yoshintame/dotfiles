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
}
