{
  pkgs,
  inputs,
  lib,
  ...
}: let
  username = "yoshintame";
  homeDir = "/Users/${username}";
  sharedEnv = {
    EDITOR = "code --wait";
    VISUAL = "code --wait";
    GOPATH = "${homeDir}/go";
    PNPM_HOME = "${homeDir}/.local/share/pnpm";
    DOTFILES = "${homeDir}/.dotfiles";
    OBSIDIAN_VAULT = "${homeDir}/Documents/obsidian/yoshintame";
    XDG_CONFIG_HOME = "${homeDir}/.config";
    XDG_DATA_HOME = "${homeDir}/.local/share";
    XDG_STATE_HOME = "${homeDir}/.local/state";
    XDG_CACHE_HOME = "${homeDir}/.cache";
    TRASH = "${homeDir}/.Trash";
    PLAY = "iina";
    SSH_AUTH_SOCK = "${homeDir}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };
  brewFull = builtins.getEnv "DOT_BREW_FULL" == "1";
  sharedPath = [
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/${username}/bin"
    "${homeDir}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "${homeDir}/.local/share/mise/shims"
    "${homeDir}/.local/share/pnpm"
    "${homeDir}/.bun/bin"
    "${homeDir}/go/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
  fullEnv =
    sharedEnv
    // {
      PATH = builtins.concatStringsSep ":" sharedPath;
    };

in {
  imports = [./macos-defaults.nix];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["@admin" username];
  nix.channel.enable = false;

  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    systems = ["aarch64-linux" "x86_64-linux"];
    config = {
      boot.binfmt.emulatedSystems = ["x86_64-linux"];
      virtualisation = {
        cores = 4;
        darwin-builder = {
          memorySize = 8 * 1024;
          diskSize = 40 * 1024;
        };
      };
    };
  };

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
    enable = brewFull;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
      extraFlags = ["--force-cleanup"];
    };
    global.brewfile = false;
    extraConfig = builtins.readFile ./packages/Brewfile;
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

  launchd.user.envVariables = fullEnv;

  launchd.user.agents.session-env = {
    serviceConfig = {
      Label = "com.yoshintame.session-env";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        (builtins.concatStringsSep " ; " (
          lib.mapAttrsToList
          (name: value: "launchctl setenv ${name} ${lib.escapeShellArg value}")
          fullEnv
        ))
      ];
      RunAtLoad = true;
      StandardErrorPath = "/tmp/session-env.err";
    };
  };

  launchd.user.agents.claude-code-patch = {
    serviceConfig = {
      Label = "com.yoshintame.claude-code-patch";
      ProgramArguments = [
        "${pkgs.python3}/bin/python3"
        "${homeDir}/.local/bin/claude-code-patch"
      ];
      WatchPaths = ["${homeDir}/.vscode/extensions"];
      RunAtLoad = true;
      StandardOutPath = "/tmp/claude-code-patch.log";
      StandardErrorPath = "/tmp/claude-code-patch.err";
    };
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
        ../../modules/op
        ../../modules/resticprofile
        ../../modules/rclone
        ../../modules/btt-gestures
        ../../modules/claude
        ../../modules/claude-code-patch
        ../../modules/codex
        ../../modules/serena
        ../../modules/iina
        ../../modules/worktrunk
      ];

      programs.bash.enable = true;
      programs.zsh.enable = true;
      programs.zsh.envExtra = ''
        autoload -Uz add-zsh-hook
        _vtb_tz() {
          case "$PWD" in
            "$HOME"/Development/work/vtb/*) export TZ=Europe/Moscow ;;
            *) unset TZ ;;
          esac
        }
        add-zsh-hook chpwd _vtb_tz
        _vtb_tz
      '';

      home.sessionPath = sharedPath;

      home.sessionVariables = sharedEnv;

      home.stateVersion = "25.05";
      home.username = username;
      home.homeDirectory = homeDir;

      targets.darwin.currentHostDefaults."com.apple.ImageCapture" = {
        disableHotPlug = true;
      };

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
