{pkgs-unstable ? pkgs, pkgs, ...}: {
  programs.mise = {
    enable = true;
    package = pkgs-unstable.mise;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  nixDotbot.links = {
    "~/.config/mise/config.toml" = "modules/mise/config/config.toml";
    "~/.config/mise/tasks/dot.toml" = "dot.toml";
  };
}
