{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "atuin" {
  programs.atuin = {
    enable = true;
    package = pkgs.atuin;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  nixDotbot.links = {
    "~/.config/atuin" = "modules/home/atuin/config";
  };
}
