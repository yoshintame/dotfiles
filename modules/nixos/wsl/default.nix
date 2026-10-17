{
  config,
  pkgs,
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

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;

  programs.nix-ld.enable = true;

  environment.systemPackages = [ pkgs.wget ];
}
