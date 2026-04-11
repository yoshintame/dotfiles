{pkgs, ...}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  nixDotbot.links = {
    "~/.config/starship.toml" = "modules/starship/config/starship.toml";
  };
}
