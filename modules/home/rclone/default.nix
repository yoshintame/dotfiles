{
  config,
  lib,
  sopsRefs,
  myLib,
  ...
}:
let
  gdrive = sopsRefs config ./secrets.yaml {
    token = "RCLONE_GDRIVE_TOKEN";
    client_id = "RCLONE_GDRIVE_CLIENT_ID";
    client_secret = "RCLONE_GDRIVE_CLIENT_SECRET";
  };
in
myLib.mkModule config "rclone" (
  lib.mkMerge [
    { programs.rclone.enable = true; }
    (lib.mkIf gdrive.available {
      sops.secrets = gdrive.secrets;

      # Own OAuth client (Desktop app) created in Google Cloud Console.
      # rclone-shipped defaults differ between distributions (brew vs nix vs
      # vendored), and tokens are bound to whichever client_id was used during
      # the OAuth flow — using our own decouples auth from the rclone build.
      programs.rclone.remotes.gdrive = {
        config = {
          type = "drive";
          scope = "drive";
        };
        secrets = gdrive.paths;
      };
    })
  ]
)
