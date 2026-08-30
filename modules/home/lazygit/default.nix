{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "lazygit" {
  home.packages = [
    pkgs.lazygit
  ];

  home.shellAliases = {
    lg = "lazygit";
  };

  nixLink.links = {
    "~/.config/lazygit" = "modules/home/lazygit/config";
  };
}
