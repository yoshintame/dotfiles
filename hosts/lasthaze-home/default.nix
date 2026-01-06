{
  pkgs,
  flakeRoot,
  ...
}: let
  username = "yoshintame";
in {
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
  ];

  home.stateVersion = "25.05";
  home.username = username;
  home.homeDirectory = "/home/${username}";

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
}
