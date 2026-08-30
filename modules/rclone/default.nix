{
  config,
  lib,
  ...
}:
{
  sops = {
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets.RCLONE_GDRIVE_TOKEN.sopsFile = ./secrets.yaml;
    secrets.RCLONE_GDRIVE_CLIENT_ID.sopsFile = ./secrets.yaml;
    secrets.RCLONE_GDRIVE_CLIENT_SECRET.sopsFile = ./secrets.yaml;
  };

  # Own OAuth client (Desktop app) created in Google Cloud Console.
  # rclone-shipped defaults differ between distributions (brew vs nix vs
  # vendored), and tokens are bound to whichever client_id was used during
  # the OAuth flow — using our own decouples auth from the rclone build.
  programs.rclone = {
    enable = true;
    remotes.gdrive = {
      config = {
        type = "drive";
        scope = "drive";
      };
      secrets = {
        token = config.sops.secrets.RCLONE_GDRIVE_TOKEN.path;
        client_id = config.sops.secrets.RCLONE_GDRIVE_CLIENT_ID.path;
        client_secret = config.sops.secrets.RCLONE_GDRIVE_CLIENT_SECRET.path;
      };
    };
  };
}
