{
  pkgs,
  lib,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
in {
  nixDotbot.links =
    {
      "~/.config/resticprofile/profiles.yaml" = "modules/resticprofile/config/profiles.yaml";
      "~/.local/bin/resticprofile-launchd.sh" = "modules/resticprofile/bin/resticprofile-launchd.sh";
      "~/.local/bin/resticprofile-maintenance.sh" = "modules/resticprofile/bin/resticprofile-maintenance.sh";
    }
    // lib.optionalAttrs isDarwin {
      # launchd (macOS)
      "~/Library/LaunchAgents/com.yoshintame.resticprofile.dev-local-fast.plist" = "modules/resticprofile/launchd/com.yoshintame.resticprofile.dev-local-fast.plist";
      "~/Library/LaunchAgents/com.yoshintame.resticprofile.dev-b2.plist" = "modules/resticprofile/launchd/com.yoshintame.resticprofile.dev-b2.plist";
      "~/Library/LaunchAgents/com.yoshintame.resticprofile.home-local.plist" = "modules/resticprofile/launchd/com.yoshintame.resticprofile.home-local.plist";
      "~/Library/LaunchAgents/com.yoshintame.resticprofile.home-b2.plist" = "modules/resticprofile/launchd/com.yoshintame.resticprofile.home-b2.plist";
      "~/Library/LaunchAgents/com.yoshintame.resticprofile.maintenance-local.plist" = "modules/resticprofile/launchd/com.yoshintame.resticprofile.maintenance-local.plist";
      "~/Library/LaunchAgents/com.yoshintame.resticprofile.maintenance-b2.plist" = "modules/resticprofile/launchd/com.yoshintame.resticprofile.maintenance-b2.plist";
    };
}
