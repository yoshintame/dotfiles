{pkgs, ...}: {
  programs.atuin = {
    enable = true;
    package = pkgs.atuin;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  nixDotbot.links = {
    "~/.config/atuin" = "modules/atuin/config";
  };
}
