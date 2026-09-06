{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "tailscale" {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = lib.mkDefault "both";
  };
}
