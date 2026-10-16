{
  config,
  pkgs,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "wsl" {
  wsl = {
    enable = true;
    defaultUser = "yoshintame";
    interop = {
      register = true;
      includePath = false;
    };
  };

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  nix.settings.trusted-users = [ config.wsl.defaultUser ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      zstd
      openssl
      curl
      libffi
      libxml2
      expat
      xz
      bzip2
      sqlite
      ncurses
      readline
      icu
      libuuid
      util-linux
      glib
    ];
  };

  environment.systemPackages = [ pkgs.wget ];
}
