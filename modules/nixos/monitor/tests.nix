{
  inputs,
  lib,
  myLib,
}:
let
  eval =
    sources: extra:
    (inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs myLib; };
      modules = [
        ./.
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          system.stateVersion = "25.05";
          networking.hostName = "watchtower";
          services.gatus = {
            package = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.gatus;
            environmentFile = "/dev/null";
          };
          my.monitor = {
            enable = true;
            listenAddress = "127.0.0.1";
            telegram = {
              chatId = -1;
              topics = {
                monitor = 1;
                backups = 6;
              };
              defaultTopic = "monitor";
            };
            inherit sources;
          };
        }
        extra
      ];
    }).config;

  sample = {
    lab = {
      address = "100.64.0.1";
      tokenVariable = "LAB_TOKEN";
      targets = {
        probes.web = {
          group = "lab";
          url = "https://web.lab/";
          conditions = [ "[STATUS] < 400" ];
        };
        heartbeats.alerting = {
          group = "heartbeat";
          interval = "10m";
        };
        privateHosts = [
          "web.lab"
          "lab"
        ];
      };
    };
    mac = {
      tokenVariable = "MAC_TOKEN";
      targets.heartbeats.mac-dev-backup = {
        group = "backup";
        interval = "9h";
        topic = "backups";
      };
    };
  };
  cfg = eval sample { };
  inherit (cfg.services.gatus) settings;

  expect = name: actual: expected: { inherit name actual expected; };
  failedMessages = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  rejects =
    name: fragment: sources:
    expect "rejects: ${name}" (lib.any (lib.hasInfix fragment) (
      failedMessages (eval sources { })
    )) true;
in
[
  (expect "probes alert on the default topic after three failures" settings.endpoints [
    {
      name = "web";
      group = "lab";
      url = "https://web.lab/";
      conditions = [ "[STATUS] < 400" ];
      interval = "60s";
      alerts = [
        {
          type = "telegram";
          "failure-threshold" = 3;
          "success-threshold" = 2;
          "send-on-resolved" = true;
        }
      ];
    }
  ])
  (expect "the default topic is named in the telegram map" settings.alerting.telegram."topic-id" "1")
  (expect "heartbeats take the source token and override the topic they name"
    (map (e: {
      inherit (e) name token;
      inherit (e.heartbeat) interval;
      alert = lib.head e.alerts;
    }) settings."external-endpoints")
    [
      {
        name = "alerting";
        token = "\${LAB_TOKEN}";
        interval = "10m";
        alert = {
          type = "telegram";
          "failure-threshold" = 1;
          "success-threshold" = 1;
          "send-on-resolved" = true;
        };
      }
      {
        name = "mac-dev-backup";
        token = "\${MAC_TOKEN}";
        interval = "9h";
        alert = {
          type = "telegram";
          "failure-threshold" = 1;
          "success-threshold" = 1;
          "send-on-resolved" = true;
          "provider-override"."topic-id" = "6";
        };
      }
    ]
  )
  (expect "private hosts resolve through the source address" cfg.networking.hosts."100.64.0.1" [
    "web.lab"
    "lab"
  ])
  (expect "the monitor exports where producers reach it" cfg.my.monitor.address {
    host = "watchtower";
    port = 8080;
  })
  (rejects "private hosts without a source address" "private hosts resolve only through" (
    sample // { lab = removeAttrs sample.lab [ "address" ]; }
  ))
  (rejects "heartbeats without a token variable" "heartbeats need the source tokenVariable" (
    sample // { mac = removeAttrs sample.mac [ "tokenVariable" ]; }
  ))
  (rejects "two sources with one Gatus key" "share the Gatus keys lab_web" (
    sample // { twin.targets.probes.web = sample.lab.targets.probes.web; }
  ))
  (rejects "a topic missing from the telegram map" "targets mac.mac-dev-backup name topics missing" (
    lib.recursiveUpdate sample { mac.targets.heartbeats.mac-dev-backup.topic = "nope"; }
  ))
]
