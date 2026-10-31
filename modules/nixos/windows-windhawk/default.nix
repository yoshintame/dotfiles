{ config, myLib, ... }:
myLib.mkModule config "windows-windhawk" {
  windows = {
    winget.packages."RamenSoftware.Windhawk" = { };
    registry.HKLM."SOFTWARE\\Windhawk\\Engine\\Settings".InjectIntoGames = 0;
  };
}
