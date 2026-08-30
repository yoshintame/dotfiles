{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "brew" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    b = "brew";
    bi = "brew install";
    bic = "brew install --cask";
    bd = "brew uninstall";
    bl = "brew list";
    bu = "brew upgrade";
    bud = "brew update";
    bs = "brew search";
    bsc = "brew search --cask";
    bp = "brew dump";
    bup = "brew update && brew upgrade && brew cleanup";
  };
}
