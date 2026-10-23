{ lib }:
config: file: mapping: {
  available = builtins.pathExists "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  secrets = lib.genAttrs (lib.attrValues mapping) (_: {
    sopsFile = file;
  });
  paths = lib.mapAttrs (_: name: config.sops.secrets.${name}.path) mapping;
}
