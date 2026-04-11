{
  pkgs,
  inputs,
  ...
}: let
  username = "yoshintame";
in {
  imports = [./macos-defaults.nix];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = 6;

  security.pam.services.sudo_local.touchIdAuth = true;

  fonts.packages = with pkgs; [
    nerd-fonts.geist-mono
    nerd-fonts.fira-code
    cascadia-code
  ];

  power.sleep = {
    display = 3;
    computer = 30;
  };

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
        ./file-associations
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
        ../../modules/mise
        ../../modules/resticprofile
        ../../modules/claude
        ../../modules/codex
        ../../modules/iina
      ];

      programs.bash.enable = true;

      home.sessionVariables = {
        EDITOR = "code --wait";
        VISUAL = "code --wait";
      };

      home.stateVersion = "25.05";
      home.username = username;
      home.homeDirectory = "/Users/${username}";

      targets.darwin.currentHostDefaults."com.apple.ImageCapture" = {
        disableHotPlug = true;
      };

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

        links = {
          "~/.config/packages" = "hosts/lasthaze-mbp/packages";
          "~/.cache/.bun/install/global/package.json" = "hosts/lasthaze-mbp/packages/package.json";
        };
      };
    };
  };
}
