{
  config,
  pkgs,
  ...
}:
let
  username = "yoshintame";
  repoDir = "/var/lib/homelab-deploy/dotfiles";
in
{
  sops.secrets.deploy_key_dotfiles = {
    sopsFile = ../../secrets/homelab/deploy.yaml;
    mode = "0600";
    owner = "root";
    group = "root";
  };
  sops.secrets.deploy_key_homelab = {
    sopsFile = ../../secrets/homelab/deploy.yaml;
    mode = "0600";
    owner = "root";
    group = "root";
  };

  programs.ssh.knownHosts.github = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };

  programs.ssh.extraConfig = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile ${config.sops.secrets.deploy_key_homelab.path}
      IdentitiesOnly yes
    Host dotfiles.github.com
      HostName github.com
      User git
      IdentityFile ${config.sops.secrets.deploy_key_dotfiles.path}
      IdentitiesOnly yes
  '';

  services.tailscale.extraSetFlags = [ "--ssh" ];

  systemd.tmpfiles.rules = [ "d /var/lib/homelab-deploy 0700 root root -" ];

  systemd.services.homelab-deploy = {
    description = "Pull dotfiles + fresh homelab, rebuild the system (GitOps pull)";
    after = [
      "network-online.target"
      "sops-nix.service"
    ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      nix
      git
      openssh
      nixos-rebuild
      coreutils
    ];
    environment = {
      HOME = "/var/lib/homelab-deploy";
      GIT_TERMINAL_PROMPT = "0";
    };
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      repo="${repoDir}"
      if [ ! -d "$repo/.git" ]; then
        git clone git@dotfiles.github.com:${username}/dotfiles.git "$repo"
      fi
      cd "$repo"
      git fetch --prune origin
      git reset --hard origin/master
      git clean -fd
      nix flake update homelab
      nixos-rebuild switch --flake "$repo#lasthaze-homelab"
    '';
  };

  systemd.timers.homelab-deploy = {
    description = "Safety-net hourly homelab GitOps pull";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start homelab-deploy.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
