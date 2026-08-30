{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "git" {
  home.packages = [
    pkgs.git
  ];

  nixDotbot.links = {
    "~/.config/git" = "modules/home/git/config";
    "~/.local/bin/" = {
      path = "modules/home/git/bin/**";
      glob = true;
    };
  };
}
