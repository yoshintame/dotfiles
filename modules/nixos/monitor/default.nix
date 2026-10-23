{
  config,
  lib,
  myLib,
  inputs,
  ...
}:
let
  inherit (lib) mkOption types;
  contract = inputs.homelab.lib.monitoringTargets { inherit lib; };
  cfg = config.my.monitor;
  port = 8080;

  alert =
    target:
    {
      type = "telegram";
      "failure-threshold" = 3;
      "success-threshold" = 2;
      "send-on-resolved" = true;
    }
    // lib.optionalAttrs (target.topic != null) {
      "provider-override"."topic-id" = toString cfg.telegram.topics.${target.topic};
    };
  mkEndpoint = probe: {
    inherit (probe)
      name
      group
      url
      conditions
      interval
      ;
    alerts = [ (alert probe) ];
  };
  mkHeartbeat = source: heartbeat: {
    inherit (heartbeat) name group;
    token = "\${${source.tokenVariable}}";
    heartbeat = { inherit (heartbeat) interval; };
    alerts = [
      (
        alert heartbeat
        // {
          "failure-threshold" = 1;
          "success-threshold" = 1;
        }
      )
    ];
  };

  sources = lib.attrValues cfg.sources;
  endpoints = lib.concatMap (s: map mkEndpoint (lib.attrValues s.targets.probes)) sources;
  heartbeats = lib.concatMap (s: map (mkHeartbeat s) (lib.attrValues s.targets.heartbeats)) sources;
  keys = map (e: "${e.group}_${e.name}") (endpoints ++ heartbeats);
  duplicateKeys = lib.unique (lib.filter (k: lib.count (x: x == k) keys > 1) keys);
  unknownTopics = lib.concatLists (
    lib.mapAttrsToList (
      source: s:
      map (t: "${source}.${t.name}") (
        lib.filter (t: t.topic != null && !(cfg.telegram.topics ? ${t.topic})) (
          lib.attrValues s.targets.probes ++ lib.attrValues s.targets.heartbeats
        )
      )
    ) cfg.sources
  );
in
lib.recursiveUpdate
  (myLib.mkModule config "monitor" {
    assertions = [
      {
        assertion = lib.versionAtLeast config.services.gatus.package.version "5.33.0";
        message = "my.monitor requires Gatus 5.33.0 or newer.";
      }
      {
        assertion = config.services.gatus.environmentFile != null;
        message = "my.monitor needs services.gatus.environmentFile with GATUS_TELEGRAM_TOKEN and the source token variables.";
      }
      {
        assertion = duplicateKeys == [ ];
        message = "my.monitor: targets share the Gatus keys ${lib.concatStringsSep ", " duplicateKeys}.";
      }
      {
        assertion = unknownTopics == [ ];
        message = "my.monitor: targets ${lib.concatStringsSep ", " unknownTopics} name topics missing from my.monitor.telegram.topics.";
      }
    ]
    ++ lib.mapAttrsToList (name: s: {
      assertion = s.targets.privateHosts == [ ] || s.address != null;
      message = "my.monitor.sources.${name}: private hosts resolve only through the source address.";
    }) cfg.sources
    ++ lib.mapAttrsToList (name: s: {
      assertion = s.targets.heartbeats == { } || s.tokenVariable != null;
      message = "my.monitor.sources.${name}: heartbeats need the source tokenVariable.";
    }) cfg.sources;

    networking.hosts = lib.mkMerge (
      map (s: lib.optionalAttrs (s.address != null) { ${s.address} = s.targets.privateHosts; }) sources
    );

    services.gatus = {
      enable = true;
      settings = {
        metrics = true;
        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/data.db";
          "maximum-number-of-results" = 100;
        };
        web = {
          address = cfg.listenAddress;
          inherit port;
        };
        alerting.telegram = {
          token = "\${GATUS_TELEGRAM_TOKEN}";
          id = toString cfg.telegram.chatId;
          "topic-id" = toString cfg.telegram.topics.${cfg.telegram.defaultTopic};
        };
        inherit endpoints;
        "external-endpoints" = heartbeats;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
    systemd.services.gatus = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        RestartSec = "5s";
        MemoryHigh = "100M";
        MemoryMax = "150M";
      };
    };
  })
  {
    options.my.monitor = {
      listenAddress = mkOption { type = types.str; };
      address = mkOption {
        type = types.submodule {
          options = {
            host = mkOption { type = types.str; };
            port = mkOption { type = types.port; };
          };
        };
        readOnly = true;
        default = {
          host = config.networking.hostName;
          inherit port;
        };
      };
      telegram = {
        chatId = mkOption { type = types.int; };
        topics = mkOption { type = types.attrsOf types.int; };
        defaultTopic = mkOption { type = types.enum (lib.attrNames cfg.telegram.topics); };
      };
      sources = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              targets = mkOption { type = contract.targets; };
              address = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              tokenVariable = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
            };
          }
        );
        default = { };
      };
    };
  }
