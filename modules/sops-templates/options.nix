{lib, ...}: {
  options.sopsTemplates = {
    enable = lib.mkEnableOption "sops-based template rendering" // {default = true;};

    defaultSecretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Default sops-encrypted secrets file for render entries that omit their own. Null = each entry must set secretsFile";
    };

    render = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either
        lib.types.path
        (lib.types.submodule {
          options = {
            template = lib.mkOption {
              type = lib.types.path;
              description = "Template file as a path literal (e.g. ./config/app.yaml.tmpl)";
            };
            secretsFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Sops-encrypted secrets file as a path literal. Null = use defaultSecretsFile";
            };
            permissions = lib.mkOption {
              type = lib.types.str;
              default = "0600";
              description = "File permissions (octal) for the rendered output";
            };
          };
        }));
      default = {};
      description = "Map of destination paths to template sources (path literal or submodule)";
      example = lib.literalExpression ''
        {
          "~/.config/myapp/config.yaml" = ./config/config.yaml.tmpl;
          "~/.config/myapp/credentials" = {
            template = ./config/credentials.tmpl;
            secretsFile = ./secrets.yaml;
            permissions = "0400";
          };
        }
      '';
    };
  };
}
