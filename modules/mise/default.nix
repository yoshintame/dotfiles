{
  pkgs-unstable ? pkgs,
  pkgs,
  ...
}: let
  mkMiseCli = import ../../lib/mkMiseCli.nix {
    inherit pkgs;
    mise = pkgs-unstable.mise;
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
in {
  programs.mise = {
    enable = true;
    package = pkgs-unstable.mise;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  home.packages = [dotCli];

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

  nixDotbot.links = {
    "~/.config/mise/config.toml" = "modules/mise/config/config.toml";
    "~/.config/mise/tasks/dot.toml" = "dot.toml";
  };
}
