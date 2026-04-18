{
  pkgs,
  inputs,
  lib,
  ...
}: let
  username = "yoshintame";
  homeDir = "/Users/${username}";
  testMode = (builtins.getEnv "DOTFILES_TEST_MODE") == "1";
  rawBrewfile = builtins.readFile ./packages/Brewfile;
  filteredBrewfile =
    if testMode
    then
      lib.concatStringsSep "\n"
      (builtins.filter
        (line: !(lib.hasPrefix "cask " line) && !(lib.hasPrefix "mas " line))
        (lib.splitString "\n" rawBrewfile))
    else rawBrewfile;
  sharedEnv = {
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
  sharedPath = [
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
in {
  imports = [./macos-defaults.nix];

  nix.enable = false;
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

  programs.fish.enable = true;

  system.activationScripts.postActivation.text = ''
    fishPath="/run/current-system/sw/bin/fish"

    if ! grep -qxF "$fishPath" /etc/shells; then
      echo "Adding $fishPath to /etc/shells" >&2
      echo "$fishPath" >> /etc/shells
    fi

    currentShell=$(/usr/bin/dscl . -read /Users/${username} UserShell 2>/dev/null | awk '{print $2}')
    if [ "$currentShell" != "$fishPath" ]; then
      echo "Setting ${username}'s login shell to $fishPath" >&2
      /usr/bin/dscl . -change /Users/${username} UserShell "$currentShell" "$fishPath"
    fi
  '';

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
    };
    global.brewfile = false;
    extraConfig = filteredBrewfile;
  };

  environment.variables =
    sharedEnv
    // {
      HOMEBREW_PREFIX = "/opt/homebrew";
      HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
      HOMEBREW_REPOSITORY = "/opt/homebrew";
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_ENV_HINTS = "1";
      HOMEBREW_BUNDLE_FILE = "${homeDir}/.config/packages/Brewfile";
      HOMEBREW_BUNDLE_DUMP_NO_GO = "1";
      HOMEBREW_BUNDLE_DUMP_NO_NPM = "1";
    };

  launchd.user.envVariables =
    sharedEnv
    // {
      PATH = builtins.concatStringsSep ":" sharedPath;
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
      imports =
        [
          ./file-associations
          ../../modules/git
          ../../modules/fish
          ../../modules/gitui
          ../../modules/kitty
          ../../modules/lazygit
          ../../modules/tmux
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
        ]
        ++ lib.optional (!testMode) ../../modules/vscode;

      programs.bash.enable = true;
      programs.zsh.enable = true;

      home.sessionPath = sharedPath;

      home.sessionVariables = sharedEnv;

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
