{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "bun" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    n = "bun";
    na = "bun add";
    nini = "bun init";
    nc = "bun create";
    nct = "bun create yoshintame/template-bun-ts";
    ncc = "bun create yoshintame/template-bun-cli";
    ncr = "bun create yoshintame/template-bun-react";
    ni = "bun install";
    nig = "bun install --global";
    nd = "bun remove";
    nu = "bun update";
    nb = "bun build";
    nl = "bun pm ls";
    nlg = "bun pm ls -g";
    nt = "bun test";
    nr = "bun run";
    nrd = "bun run dev";
    nrs = "bun run start";
    nrb = "bun run build";
    nrl = "bun run lint";
    nrt = "bun run typecheck";
    nrdc = "bun run depcheck";
    nrf = "bun run format";
    nrc = "bun run check";
    nx = "bun x";
  };
}
