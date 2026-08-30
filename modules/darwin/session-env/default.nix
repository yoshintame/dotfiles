{
  config,
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
}
