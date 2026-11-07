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
    local-to-homelab.copy = "13h";
    local-ops = {
      forget = "216h";
      check = "768h";
    };
  };
  mkMiseCli = import ../../../lib/mkMiseCli.nix {
    inherit pkgs;
    inherit (pkgs-unstable) mise;
  };

  rpCli = mkMiseCli { name = "rp"; };
  endpoint.options = {
    host = mkOption { type = types.str; };
    port = mkOption { type = types.port; };
  };
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

    stencil.files = {
      "~/.config/resticprofile/profiles.yaml" = {
        template = ./config/profiles.tmpl.yaml;
        sopsFile = ./secrets.yaml;
        vars = {
          gatusBackupEndpoint = "http://${cfg.monitor.host}:${toString cfg.monitor.port}/api/v1/endpoints/${heartbeatGroup}_${heartbeatPrefix}";
          appState = lib.getExe' config.home.path "app-state";
          hubRepository = "rest:http://${cfg.hub.host}:${toString cfg.hub.port}/${cfg.hub.client}/mac";
        };
      };
      "~/.config/resticprofile/homelab.env" = {
        template = ./config/homelab.env.tmpl;
        sopsFile = ./secrets.yaml;
        vars.hubClient = cfg.hub.client;
      };
      "~/.config/resticprofile/hc.env" = {
        template = ./config/hc.env.tmpl;
        sopsFile = ./secrets.yaml;
      };
      "~/.config/resticprofile/b2.env" = {
        template = ./config/b2.env.tmpl;
        sopsFile = ./secrets.yaml;
      };
      "~/.config/resticprofile/repo.key" = {
        template = ./config/repo.key.tmpl;
        sopsFile = ./secrets.yaml;
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
      monitor = mkOption { type = types.submodule endpoint; };
      hub = mkOption {
        type = types.submodule [
          endpoint
          { options.client = mkOption { type = types.str; }; }
        ];
      };
      monitoringTargets = mkOption {
        type = types.raw;
        default = { };
        internal = true;
      };
    };
  }
