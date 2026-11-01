{ config, myLib, ... }:
let
  mods = "SOFTWARE\\Windhawk\\Engine\\Mods";
in
myLib.mkModule config "windows-windhawk" {
  windows = {
    winget.packages."RamenSoftware.Windhawk" = { };

    registry.HKLM = {
      "SOFTWARE\\Windhawk\\Engine\\Settings".InjectIntoGames = 0;

      "${mods}\\dark-menus".Disabled = 0;
      "${mods}\\dark-menus\\Settings" = {
        AppMode = "ForceDark";
        TranslucentFlyoutsFix = 0;
      };

      "${mods}\\taskbar-auto-hide-speed".Disabled = 0;
      "${mods}\\taskbar-auto-hide-speed\\Settings" = {
        showSpeedup = 250;
        hideSpeedup = 250;
        frameRate = 90;
        oldTaskbarOnWin11 = 0;
      };
    };
  };
}
