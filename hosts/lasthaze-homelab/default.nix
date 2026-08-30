{ flakeRoot, ... }:
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
