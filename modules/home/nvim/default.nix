{ config, myLib, ... }:
myLib.mkModule config "nvim" {
  # home.packages = [
  #   pkgs.nvim
  # ];

  home.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

  nixLink.links = {
    "~/.config/nvim/" = {
      path = "modules/home/nvim/config/**";
      glob = true;
    };
  };
}
