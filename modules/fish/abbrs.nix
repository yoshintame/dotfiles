{...}: {
  programs.fish.shellAbbrs = {
    # brew
    b = "brew";
    bi = "brew install";
    bic = "brew install --cask";
    bd = "brew uninstall";
    bl = "brew list";
    bu = "brew upgrade";
    bud = "brew update";
    bs = "brew search";
    bsc = "brew search --cask";
    bp = "brew dump";
    bup = "brew update && brew upgrade && brew cleanup";

    # bun
    n = "bun";
    na = "bun add";
    nini = "bun init";
    nc = "bun create";
    nct = "bun create yoshintame/template-bun-ts";
    ncc = "bun create yoshintame/template-bun-cli";
    ncr = "bun create yoshintame/template-bun-react";
    ni = "bun install";
    nig = "pnpm add -g";
    nd = "bun remove";
    nu = "bun update";
    nb = "bun bundle";
    nl = "bun pm ls";
    nlg = "pnpm list -g";
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

    # npm
    np = "npm";
    npi = "npm install";
    npd = "npm uninstall";
    npu = "npm update";
    npl = "npm list";
    nplg = "npm list -g --depth=0";
    npr = "npm run";
    nprd = "npm run dev";
    nprs = "npm run start";
    nprb = "npm run build";
    nprt = "npm run test";

    # pnpm
    pn = "pnpm";
    pni = "pnpm install";
    pnig = "pnpm install --global";
    pnd = "pnpm uninstall";
    pnu = "pnpm update";
    pnl = "pnpm list";
    pnlg = "pnpm list --global";
    pnt = "pnpm run test";
    pnr = "pnpm run";
    pnrd = "pnpm run dev";
    pnrs = "pnpm run start";
    pnrb = "pnpm run build";
    pnrl = "pnpm run lint";
    pnrt = "pnpm run typecheck";
    pnx = "pnpx";

    # dot
    de = "dot edit";
    dg = "dot go";
    dl = "dot link";

    # docker
    dk = "docker";
    dc = "docker compose";

    # python
    py = "python";
    pyi = "pip install";

    # uv
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

    # misc
    ltl = "lt --level";
  };
}
