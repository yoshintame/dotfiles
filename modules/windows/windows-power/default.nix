{ config, myLib, ... }:
myLib.mkModule config "windows-power" {
  windows.power = {
    timeouts = {
      standby-timeout-ac = 0;
      hibernate-timeout-ac = 0;
    };
    hibernate = false;
  };

  windows.networkAdapters.powerManagement = {
    WakeOnMagicPacket = "Enabled";
    WakeOnPattern = "Disabled";
  };
}
