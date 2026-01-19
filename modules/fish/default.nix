{
  pkgs,
  pkgs-unstable ? pkgs,
  ...
}: {
  programs.fish.enable = true;

  home.packages = with pkgs; [
    pkgs-unstable.mise
    grc
    thefuck
    eza
    bat
    fd
    ripgrep
    fzf
    gtrash
  ];

  nixDotbot.links = {
    "~/.config/fish/" = {
      path = "modules/fish/config/**";
      glob = true;
    };
  };
}
