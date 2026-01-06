{pkgs, ...}: {
  home.packages = [
    pkgs.starship
  ];

  nixDotbot.links = {
    "~/.config/starship.toml" = "modules/starship/config/starship.toml";
  };
}
