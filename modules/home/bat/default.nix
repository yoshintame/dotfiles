{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "bat" {
  home.packages = [
    pkgs.bat
  ];

  home.shellAliases = {
    cat = "bat";
  };

  nixLink.links = {
    "~/.config/bat" = "modules/home/bat/config";
  };
}
