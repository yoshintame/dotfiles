{pkgs, pkgs-unstable ? pkgs, ...}: {
  home.packages = [
    pkgs-unstable.mise
  ];

  nixDotbot.links = {
    "~/.config/mise/config.toml" = "modules/mise/config/config.toml";
    "~/.config/mise/tasks/dot.toml" = "dot.toml";
  };
}
