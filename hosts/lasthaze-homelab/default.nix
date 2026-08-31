{ flakeRoot, ... }:
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

  networking.firewall.interfaces = {
    tailscale0.allowedTCPPorts = [ 22 ];
    enp2s0.allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "25.05";

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  homelab.infra.traefik.enable = true;
  homelab.infra.authelia.enable = true;
  homelab.infra.cloudflared.enable = true;

  homelab.services = {
    actual = {
      enable = true;
      tailnet = true;
      tailnetPort = 8443;
    };
    archivebox.enable = false;
    paperless.enable = false;
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
