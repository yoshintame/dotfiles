{ config, myLib, ... }:
myLib.mkModule config "windows-paseo" {
  windows = {
    winget.packages."Paseo.Paseo" = { };

    firewall.rules.Paseo-In-TCP = {
      displayName = "Paseo daemon";
      localPort = 6767;
      interfaceAlias = "Tailscale";
      remoteAddress = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
    };
  };
}
