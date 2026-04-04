{pkgs, ...}: {
  nixDotbot.links = {
    "~/Library/Application Support/com.colliderli.iina/" = {
      path = "modules/iina/config/**";
      glob = true;
    };
  };
}
