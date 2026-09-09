{
  config,
  lib,
  myLib,
  ...
}:
let
  home = config.home.homeDirectory;
  user = config.home.username;
  binPath = lib.concatStringsSep ":" [
    "${home}/.local/share/mise/shims"
    "/etc/profiles/per-user/${user}/bin"
    "${home}/.nix-profile/bin"
    "/run/current-system/sw/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
in
myLib.mkModule config "claude" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    ccr = "bun ~/.claude/skills/reset-sessions/scripts/reset-sessions.ts --all";
  };

  launchd.agents.claude-settings-relink = {
    enable = true;
    config = {
      ProgramArguments = [ "${home}/.local/bin/claude-settings-relink" ];
      WatchPaths = [ "${home}/.claude/settings.json" ];
      EnvironmentVariables = {
        PATH = binPath;
        HOME = home;
      };
      RunAtLoad = true;
      StandardOutPath = "/tmp/claude-settings-relink.log";
      StandardErrorPath = "/tmp/claude-settings-relink.err";
    };
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
    "~/.local/bin/search-discourse" = "modules/home/agents-shared/config/bin/search-discourse";
    "~/.local/bin/claude-settings-relink" = "modules/home/claude/config/bin/claude-settings-relink";
  };
}
