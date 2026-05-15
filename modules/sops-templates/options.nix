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
              default = "0600";
              description = "File permissions (octal) for the rendered output";
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
            permissions = "0400";
          };
        }
      '';
    };
  };
}
