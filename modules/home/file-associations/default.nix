{
  config,
  pkgs,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "file-associations" {
  home.packages = [
    pkgs.duti
  ];

  home.activation = {
    setFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Setting file associations with duti..."
      ${pkgs.duti}/bin/duti ${./duti.conf}
    '';
  };
}
