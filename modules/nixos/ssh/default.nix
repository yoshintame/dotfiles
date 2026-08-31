{ config, myLib, ... }:
myLib.mkModule config "ssh" {
  networking.firewall.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      MaxAuthTries = 3;
    };
  };
}
