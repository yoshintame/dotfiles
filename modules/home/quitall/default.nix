{
  config,
  lib,
  myLib,
  ...
}:
let
  policyApps = {
    "com.readdle.SparkDesktop-setapp" = "Always";
    "ru.keepcoder.Telegram" = "Never";
    "io.tailscale.ipn.macsys" = "Never";
  };
in
myLib.mkModule config "quitall" {
  home.activation.quitallPolicyApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/defaults write com.quitallapp.quitall-setapp kUserdefaultsPolicyApps -data \
      "$(printf '%s' ${lib.escapeShellArg (builtins.toJSON policyApps)} | /usr/bin/xxd -p | /usr/bin/tr -d '\n')"
  '';
}
