{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (builtins.pathExists ./secrets.yaml) {
    sops = {
      age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      secrets.BTT_WEBSERVER_SHARED_SECRET.sopsFile = ./secrets.yaml;
    };
  };
}
