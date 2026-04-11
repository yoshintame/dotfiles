{
  pkgs,
  inputs,
  ...
}: let
  username = "yoshintame";
  homeDir = "/Users/${username}";
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
    home = homeDir;
  };

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
    };
    global.brewfile = false;
    extraConfig = builtins.readFile ./packages/Brewfile;
  };

  environment.variables = {
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
    HOMEBREW_NO_ANALYTICS = "1";
    HOMEBREW_NO_ENV_HINTS = "1";
    HOMEBREW_BUNDLE_FILE = "${homeDir}/.config/packages/Brewfile";
    GOPATH = "${homeDir}/go";
    PNPM_HOME = "${homeDir}/.local/share/pnpm";
    DOTFILES = "${homeDir}/.dotfiles";
    EDITOR = "code --wait";
    VISUAL = "code --wait";
    XDG_CONFIG_HOME = "${homeDir}/.config";
    XDG_DATA_HOME = "${homeDir}/.local/share";
    XDG_STATE_HOME = "${homeDir}/.local/state";
    XDG_CACHE_HOME = "${homeDir}/.cache";
    TRASH = "${homeDir}/.Trash";
    PLAY = "iina";
    SSH_AUTH_SOCK = "${homeDir}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
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
        ../../modules/zoxide
        ../../modules/fzf
        ../../modules/btop
        ../../modules/nvim
        ../../modules/mise
        ../../modules/resticprofile
        ../../modules/claude
        ../../modules/codex
        ../../modules/iina
      ];

      programs.bash.enable = true;
      programs.zsh.enable = true;

      home.sessionPath = [
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
        "/opt/homebrew/opt/ruby/bin"
        "/opt/homebrew/opt/curl/bin"
        "/opt/homebrew/opt/sqlite/bin"
        "${homeDir}/.local/share/mise/shims"
        "${homeDir}/.local/share/pnpm"
        "${homeDir}/.bun/bin"
        "${homeDir}/go/bin"
        "${homeDir}/.local/bin"
        "${homeDir}/bin"
      ];

      home.sessionVariables = {
        EDITOR = "code --wait";
        VISUAL = "code --wait";
        GOPATH = "${homeDir}/go";
        PNPM_HOME = "${homeDir}/.local/share/pnpm";
        DOTFILES = "${homeDir}/.dotfiles";
        XDG_CONFIG_HOME = "${homeDir}/.config";
        XDG_DATA_HOME = "${homeDir}/.local/share";
        XDG_STATE_HOME = "${homeDir}/.local/state";
        XDG_CACHE_HOME = "${homeDir}/.cache";
        TRASH = "${homeDir}/.Trash";
        PLAY = "iina";
        SSH_AUTH_SOCK = "${homeDir}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
      };

      home.stateVersion = "25.05";
      home.username = username;
      home.homeDirectory = homeDir;

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
