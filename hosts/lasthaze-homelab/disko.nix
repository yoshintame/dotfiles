{
  disko.devices = {
    disk.nvme0n1 = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "8G";
            content = {
              type = "swap";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };

    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12";
        autotrim = "on";
      };
      rootFsOptions = {
        compression = "zstd";
        xattr = "sa";
        acltype = "posixacl";
        atime = "off";
        mountpoint = "none";
      };
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options = {
            mountpoint = "legacy";
          };
        };
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options = {
            mountpoint = "legacy";
          };
        };
        state = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
          options = {
            mountpoint = "legacy";
          };
        };
        containers = {
          type = "zfs_fs";
          mountpoint = "/var/lib/containers";
          options = {
            mountpoint = "legacy";
          };
        };
        media = {
          type = "zfs_fs";
          mountpoint = "/mnt/media/data";
          options = {
            mountpoint = "legacy";
            recordsize = "1M";
            quota = "300G";
          };
        };
        restic = {
          type = "zfs_fs";
          mountpoint = "/srv/restic";
          options = {
            mountpoint = "legacy";
            recordsize = "1M";
            compression = "lz4";
            quota = "300G";
          };
        };
        reserved = {
          type = "zfs_fs";
          options.refreservation = "50G";
        };
      };
    };
  };
}
