{
  config,
  lib,
  myLib,
  ...
}:
let
  secret = config.stencil.refs.rclone;
in
myLib.mkModule config "rclone" (
  lib.mkMerge [
    {
      programs.rclone.enable = true;
      stencil.namespaces.rclone.sopsFile = ./secrets.yaml;
    }
    (lib.mkIf config.stencil.enable {
      # Own OAuth client (Desktop app) created in Google Cloud Console.
      # rclone-shipped defaults differ between distributions (brew vs nix vs
      # vendored), and tokens are bound to whichever client_id was used during
      # the OAuth flow — using our own decouples auth from the rclone build.
      programs.rclone.remotes.gdrive = {
        config = {
          type = "drive";
          scope = "drive";
        };
        secrets = {
          token = secret.RCLONE_GDRIVE_TOKEN;
          client_id = secret.RCLONE_GDRIVE_CLIENT_ID;
          client_secret = secret.RCLONE_GDRIVE_CLIENT_SECRET;
        };
      };
    })
  ]
)
