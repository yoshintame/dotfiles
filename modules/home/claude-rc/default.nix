{
  config,
  myLib,
  ...
}:
let
  home = config.home.homeDirectory;
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
        PATH = myLib.launchdPath config [ ];
        HOME = home;
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/claude-rc.log";
      StandardErrorPath = "/tmp/claude-rc.err";
    };
  };
}
