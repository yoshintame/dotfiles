{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "gtrash" {
  home.packages = [
    pkgs.gtrash
  ];

  home.shellAliases = {
    rm = "gtrash put";
    "rm!" = "/bin/rm";
    trf = "gtrash find";
    trg = "gtrash restore-group";
    trl = "gtrash find -n 1 --restore -f";
    trr = "gtrash restore";
    trs = "gtrash summary";
  };
}
