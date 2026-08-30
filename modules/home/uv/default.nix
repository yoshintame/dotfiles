{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "uv" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    p = "uv";
    pr = "uv run";
    pini = "uv init";
    pa = "uv add";
    pd = "uv remove";
    ps = "uv sync";
    pl = "uv lock";
    pe = "uv export";
    pt = "uv tree";
    ptl = "uv tool";
    ppy = "uv python";
    pp = "uv pip";
    pv = "uv venv";
    pb = "uv build";
    ppu = "uv publish";
    pc = "uv cache";
    psf = "uv self";
    pver = "uv version";
    ph = "uv help";
  };
}
