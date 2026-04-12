{pkgs, lib, ...}: {
  imports = [
    ./aliases.nix
    ./abbrs.nix
    ./plugins.nix
  ];

  programs.bash = {
    enable = true;
    initExtra = lib.mkIf pkgs.stdenv.isLinux ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z $BASH_EXECUTION_STRING ]]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = "set fish_greeting";
    functions = {
      mb = {
        description = "Create a .bak copy of a file";
        body = ''cp -- "$argv[1]" "$argv[1].bak"'';
      };
      rb = {
        description = "Restore a file from a .bak file";
        body = ''
          set original (echo $argv[1] | sed 's/\.bak$//')
          mv -- $argv[1] $original
        '';
      };
    };
  };

  home.packages = with pkgs; [
    grc
    thefuck
    eza
    bat
    fd
    ripgrep
    gtrash
  ];

  nixDotbot.links = {
    "~/.config/fish/" = {
      path = "modules/fish/config/**";
      glob = true;
    };
  };
}
