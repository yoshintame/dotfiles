{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "hammerspoon" {
  nixLink.links = {
    "~/.hammerspoon/" = {
      path = "modules/home/hammerspoon/config/**";
      glob = true;
    };
  };

  home.file.".hammerspoon/Spoons/Coffee.spoon".source = pkgs.fetchFromGitHub {
    owner = "Necrom4";
    repo = "Coffee.spoon";
    rev = "9575a8a535c31fe94d7a8154cc2b1c45be197514";
    hash = "sha256-BrcetlW7mQAz6cRFFj75O3DZRSaOV3B6SIbWJIc3q+k=";
  };
}
