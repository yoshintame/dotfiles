{
  pkgs-unstable ? pkgs,
  pkgs,
  config,
  lib,
  myLib,
  ...
}:
let
  mkMiseCli = import ../../../lib/mkMiseCli.nix {
    inherit pkgs;
    inherit (pkgs-unstable) mise;
  };

  dotCli = mkMiseCli {
    name = "dot";
    specials = [
      {
        sub = "go";
        help = "cd $DOTFILES (shell-only, use fish function)";
        run = ''echo "dot go: shell-bound, run:  cd \"$DOTFILES\"" >&2; exit 2'';
      }
    ];
  };
in
myLib.mkModule config "mise" {
  programs.mise = {
    enable = true;
    package = pkgs-unstable.mise;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  home.packages = [ dotCli ];

  programs.fish.functions.dot = {
    description = "Dotfiles management (fish UX wrapper over `dot` binary)";
    body = ''
      if test (count $argv) -gt 0; and test "$argv[1]" = "go"
          cd $DOTFILES
          return
      end
      command dot $argv
    '';
  };

  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    de = "dot edit";
    dg = "dot go";
    dl = "dot link";
    dco = "dot config";
    dr = "dot rebuild";
    dpb = "dot proxy-bindings";
    dbg = "dot btt-gestures";
    ddp = "dot dump-packages";
    dbak = "dot bootstrap-age-key";
    dbs = "dot bootstrap-ssh";
    dsb = "dot sops-bootstrap";
  };

  nixLink.links = {
    "~/.config/mise/config.toml" = "modules/home/mise/config/config.toml";
    "~/.config/mise/tasks/dot.toml" = "dot.toml";
  };
}
