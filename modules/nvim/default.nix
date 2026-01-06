{pkgs, ...}: {
  # home.packages = [
  #   pkgs.nvim
  # ];

  nixDotbot.links = {
    "~/.config/nvim/" = {
      path = "modules/nvim/config/**";
      glob = true;
    };
  };
}
