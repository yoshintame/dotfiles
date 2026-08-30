{
  config,
  pkgs,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "fish" {
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
    plugins = import ./plugins.nix { inherit pkgs; };
  };

  home.shellAliases = {
    md = "mkdir -p";
    ml = "ln -s";
    o = "open";
    oa = "open -a";
    oo = "open .";
    ip = "dig +short myip.opendns.com @resolver1.opendns.com";
    localip = "ipconfig getifaddr en0";
    whichis = "type -a --path";
    sp = "speedtest";
    cl = "clear";
    aliasessh = "manssh list";
  };

  home.packages = with pkgs; [
    grc
    thefuck
    fd
    ripgrep
  ];

  nixDotbot.links = {
    "~/.config/fish/" = {
      path = "modules/home/fish/config/**";
      glob = true;
    };
  };
}
