{ config, myLib, ... }:
myLib.mkModule config "starship" {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  nixDotbot.links = {
    "~/.config/starship.toml" = "modules/home/starship/config/starship.toml";
  };
}
