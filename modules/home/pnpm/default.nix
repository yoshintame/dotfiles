{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "pnpm" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
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
  };
}
