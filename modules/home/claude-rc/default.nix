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
myLib.mkModule config "claude-rc" {
  launchd.agents.claude-rc = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/claude"
        "remote-control"
        "--spawn=same-dir"
      ];
      WorkingDirectory = "${home}/Documents/obsidian/yoshintame";
      EnvironmentVariables = {
        PATH = binPath;
        HOME = home;
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/claude-rc.log";
      StandardErrorPath = "/tmp/claude-rc.err";
    };
  };
}
