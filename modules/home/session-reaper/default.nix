{
  config,
  myLib,
  ...
}:
let
  home = config.home.homeDirectory;
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
        PATH = myLib.launchdPath config [ ];
        HOME = home;
      };
      StartInterval = 300;
      RunAtLoad = true;
      StandardOutPath = "/tmp/session-reaper.log";
      StandardErrorPath = "/tmp/session-reaper.err";
    };
  };
}
