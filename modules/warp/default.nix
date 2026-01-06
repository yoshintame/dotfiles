{pkgs, ...}: {
  nixDotbot.links = {
    "~/.warp/" = {
      path = "modules/warp/config/**";
      glob = true;
    };
  };
}
