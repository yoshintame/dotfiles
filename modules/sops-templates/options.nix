{lib, ...}: {
  options.sopsTemplates = {
    enable = lib.mkEnableOption "sops-based template rendering" // {default = true;};

    dotfilesDir = lib.mkOption {
      type = lib.types.str;
      default = "~/.dotfiles";
      description = "Root directory of the dotfiles repository";
    };

    defaultSecretsFile = lib.mkOption {
      type = lib.types.str;
      default = "secrets/secrets.yaml";
      description = "Default sops-encrypted secrets file (relative to dotfilesDir)";
    };

    ageKeyCmd = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Command that outputs the age private key to stdout.
        When set, SOPS_AGE_KEY_CMD is used instead of SOPS_AGE_KEY_FILE.
        Example: "op read 'op://Personal/sops-age-key/private-key'"
      '';
      example = "op read 'op://Personal/sops-age-key/private-key'";
    };

    render = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either
        lib.types.str
        (lib.types.submodule {
          options = {
            template = lib.mkOption {
              type = lib.types.str;
              description = "Template file path relative to dotfilesDir";
            };
            secretsFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Sops-encrypted secrets file (relative to dotfilesDir). Null = use defaultSecretsFile";
            };
            permissions = lib.mkOption {
              type = lib.types.str;
              default = "600";
              description = "File permissions for the rendered output";
            };
            variables = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              description = "List of variable names to substitute. When set, only these variables are replaced by envsubst, leaving all others (like $ERROR_MESSAGE) untouched. Null = substitute all variables.";
              example = ["HC_DEVELOPMENT_BACKUP_UUID" "HC_HOME_BACKUP_UUID"];
            };
          };
        }));
      default = {};
      description = "Map of destination paths to template sources (string or submodule)";
      example = lib.literalExpression ''
        {
          "~/.config/myapp/config.yaml" = "modules/myapp/config/config.yaml.tmpl";
          "~/.config/myapp/credentials" = {
            template = "modules/myapp/config/credentials.tmpl";
            secretsFile = "modules/myapp/secrets.yaml";
            permissions = "400";
          };
        }
      '';
    };
  };
}
