{ config, myLib, ... }:
myLib.mkModule config "windows-paseo" {
  windows.winget.packages."Paseo.Paseo" = { };
}
