{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "btt-gestures" (
  lib.mkIf (builtins.pathExists ./secrets.yaml) {
    sops = {
      age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      secrets.BTT_WEBSERVER_SHARED_SECRET.sopsFile = ./secrets.yaml;
    };
  }
)
