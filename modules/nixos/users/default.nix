{
  config,
  pkgs,
  lib,
  myLib,
  ...
}:
let
  username = "yoshintame";

  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJz1+EB4G3BZUXHDTrLCmRVFUnzEuKbSO5zIwKWGl0ev yoshintame-mbp"
  ];
in
myLib.mkModule config "users" {
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "Mikhail Ivanov";
    extraGroups = [
      "wheel"
    ]
    ++ lib.optional config.networking.networkmanager.enable "networkmanager";
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = authorizedKeys;

    hashedPassword = "!";
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
