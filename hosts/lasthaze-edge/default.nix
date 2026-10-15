{ config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./manifest.nix
  ];

  networking.hostName = "lasthaze-edge";
  system.stateVersion = "25.05";
  time.timeZone = lib.mkForce "UTC";

  nix.gc.options = "--delete-older-than 14d";
  nix.settings.min-free = 1024 * 1024 * 1024;

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.timeout = 1;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "/dev/vda";
    configurationLimit = 5;
  };

  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  networking.hosts."100.123.237.27" = [ "lasthaze-homelab" ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  sops.secrets."TAILSCALE_AUTHKEY".sopsFile = ../../secrets/lasthaze-edge/edge.yaml;
  sops.secrets."GATUS_ENV" = {
    sopsFile = ../../secrets/lasthaze-edge/edge.yaml;
    mode = "0440";
    group = "gatus-secrets";
    restartUnits = [ "gatus.service" ];
  };
  users.groups.gatus-secrets = { };
  services.tailscale = {
    useRoutingFeatures = "none";
    authKeyFile = config.sops.secrets."TAILSCALE_AUTHKEY".path;
    extraUpFlags = [
      "--advertise-tags=tag:edge"
      "--accept-dns=false"
    ];
  };

  edge = {
    secretsFile = ../../secrets/lasthaze-edge/edge.yaml;
    decoySiteFile = ../../secrets/lasthaze-edge/decoy-site.tar;
    decoy.mode = "self-steal";
    observability = {
      enable = true;
      promRemoteWriteUrl = "http://lasthaze-homelab:9090/api/v1/write";
      lokiPushUrl = "http://lasthaze-homelab:3100/loki/api/v1/push";
    };
  };

  homelab.sentinel = {
    enable = true;
    homelabAddress = "100.123.237.27";
    listenAddress = "100.98.13.73";
    environmentFile = config.sops.secrets."GATUS_ENV".path;
    backupHeartbeats.mbp = {
      tokenVariable = "GATUS_BACKUP_TOKEN_MBP";
      jobs = {
        dev-backup = "9h";
        home-backup = "14h";
        local-to-b2-copy = "13h";
        local-to-onedrive-copy = "13h";
        local-ops-check = "768h";
        b2-ops-check = "768h";
        onedrive-ops-check = "768h";
      };
    };
  };

  systemd.services.gatus.serviceConfig.SupplementaryGroups = [ "gatus-secrets" ];
}
