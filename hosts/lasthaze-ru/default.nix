{ config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./manifest.nix
  ];

  networking.hostName = "lasthaze-ru";
  system.stateVersion = "25.05";
  time.timeZone = lib.mkForce "UTC";

  boot = {
    growPartition = true;
    kernel.sysctl = {
      "net.ipv4.conf.all.rp_filter" = lib.mkForce 2;
      "net.ipv4.conf.default.rp_filter" = lib.mkForce 2;
    };
    loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = false;
      timeout = 1;
      grub = {
        enable = true;
        efiSupport = false;
        configurationLimit = 5;
      };
    };
  };

  fileSystems."/".autoResize = true;

  nix.gc.options = lib.mkForce "--delete-older-than 14d";

  services.qemuGuest.enable = true;

  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";
    useSystemdActivation = true;
    secrets."TAILSCALE_AUTHKEY" = {
      sopsFile = ../../secrets/lasthaze-ru/connector.yaml;
      mode = "0400";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  services.tailscale = {
    useRoutingFeatures = "server";
    authKeyFile = config.sops.secrets."TAILSCALE_AUTHKEY".path;
    extraUpFlags = [
      "--advertise-connector"
      "--advertise-tags=tag:ru-exit"
      "--accept-dns=false"
    ];
  };
}
