{
  flakeRoot,
  pkgs,
  config,
  ...
}:
let
  username = "yoshintame";
  homeDir = "/home/${username}";
in
{
  imports = [
    ./hardware-configuration.nix
    ./manifest.nix
  ];

  networking.hostName = "lasthaze-homelab";
  networking.networkmanager.enable = true;

  system.stateVersion = "25.05";

  virtualisation.docker.enable = true;

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  homelab.services = {
    actual.enable = true;
    archivebox.enable = false;
    paperless.enable = false;
  };

  systemd.services.actual-tailscale-serve = {
    description = "Expose Actual over the tailnet (tailscale serve, HTTP)";
    after = [
      "tailscaled.service"
      "arion-homelab.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --http=80 http://127.0.0.1:${toString config.homelab.services.actual.port}";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --http=80 off";
    };
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
