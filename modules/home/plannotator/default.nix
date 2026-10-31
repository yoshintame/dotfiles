{
  config,
  myLib,
  ...
}:
let
  home = config.home.homeDirectory;
in
myLib.mkModule config "plannotator" {
  nixLink.links = {
    "~/.config/desvio/plannotator" = "modules/home/plannotator/config";
    "~/.local/bin/plannotator-update" = "modules/home/plannotator/update.sh";
  };

  launchd.agents.plannotator-update = {
    enable = true;
    config = {
      ProgramArguments = [ "${home}/.local/bin/plannotator-update" ];
      EnvironmentVariables = {
        PATH = myLib.launchdPath config [ "${home}/.local/bin" ];
        HOME = home;
        DESVIO_AUTO_RESOLVE = "0";
      };
      StartCalendarInterval = [
        {
          Hour = 11;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/plannotator-update.log";
      StandardErrorPath = "/tmp/plannotator-update.err";
    };
  };
}
