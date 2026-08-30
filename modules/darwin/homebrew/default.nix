{
  config,
  hostFacts,
  myLib,
  ...
}:
let
  brewFull = builtins.getEnv "DOT_BREW_FULL" == "1";
in
myLib.mkModule config "homebrew" {
  homebrew = {
    enable = brewFull;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
      extraFlags = [ "--force-cleanup" ];
    };
    global.brewfile = false;
    extraConfig = builtins.readFile hostFacts.brewfile;
  };

  environment.variables = {
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
    HOMEBREW_NO_ANALYTICS = "1";
    HOMEBREW_NO_ENV_HINTS = "1";
    HOMEBREW_BUNDLE_FILE = "${hostFacts.homeDir}/.config/packages/Brewfile";
    HOMEBREW_BUNDLE_DUMP_NO_GO = "1";
    HOMEBREW_BUNDLE_DUMP_NO_NPM = "1";
  };
}
