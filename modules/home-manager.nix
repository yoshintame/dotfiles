{
  pkgs,
  lib,
  inputs,
  flakeRoot,
  myLib,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    backupFileExtension = lib.mkDefault "bkp";

    extraSpecialArgs = {
      inherit flakeRoot myLib;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    };

    sharedModules = [
      ../lib/nix-link.nix
      inputs.sops-nix.homeManagerModules.sops
      inputs.nix-stencil.homeManagerModules.default
      (
        { config, lib, ... }:
        {
          options.my.sops.ready = lib.mkOption {
            type = lib.types.bool;
            readOnly = true;
            default = builtins.pathExists config.sops.age.keyFile;
            description = "Whether the SOPS age key exists on disk at evaluation time (needs --impure).";
          };
          config = {
            sops.age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
            sops.defaultSecretsMountPoint = "${config.home.homeDirectory}/.local/state/sops-nix/secrets.d";
            stencil.enable = config.my.sops.ready;
            sops.secrets = lib.mkIf (!config.my.sops.ready) (lib.mkForce { });
            sops.templates = lib.mkIf (!config.my.sops.ready) (lib.mkForce { });
          };
        }
      )

      ./home/aerospace
      ./home/apm
      ./home/app-state
      ./home/atuin
      ./home/bat
      ./home/brew
      ./home/btop
      ./home/btt-gestures
      ./home/bun
      ./home/cc-trace
      ./home/claude
      ./home/claude-code-patch
      ./home/claude-rc
      ./home/codex
      ./home/docker
      ./home/eza
      ./home/file-associations
      ./home/fish
      ./home/fzf
      ./home/ghostty
      ./home/git
      ./home/gitui
      ./home/gtrash
      ./home/hammerspoon
      ./home/iina
      ./home/karabiner
      ./home/kitty
      ./home/lazygit
      ./home/mise
      ./home/npm
      ./home/nvim
      ./home/op
      ./home/ouch
      ./home/plannotator
      ./home/pnpm
      ./home/python
      ./home/quitall
      ./home/rclone
      ./home/resticprofile
      ./home/serena
      ./home/session-reaper
      ./home/ssh
      ./home/starship
      ./home/tig
      ./home/tmux
      ./home/uv
      ./home/vscode
      ./home/warp
      ./home/wezterm
      ./home/worktrunk
      ./home/yabai
      ./home/yazi
      ./home/zed
      ./home/zoxide
    ];
  };
}
