{
  networking.hostId = "8425e349";
  boot.zfs.forceImportRoot = false;

  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "zfs.zfs_arc_max=${toString (8 * 1024 * 1024 * 1024)}"
  ];

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
  };
}
