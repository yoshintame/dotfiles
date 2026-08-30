{ lib }:
cfg: name: body: {
  options.my.${name}.enable = lib.mkEnableOption name;
  config = lib.mkIf cfg.my.${name}.enable body;
}
