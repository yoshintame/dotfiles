{pkgs, ...}: {
  home.programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
