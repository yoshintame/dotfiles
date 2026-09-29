{
  config,
  lib,
  myLib,
  ...
}:
let
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/state/cc-trace";
in
myLib.mkModule config "cc-trace" {
  nixLink.links = {
    "~/.local/bin/cc-trace-compact" = "modules/home/cc-trace/config/cc-trace-compact.ts";
    "~/.local/bin/cc-trace-break" = "modules/home/cc-trace/config/cc-trace-break.ts";
  };

  home.activation.ccTraceState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /bin/mkdir -p -m 700 "${stateDir}" "${stateDir}/bodies" "${stateDir}/sessions"
  '';

  launchd.agents.cc-trace-compact = {
    enable = true;
    config = {
      ProgramArguments = [
        "${home}/.local/share/mise/shims/bun"
        "${home}/.local/bin/cc-trace-compact"
      ];
      EnvironmentVariables = {
        PATH = myLib.launchdPath config [ ];
        HOME = home;
      };
      StartInterval = 300;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cc-trace-compact.log";
      StandardErrorPath = "/tmp/cc-trace-compact.err";
    };
  };
}
