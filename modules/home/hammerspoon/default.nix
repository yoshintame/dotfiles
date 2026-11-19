{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "hammerspoon" {
  nixLink.links."~/.hammerspoon" = "modules/home/hammerspoon/config";

  stencil.files."~/.local/share/hammerspoon/site/private.lua" = {
    template = ./private.lua.tmpl;
    sopsFile = ./secrets.yaml;
  };

  home.file = {
    ".local/share/hammerspoon/site/Spoons/Coffee.spoon".source = pkgs.fetchFromGitHub {
      owner = "Necrom4";
      repo = "Coffee.spoon";
      rev = "9575a8a535c31fe94d7a8154cc2b1c45be197514";
      hash = "sha256-BrcetlW7mQAz6cRFFj75O3DZRSaOV3B6SIbWJIc3q+k=";
    };
    ".local/share/hammerspoon/site/Spoons/Zoom.spoon".source = pkgs.fetchFromGitHub {
      owner = "jpf";
      repo = "Zoom.spoon";
      rev = "6eaf4904bed611bacea9ae85575421ef4adfc230";
      hash = "sha256-L9Zn2fy2XGgKGMCbPfXVYQepxbYK7kGS0FQCY5knFa4=";
    };
  };
}
