{
  pkgs-unstable ? pkgs,
  pkgs,
  ...
}:
let
  mkMiseCli = import ../../lib/mkMiseCli.nix {
    inherit pkgs;
    inherit (pkgs-unstable) mise;
  };

  rpCli = mkMiseCli { name = "rp"; };
in
{
  home.packages = [ rpCli ];

  nixDotbot.links = {
    "~/.config/resticprofile/logrotate.conf" = "modules/resticprofile/config/logrotate.conf";
    "~/.config/mise/tasks/rp.toml" = "modules/resticprofile/config/rp.toml";
  };

  sopsTemplates.render = {
    "~/.config/resticprofile/profiles.yaml" = {
      template = ./config/profiles.tmpl.yaml;
      secretsFile = ./secrets.yaml;
    };
    "~/.config/resticprofile/hc.env" = {
      template = ./config/hc.env.tmpl;
      secretsFile = ./secrets.yaml;
    };
    "~/.config/resticprofile/b2.env" = {
      template = ./config/b2.env.tmpl;
      secretsFile = ./secrets.yaml;
    };
    "~/.config/resticprofile/repo.key" = {
      template = ./config/repo.key.tmpl;
      secretsFile = ./secrets.yaml;
    };
  };
}
