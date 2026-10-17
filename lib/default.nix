{ lib }:
{
  mkModule = import ./mk-module.nix { inherit lib; };

  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJz1+EB4G3BZUXHDTrLCmRVFUnzEuKbSO5zIwKWGl0ev yoshintame-mbp"
  ];

  enabled = {
    enable = true;
  };
  disabled = {
    enable = false;
  };

  enableList =
    names:
    lib.genAttrs names (_: {
      enable = true;
    });

  launchdPath =
    config: extra:
    lib.concatStringsSep ":" (
      extra
      ++ [
        "${config.home.homeDirectory}/.local/share/mise/shims"
        "/etc/profiles/per-user/${config.home.username}/bin"
        "${config.home.homeDirectory}/.nix-profile/bin"
        "/run/current-system/sw/bin"
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ]
    );
}
