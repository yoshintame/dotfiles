{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "npm" {
  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
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
  };
}
