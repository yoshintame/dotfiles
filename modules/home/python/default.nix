{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "python" {
  home.shellAliases = {
    python = "python3";
    pip = "pip3";
  };

  programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
    py = "python";
    pyi = "pip install";
  };
}
