{ config, myLib, ... }:
myLib.mkModule config "zoxide" {
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    options = [
      "--cmd"
      "j"
    ];
  };
}
