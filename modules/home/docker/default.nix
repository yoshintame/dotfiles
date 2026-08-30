{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "docker" {
  home.shellAliases = {
    ld = "lazydocker";
  };

  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    dk = "docker";
    dc = "docker compose";
  };
}
