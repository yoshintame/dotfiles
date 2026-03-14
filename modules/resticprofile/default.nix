{
  pkgs,
  lib,
  flakeRoot,
  ...
}: {
  nixDotbot.links = {
    "~/.config/resticprofile/logrotate.conf" = "modules/resticprofile/config/logrotate.conf";
    "~/.config/mise/tasks/rp.toml" = "modules/resticprofile/config/rp.toml";
  };

  sopsTemplates.render = {
    "~/.config/resticprofile/profiles.yaml" = {
      template = "modules/resticprofile/config/profiles.tmpl.yaml";
      secretsFile = "modules/resticprofile/secrets.yaml";
      variables = [
        "HC_DEVELOPMENT_BACKUP_UUID"
        "HC_HOME_BACKUP_UUID"
        "HC_COPY_TO_B2_UUID"
        "HC_MAINT_LOCAL_UUID"
        "HC_MAINT_B2_UUID"
      ];
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
