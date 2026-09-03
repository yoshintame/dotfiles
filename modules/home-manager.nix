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
      sopsRefs = import ../lib/sopsRefs.nix { inherit lib; };
    };

    sharedModules = [
      ../lib/nix-link.nix
      inputs.sops-nix.homeManagerModules.sops
      ../lib/sops-templates
      (
        { config, lib, ... }:
        {
          sops.age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        }
      )

      ./home/aerospace
      ./home/atuin
      ./home/bat
      ./home/brew
      ./home/btop
      ./home/btt-gestures
      ./home/bun
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
      ./home/pnpm
      ./home/python
      ./home/rclone
      ./home/resticprofile
      ./home/serena
      ./home/session-reaper
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
