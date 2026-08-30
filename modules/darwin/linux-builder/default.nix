{ config, myLib, ... }:
myLib.mkModule config "linux-builder" {
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    config = {
      boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
      virtualisation = {
        cores = 4;
        darwin-builder = {
          memorySize = 8 * 1024;
          diskSize = 40 * 1024;
        };
      };
    };
  };
}
