{
  config,
  pkgs,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "eza" {
  home.packages = [
    pkgs.eza
  ];

  home.shellAliases = {
    l = "eza -a --group --header --group-directories-first --git --icons --hyperlink";
    la = "eza -a --group --header --group-directories-first --git --icons --oneline --hyperlink";
    ll = "eza -a --group --header --group-directories-first --git --icons --long --hyperlink";
    lo = "eza -a --group --header --group-directories-first --git --icons --oneline --hyperlink";
    lt = "eza -a --group --header --group-directories-first --git --icons --tree --hyperlink";
    lt1 = "eza -a --group --header --group-directories-first --git --icons --tree --level=1 --hyperlink";
    lt2 = "eza -a --group --header --group-directories-first --git --icons --tree --level=2 --hyperlink";
    lt3 = "eza -a --group --header --group-directories-first --git --icons --tree --level=3 --hyperlink";
  };

  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    ltl = "lt --level";
  };
}
