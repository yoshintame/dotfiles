{ config, myLib, ... }:
myLib.mkModule config "windows-power" {
  windows.power = {
    scheme = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c";
    timeouts = {
      monitor-timeout-ac = 5;
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
