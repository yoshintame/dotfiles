{ config, myLib, ... }:
myLib.mkModule config "nvim" {
  # home.packages = [
  #   pkgs.nvim
  # ];

  home.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

  nixDotbot.links = {
    "~/.config/nvim/" = {
      path = "modules/home/nvim/config/**";
      glob = true;
    };
  };
}
