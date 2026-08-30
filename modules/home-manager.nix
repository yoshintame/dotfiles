{
  pkgs,
  lib,
  inputs,
  flakeRoot,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    backupFileExtension = lib.mkDefault "bkp";

    extraSpecialArgs = {
      inherit flakeRoot;
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    };

    sharedModules = [
      ../lib/nix-link.nix
      inputs.sops-nix.homeManagerModules.sops
      ./sops-templates
    ];
  };
}
