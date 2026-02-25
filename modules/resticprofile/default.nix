{
  pkgs,
  lib,
  flakeRoot,
  ...
}: {
  nixDotbot.links = {
    "~/.config/resticprofile/profiles.yaml" = "modules/resticprofile/config/profiles.yaml";
  };
}
