{
  disko = {
    imageBuilder.imageFormat = "qcow2";

    devices.disk.main = {
      device = "/dev/vda";
      type = "disk";
      imageName = "lasthaze-ru";
      imageSize = "8G";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            priority = 1;
            size = "1M";
            type = "EF02";
          };
          swap = {
            priority = 2;
            size = "1G";
            content.type = "swap";
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
