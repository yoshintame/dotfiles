{
  pkgs,
  flakeRoot,
  hostFacts,
  ...
}:
{
  imports = [ ./manifest.nix ];

  networking.knownNetworkServices = [ "Wi-Fi" ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.builders = "@/etc/nix/machines";
  nix.settings.trusted-users = [
    "@admin"
    hostFacts.username
  ];
  nix.channel.enable = false;

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

  users.users.${hostFacts.username} = {
    name = hostFacts.username;
    home = hostFacts.homeDir;
  };

  programs.fish.enable = true;

  system.activationScripts.postActivation.text = ''
    fishPath="/run/current-system/sw/bin/fish"

    if ! grep -qxF "$fishPath" /etc/shells; then
      echo "Adding $fishPath to /etc/shells" >&2
      echo "$fishPath" >> /etc/shells
    fi

    currentShell=$(/usr/bin/dscl . -read /Users/${hostFacts.username} UserShell 2>/dev/null | awk '{print $2}')
    if [ "$currentShell" != "$fishPath" ]; then
      echo "Setting ${hostFacts.username}'s login shell to $fishPath" >&2
      /usr/bin/dscl . -change /Users/${hostFacts.username} UserShell "$currentShell" "$fishPath"
    fi
  '';

  environment.variables = hostFacts.sharedEnv;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bkp";

    users.${hostFacts.username} = {
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

      home.sessionPath = hostFacts.sharedPath;

      home.sessionVariables = hostFacts.sharedEnv;

      home.stateVersion = "25.05";
      home.username = hostFacts.username;
      home.homeDirectory = hostFacts.homeDir;

      targets.darwin.currentHostDefaults."com.apple.ImageCapture" = {
        disableHotPlug = true;
      };

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

        links = {
          "~/.config/packages" = "hosts/lasthaze-mbp/packages";
          "~/.cache/.bun/install/global/package.json" = "hosts/lasthaze-mbp/packages/package.json";
        };
      };
    };
  };
}
