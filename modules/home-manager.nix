{
  pkgs,
  lib,
  inputs,
  flakeRoot,
  myLib,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    backupFileExtension = lib.mkDefault "bkp";

    extraSpecialArgs = {
      inherit flakeRoot myLib;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      sopsRefs = import ../lib/sopsRefs.nix { inherit lib; };
    };

    sharedModules = [
      ../lib/nix-link.nix
      inputs.sops-nix.homeManagerModules.sops
      ./sops-templates
      (
        { config, lib, ... }:
        {
          sops.age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        }
      )
    ];
  };
}
