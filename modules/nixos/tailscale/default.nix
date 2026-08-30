{ config, myLib, ... }:
myLib.mkModule config "tailscale" {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };
}
