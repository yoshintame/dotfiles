_: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 3;

  boot.kernelParams = [
    "quiet"
    "loglevel=3"
  ];

  boot.tmp.cleanOnBoot = true;
}
