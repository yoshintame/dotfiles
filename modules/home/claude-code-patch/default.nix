{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "claude-code-patch" {
  nixDotbot.links = {
    "~/.local/bin/claude-code-patch" = "modules/home/claude-code-patch/config/patch.py";
  };

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
