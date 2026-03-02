{
  pkgs,
  lib,
  flakeRoot,
  ...
}: {
  nixDotbot.links = {
    "~/.config/resticprofile/profiles.yaml" = "modules/resticprofile/config/profiles.yaml";
    "~/.config/resticprofile/justfile" = "modules/resticprofile/config/justfile";
    "~/.config/resticprofile/logrotate.conf" = "modules/resticprofile/config/logrotate.conf";
  };
}
