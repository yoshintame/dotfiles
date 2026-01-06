{pkgs, ...}: {
  nixDotbot.links = {
    "~/.hammerspoon/" = {
      path = "modules/hammerspoon/config/**";
      glob = true;
    };
  };
}
