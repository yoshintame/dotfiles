{
  pkgs-unstable ? pkgs,
  pkgs,
  lib,
  flakeRoot,
  ...
}: let
  mkMiseCli = import ../../lib/mkMiseCli.nix {
    inherit pkgs;
    mise = pkgs-unstable.mise;
  };

  rpCli = mkMiseCli {name = "rp";};
in {
  home.packages = [rpCli];

  nixDotbot.links = {
    "~/.config/resticprofile/logrotate.conf" = "modules/resticprofile/config/logrotate.conf";
    "~/.config/mise/tasks/rp.toml" = "modules/resticprofile/config/rp.toml";
  };

  sopsTemplates.render = {
    "~/.config/resticprofile/profiles.yaml" = {
      template = "modules/resticprofile/config/profiles.tmpl.yaml";
      secretsFile = "modules/resticprofile/secrets.yaml";
    };
    "~/.config/resticprofile/hc.env" = {
      template = "modules/resticprofile/config/hc.env.tmpl";
      secretsFile = "modules/resticprofile/secrets.yaml";
    };
    "~/.config/resticprofile/b2.env" = {
      template = "modules/resticprofile/config/b2.env.tmpl";
      secretsFile = "modules/resticprofile/secrets.yaml";
    };
    "~/.config/resticprofile/repo.key" = {
      template = "modules/resticprofile/config/repo.key.tmpl";
      secretsFile = "modules/resticprofile/secrets.yaml";
    };
  };
}
