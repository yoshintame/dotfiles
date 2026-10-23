{
  pkgs-unstable ? pkgs,
  pkgs,
  config,
  lib,
  myLib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.my.resticprofile;
  heartbeatGroup = "backup";
  heartbeatPrefix = "mbp";
  heartbeatIntervals = {
    dev.backup = "9h";
    home.backup = "14h";
    vault.backup = "9h";
    local-to-b2.copy = "13h";
    local-to-onedrive.copy = "13h";
    local-to-gdrive.copy = "13h";
    local-ops = {
      forget = "216h";
      check = "768h";
    };
    b2-ops.check = "768h";
    onedrive-ops.check = "768h";
    gdrive-ops.check = "768h";
  };
  mkMiseCli = import ../../../lib/mkMiseCli.nix {
    inherit pkgs;
    inherit (pkgs-unstable) mise;
  };

  rpCli = mkMiseCli { name = "rp"; };
  home = config.home.homeDirectory;
in
lib.recursiveUpdate
  (myLib.mkModule config "resticprofile" {
    home.packages = [ rpCli ];

    my.resticprofile.monitoringTargets.heartbeats = lib.concatMapAttrs (
      profile:
      lib.mapAttrs' (
        command: interval:
        lib.nameValuePair "${heartbeatPrefix}-${profile}-${command}" {
          group = heartbeatGroup;
          inherit interval;
          topic = "backups";
        }
      )
    ) heartbeatIntervals;

    nixLink.links = {
      "~/.config/resticprofile/logrotate.conf" = "modules/home/resticprofile/config/logrotate.conf";
      "~/.config/mise/tasks/rp.toml" = "modules/home/resticprofile/config/rp.toml";
    };

    sopsTemplates.render = {
      "~/.config/resticprofile/profiles.yaml" = {
        template = ./config/profiles.tmpl.yaml;
        secretsFile = ./secrets.yaml;
        vars.GATUS_BACKUP_ENDPOINT = "http://${cfg.monitor.host}:${toString cfg.monitor.port}/api/v1/endpoints/${heartbeatGroup}_${heartbeatPrefix}";
      };
      "~/.config/resticprofile/hc.env" = {
        template = ./config/hc.env.tmpl;
        secretsFile = ./secrets.yaml;
      };
      "~/.config/resticprofile/b2.env" = {
        template = ./config/b2.env.tmpl;
        secretsFile = ./secrets.yaml;
      };
      "~/.config/resticprofile/repo.key" = {
        template = ./config/repo.key.tmpl;
        secretsFile = ./secrets.yaml;
      };
    };

    launchd.agents.resticprofile-logrotate = {
      enable = true;
      config = {
        ProgramArguments = [
          "/opt/homebrew/sbin/logrotate"
          "--state"
          "${home}/.local/share/resticprofile/logrotate.state"
          "${home}/.config/resticprofile/logrotate.conf"
        ];
        EnvironmentVariables = {
          PATH = myLib.launchdPath config [ ];
          HOME = home;
        };
        StartCalendarInterval = [
          {
            Hour = 7;
            Minute = 0;
          }
        ];
        ProcessType = "Background";
        LowPriorityIO = true;
        StandardOutPath = "/tmp/resticprofile-logrotate.log";
        StandardErrorPath = "/tmp/resticprofile-logrotate.err";
      };
    };
  })
  {
    options.my.resticprofile = {
      monitor = mkOption {
        type = types.submodule {
          options = {
            host = mkOption { type = types.str; };
            port = mkOption { type = types.port; };
          };
        };
      };
      monitoringTargets = mkOption {
        type = types.raw;
        default = { };
        internal = true;
      };
    };
  }
