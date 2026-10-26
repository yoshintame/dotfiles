{
  config,
  hostFacts,
  myLib,
  ...
}:
myLib.mkModule config "homebrew" {
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
