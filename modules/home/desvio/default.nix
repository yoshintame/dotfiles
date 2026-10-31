{
  config,
  pkgs,
  myLib,
  ...
}:
let
  desvio = pkgs.stdenvNoCC.mkDerivation {
    pname = "desvio";
    version = "0.1.0-unstable-2026-09-08";
    src = pkgs.fetchFromGitHub {
      owner = "cleiter";
      repo = "desvio";
      rev = "9b41261f55e50317060401a3a0c3e2c23d4af563";
      hash = "sha256-gHyD3rR6PR79qUbQIsk5fflOiVQvRSIoV0RsNvBSX6w=";
    };
    installPhase = ''
      mkdir -p $out/share/desvio $out/bin
      cp -r bin lib $out/share/desvio/
      ln -s $out/share/desvio/bin/desvio $out/bin/desvio
    '';
  };
in
myLib.mkModule config "desvio" {
  home.packages = [ desvio ];
}
