{
  pkgs-unstable ? pkgs,
  pkgs,
  config,
  myLib,
  ...
}:
let
  mkMiseCli = import ../../../lib/mkMiseCli.nix {
    inherit pkgs;
    inherit (pkgs-unstable) mise;
  };

  rpCli = mkMiseCli { name = "rp"; };
in
myLib.mkModule config "resticprofile" {
  home.packages = [ rpCli ];

  nixLink.links = {
    "~/.config/resticprofile/logrotate.conf" = "modules/home/resticprofile/config/logrotate.conf";
    "~/.config/mise/tasks/rp.toml" = "modules/home/resticprofile/config/rp.toml";
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
