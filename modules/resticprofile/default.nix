{
  pkgs,
  lib,
  flakeRoot,
  ...
}: {
  nixDotbot.links = {
    "~/.config/resticprofile/profiles.yaml" = "modules/resticprofile/config/profiles.yaml";
    "~/.config/resticprofile/logrotate.conf" = "modules/resticprofile/config/logrotate.conf";
    "~/.config/mise/tasks/rp.toml" = "modules/resticprofile/config/rp.toml";
  };

  sopsTemplates.render = {
    "~/.config/resticprofile/apprise.yaml" = {
      template = "modules/resticprofile/config/apprise.tmpl.yaml";
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
