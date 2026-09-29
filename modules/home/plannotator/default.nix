{
  config,
  pkgs,
  myLib,
  ...
}:
let
  home = config.home.homeDirectory;
  desvio = pkgs.stdenvNoCC.mkDerivation {
    pname = "desvio";
    version = "0.1.0-unstable-2026-09-08";
    src = pkgs.fetchFromGitHub {
      owner = "cleiter";
      repo = "desvio";
      rev = "9b41261f55e50317060401a3a0c3e2c23d4af563";
      hash = "sha256-gHyD3rR6PR79qUbQIsk5fflOiVQvRSIoV0RsNvBSX6w=";
    };
    installPhase = ''
      mkdir -p $out/share/desvio $out/bin
      cp -r bin lib $out/share/desvio/
      ln -s $out/share/desvio/bin/desvio $out/bin/desvio
    '';
  };
in
myLib.mkModule config "plannotator" {
  home.packages = [ desvio ];

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
