{
  config,
  pkgs,
  lib,
  hostFacts,
  myLib,
  ...
}:
let
  fullEnv = hostFacts.sharedEnv // {
    PATH = builtins.concatStringsSep ":" hostFacts.sharedPath;
  };
in
myLib.mkModule config "session-env" {
  launchd.user.envVariables = fullEnv;

  launchd.user.agents.session-env = {
    serviceConfig = {
      Label = "com.yoshintame.session-env";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        (builtins.concatStringsSep " ; " (
          lib.mapAttrsToList (name: value: "launchctl setenv ${name} ${lib.escapeShellArg value}") fullEnv
        ))
      ];
      RunAtLoad = true;
      StandardErrorPath = "/tmp/session-env.err";
    };
  };

  launchd.user.agents.claude-code-patch = {
    serviceConfig = {
      Label = "com.yoshintame.claude-code-patch";
      ProgramArguments = [
        "${pkgs.python3}/bin/python3"
        "${hostFacts.homeDir}/.local/bin/claude-code-patch"
      ];
      WatchPaths = [ "${hostFacts.homeDir}/.vscode/extensions" ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/claude-code-patch.log";
      StandardErrorPath = "/tmp/claude-code-patch.err";
    };
  };
}
