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
myLib.mkModule config "session-reaper" {
  launchd.agents.session-reaper = {
    enable = true;
    config = {
      ProgramArguments = [
        "${home}/.local/share/mise/shims/bun"
        "${home}/.claude/skills/reset-sessions/scripts/session-reaper.ts"
        "--idle-minutes"
        "15"
      ];
      EnvironmentVariables = {
        PATH = binPath;
        HOME = home;
      };
      StartInterval = 300;
      RunAtLoad = true;
      StandardOutPath = "/tmp/session-reaper.log";
      StandardErrorPath = "/tmp/session-reaper.err";
    };
  };
}
