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
  stateDir = "${config.xdg.stateHome}/mac-metrics";
  exporterAddress = "127.0.0.1:9184";

  exporter = pkgs.buildGoModule {
    pname = "mac-metrics";
    version = "0.1.0";
    src = ./exporter;
    vendorHash = null;
    meta.mainProgram = "mac-metrics";
  };

  agents = {
    alloy = {
      ProgramArguments = [
        (lib.getExe pkgs.grafana-alloy)
        "run"
        "--storage.path=${stateDir}/alloy"
        "--server.http.listen-addr=127.0.0.1:12345"
        "--disable-reporting"
        "${./mac-metrics.alloy}"
      ];
      EnvironmentVariables = {
        MAC_METRICS_HOST = cfg.host;
        MAC_METRICS_EXPORTER_ADDRESS = exporterAddress;
        MAC_METRICS_REMOTE_WRITE_URL = "http://${cfg.prometheus.host}:${toString cfg.prometheus.port}/api/v1/write";
      };
    };
    exporter.ProgramArguments = [
      (lib.getExe exporter)
      "serve"
      "-listen"
      exporterAddress
    ];
  };
in
lib.recursiveUpdate
  (myLib.mkModule config "mac-metrics" {
    home.packages = [ exporter ];

    launchd.agents = lib.mapAttrs' (
      name: agent:
      lib.nameValuePair "mac-metrics-${name}" {
        enable = true;
        config = agent // {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/mac-metrics-${name}.log";
          StandardErrorPath = "/tmp/mac-metrics-${name}.err";
        };
      }
    ) agents;
  })
  {
    options.my.mac-metrics = {
      host = mkOption {
        type = types.str;
        description = "Value of the host label on every series this Mac pushes.";
      };
      prometheus = mkOption {
        type = types.submodule {
          options = {
            host = mkOption { type = types.str; };
            port = mkOption { type = types.port; };
          };
        };
        description = "Prometheus that accepts remote write from this Mac.";
      };
    };
  }
