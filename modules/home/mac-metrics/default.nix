{
  pkgs,
  config,
  lib,
  myLib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.my.mac-metrics;
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/state/mac-metrics";
  textfileDir = "${stateDir}/textfile";
  exporterAddress = "127.0.0.1:9184";

  collect = pkgs.writeShellApplication {
    name = "mac-metrics-collect";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
    ];
    text = builtins.readFile ./collect.sh;
  };

  exporter = pkgs.buildGoModule {
    pname = "mac-metrics";
    version = "0.1.0";
    src = ./exporter;
    vendorHash = null;
    meta.mainProgram = "mac-metrics";
  };

  alloyConfig = pkgs.writeText "mac-metrics.alloy" ''
    logging {
      level = "warn"
    }

    prometheus.exporter.unix "node" {
      disable_collectors = ["thermal"]

      filesystem {
        mount_points_exclude = "^/(System/Volumes/(iSCPreboot|xarts|Hardware|Preboot|Update|VM)|Volumes/.+|Users/.+)$"
      }

      textfile {
        directory = "${textfileDir}"
      }
    }

    prometheus.scrape "node" {
      targets         = prometheus.exporter.unix.node.targets
      forward_to      = [prometheus.relabel.node.receiver]
      scrape_interval = "15s"
      job_name        = "node"
    }

    prometheus.scrape "apps" {
      targets         = [{"__address__" = "${exporterAddress}"}]
      forward_to      = [prometheus.relabel.apps.receiver]
      scrape_interval = "15s"
      job_name        = "mac-apps"
    }

    prometheus.relabel "apps" {
      forward_to = [prometheus.remote_write.homelab.receiver]

      rule {
        target_label = "instance"
        replacement  = "${cfg.host}"
      }
    }

    prometheus.relabel "node" {
      forward_to = [prometheus.remote_write.homelab.receiver]

      rule {
        target_label = "job"
        replacement  = "node"
      }
    }

    prometheus.remote_write "homelab" {
      endpoint {
        url = "${cfg.remoteWriteUrl}"
      }
      external_labels = {
        host = "${cfg.host}",
      }
    }
  '';

  launchdEnv = {
    PATH = myLib.launchdPath config [ ];
    HOME = home;
  };
in
lib.recursiveUpdate
  (myLib.mkModule config "mac-metrics" {
    home.packages = [ exporter ];

    home.activation.macMetricsState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      /bin/mkdir -p "${stateDir}/alloy" "${textfileDir}"
      /bin/rm -f "${textfileDir}/browsers.prom" "${stateDir}/browsers-state.json"
    '';

    launchd.agents.mac-metrics-alloy = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe pkgs.grafana-alloy)
          "run"
          "--storage.path=${stateDir}/alloy"
          "--server.http.listen-addr=127.0.0.1:12345"
          "--disable-reporting"
          "${alloyConfig}"
        ];
        EnvironmentVariables = launchdEnv;
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/mac-metrics-alloy.log";
        StandardErrorPath = "/tmp/mac-metrics-alloy.err";
      };
    };

    launchd.agents.mac-metrics-collect = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe collect)
          textfileDir
        ];
        EnvironmentVariables = launchdEnv;
        StartInterval = 15;
        RunAtLoad = true;
        StandardOutPath = "/tmp/mac-metrics-collect.log";
        StandardErrorPath = "/tmp/mac-metrics-collect.err";
      };
    };

    launchd.agents.mac-metrics-exporter = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe exporter)
          "serve"
          "-listen"
          exporterAddress
        ];
        EnvironmentVariables = launchdEnv;
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/mac-metrics-exporter.log";
        StandardErrorPath = "/tmp/mac-metrics-exporter.err";
      };
    };
  })
  {
    options.my.mac-metrics = {
      host = mkOption { type = types.str; };
      remoteWriteUrl = mkOption { type = types.str; };
    };
  }
