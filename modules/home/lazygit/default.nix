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

  nixDotbot.links = {
    "~/.config/lazygit" = "modules/home/lazygit/config";
  };
}
