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
        PATH = binPath;
        HOME = home;
      };
      StartInterval = 300;
      RunAtLoad = true;
      StandardOutPath = "/tmp/cc-trace-compact.log";
      StandardErrorPath = "/tmp/cc-trace-compact.err";
    };
  };
}
