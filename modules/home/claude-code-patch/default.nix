{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "claude-code-patch" {
  launchd.agents.claude-code-patch = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.python3}/bin/python3"
        "${config.home.homeDirectory}/.local/bin/claude-code-patch"
      ];
      WatchPaths = [ "${config.home.homeDirectory}/.vscode/extensions" ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/claude-code-patch.log";
      StandardErrorPath = "/tmp/claude-code-patch.err";
    };
  };
}
