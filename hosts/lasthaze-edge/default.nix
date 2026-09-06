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

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.timeout = 1;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "/dev/vda";
  };

  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  sops.secrets."TAILSCALE_AUTHKEY".sopsFile = ../../secrets/lasthaze-edge/edge.yaml;
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
  };
}
