{
  pkgs,
  inputs,
  ...
}: let
  username = "yoshintame";
in {
  imports = [];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = 6;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bkp";

    users.${username} = {
      pkgs,
      flakeRoot,
      ...
    }: {
      imports = [
        ../../modules/git
        ../../modules/fish
        ../../modules/gitui
        ../../modules/kitty
        ../../modules/lazygit
        ../../modules/tmux
        ../../modules/vscode
        ../../modules/wezterm
        ../../modules/warp
        ../../modules/yazi
        ../../modules/hammerspoon
        ../../modules/ghostty
        ../../modules/karabiner
        ../../modules/aerospace
        ../../modules/atuin
        ../../modules/bat
        ../../modules/starship
        ../../modules/btop
        ../../modules/nvim
      ];

      home.stateVersion = "25.05";
      home.username = username;
      home.homeDirectory = "/Users/${username}";

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

        links = {
          "~/.config/packages" = "os/macos/packages";
          "~/.local/share/pnpm/global/5/package.json" = "os/macos/packages/package.json";
        };
      };
    };
  };
}
