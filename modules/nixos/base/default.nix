{
  config,
  pkgs,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "base" {
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      "yoshintame"
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "Asia/Bangkok";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    age
    ssh-to-age
    sops
    git
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 3;

  boot.kernelParams = [
    "quiet"
    "loglevel=3"
  ];

  boot.tmp.cleanOnBoot = true;

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.rp_filter" = lib.mkDefault 2;
    "net.ipv4.conf.default.rp_filter" = lib.mkDefault 2;
    "net.ipv4.tcp_syncookies" = lib.mkDefault 1;
  };
}
