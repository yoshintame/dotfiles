{
  config,
  lib,
  ...
}: {
  sops = {
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets.BTT_WEBSERVER_SHARED_SECRET.sopsFile = ./secrets.yaml;
  };
}
