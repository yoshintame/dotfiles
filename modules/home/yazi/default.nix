{
  config,
  pkgs,
  pkgs-unstable ? pkgs,
  myLib,
  ...
}:
myLib.mkModule config "yazi" {
  home.packages = with pkgs; [
    pkgs-unstable.yazi

    ffmpeg
    _7zz
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
  ];

  nixDotbot.links = {
    "~/.config/yazi/" = {
      path = "modules/home/yazi/config/**";
      glob = true;
    };

    "~/.config/yazi/scripts/" = {
      path = "modules/home/yazi/scripts/**";
      glob = true;
    };
  };
}
