{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "app-state" {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "app-state";
      runtimeEnv = {
        APP_STATE_BUN = "${config.home.homeDirectory}/.local/share/mise/shims/bun";
        APP_STATE_MAIN = "${config.home.homeDirectory}/Development/yoshintame/app-state/src/main.ts";
      };
      text = builtins.readFile ./app-state.sh;
    })
  ];

  nixLink.links = {
    "~/.config/app-state" = "modules/home/app-state/config";
  };
}
