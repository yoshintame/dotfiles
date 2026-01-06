{
  pkgs,
  pkgs-unstable ? pkgs,
  ...
}: {
  home.packages = with pkgs; [
    pkgs-unstable.yazi

    ffmpeg
    p7zip
    jq
    poppler
    fd
    ripgrep
    fzf
    zoxide
    resvg
    imagemagick
    glow
    gtrash

    # piper.yazi dependencies
    bat
    eza
    hexyl
    sqlite

    # openers dependencies
    mediainfo
    exiftool

    nerd-fonts.symbols-only

    # TODO:
    # clipboard
    # sevenzip # instead of p7zip
  ];

  nixDotbot.links = {
    "~/.config/yazi/" = {
      path = "modules/yazi/config/**";
      glob = true;
    };

    "~/.config/yazi/scripts/" = {
      path = "modules/yazi/scripts/**";
      glob = true;
    };
  };
}
