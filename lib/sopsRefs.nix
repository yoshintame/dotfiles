{ lib }:
config: file: mapping: {
  available = config.my.sops.ready;
  secrets = lib.genAttrs (lib.attrValues mapping) (_: {
    sopsFile = file;
  });
  paths = lib.mapAttrs (_: name: config.sops.secrets.${name}.path) mapping;
}
