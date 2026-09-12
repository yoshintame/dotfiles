{ flakeRoot, pkgs, ... }:
let
  username = "yoshintame";
  homeDir = "/home/${username}";
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./deploy.nix
    ./manifest.nix
  ];

  networking.hostName = "lasthaze-homelab";
  networking.networkmanager.enable = true;
  networking.useNetworkd = false;

  systemd.services.wake-on-lan-enp2s0 = {
    description = "Arm Wake-on-LAN (magic packet) on enp2s0";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ethtool}/bin/ethtool -s enp2s0 wol g";
    };
  };

  networking.firewall.interfaces = {
    tailscale0 = {
      allowedTCPPorts = [
        22
        53
        80
        443
        3001
      ];
      allowedUDPPorts = [ 53 ];
    };
    enp2s0 = {
      allowedTCPPorts = [
        22
        53
        80
        443
      ];
      allowedUDPPorts = [ 53 ];
    };
  };

  services.tailscale.extraSetFlags = [
    "--advertise-routes=192.168.1.48/32"
    "--advertise-tags=tag:homelab"
  ];

  system.stateVersion = "25.05";

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  homelab.infra.traefik.enable = true;
  homelab.infra.authelia.enable = true;
  homelab.infra.cloudflared.enable = true;
  homelab.infra.adguard.enable = true;
  homelab.monitoring.enable = true;

  homelab.services = {
    actual.enable = true;
    archivebox.enable = false;
    paperless.enable = false;
    postgres.enable = true;
    powersync.enable = true;
  };

  home-manager.users.${username} = {
    programs.bash.enable = true;

    home.stateVersion = "25.05";
    home.username = username;
    home.homeDirectory = homeDir;

    nixLink = {
      enable = true;
      dotfilesDir = flakeRoot;
      defaults = {
        link = {
          relink = true;
          create = true;
          force = true;
        };
        clean = {
          recursive = true;
        };
      };
      clean = [
        "~/.dotfiles"
        "~/.config"
      ];
    };
  };
}
