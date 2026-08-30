{ lib }:
config: file: mapping: {
  secrets = lib.genAttrs (lib.attrValues mapping) (_: {
    sopsFile = file;
  });
  paths = lib.mapAttrs (_: name: config.sops.secrets.${name}.path) mapping;
}
