{ config, myLib, ... }:
myLib.mkModule config "windows-nilesoft-shell" {
  windows.winget.packages."Nilesoft.Shell" = { };
}
