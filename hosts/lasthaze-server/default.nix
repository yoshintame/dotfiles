{
  pkgs,
  flakeRoot,
  ...
}: let
  username = "yoshintame";
  homeDir = "/home/${username}";
in {
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./networking.nix
    ./users.nix
    ./services/sops-age-key.nix
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    trusted-users = ["root" username];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "25.05";

  time.timeZone = "Asia/Bangkok";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    age
    ssh-to-age
    sops
    git
  ];

  home-manager.users.${username} = {
    pkgs,
    flakeRoot,
    ...
  }: {
    imports = [
      ../../modules/git
      ../../modules/fish
      ../../modules/gitui
      ../../modules/lazygit
      ../../modules/tmux
      ../../modules/yazi
      ../../modules/atuin
      ../../modules/bat
      ../../modules/starship
      ../../modules/btop
      ../../modules/nvim
      ../../modules/mise
      ../../modules/fzf
      ../../modules/zoxide
    ];

    programs.bash.enable = true;

    home.stateVersion = "25.05";
    home.username = username;
    home.homeDirectory = homeDir;

    sopsTemplates.dotfilesDir = flakeRoot;

    nixDotbot = {
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
      clean = ["~/.dotfiles" "~/.config"];
    };
  };
}
