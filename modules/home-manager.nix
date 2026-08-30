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
      ./home/btop
      ./home/btt-gestures
      ./home/claude
      ./home/claude-code-patch
      ./home/codex
      ./home/file-associations
      ./home/fish
      ./home/fzf
      ./home/ghostty
      ./home/git
      ./home/gitui
      ./home/hammerspoon
      ./home/iina
      ./home/karabiner
      ./home/kitty
      ./home/lazygit
      ./home/mise
      ./home/nvim
      ./home/op
      ./home/rclone
      ./home/resticprofile
      ./home/serena
      ./home/starship
      ./home/tmux
      ./home/vscode
      ./home/warp
      ./home/wezterm
      ./home/worktrunk
      ./home/yabai
      ./home/yazi
      ./home/zoxide
    ];
  };
}
