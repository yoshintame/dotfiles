{
  pkgs,
  config,
  lib,
  myLib,
  ...
}:
let
  stateDir = "${config.xdg.stateHome}/agent-telemetry";

  fileExporter = signal: {
    path = "${stateDir}/${signal}.jsonl";
    format = "json";
    rotation = {
      max_megabytes = 100;
      max_backups = 0;
      localtime = true;
    };
  };

  collectorConfig = (pkgs.formats.yaml { }).generate "agent-telemetry.yaml" {
    receivers.otlp.protocols = {
      grpc.endpoint = "127.0.0.1:4317";
      http.endpoint = "127.0.0.1:4318";
    };
    processors.batch = { };
    exporters = {
      "file/logs" = fileExporter "logs";
      "file/traces" = fileExporter "traces";
      "file/metrics" = fileExporter "metrics";
    };
    service = {
      telemetry.metrics.level = "none";
      pipelines = lib.genAttrs [ "logs" "traces" "metrics" ] (signal: {
        receivers = [ "otlp" ];
        processors = [ "batch" ];
        exporters = [ "file/${signal}" ];
      });
    };
  };
in
myLib.mkModule config "agent-telemetry" {
  home.activation.agentTelemetryState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /bin/mkdir -p -m 700 "${stateDir}"
  '';

  launchd.agents.agent-telemetry = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe' pkgs.opentelemetry-collector-contrib "otelcol-contrib")
        "--config=${collectorConfig}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/agent-telemetry.log";
      StandardErrorPath = "/tmp/agent-telemetry.err";
    };
  };
}
