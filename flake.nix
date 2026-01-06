{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-dotbot.url = "github:yoshintame/nix-dotbot";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-darwin,
    nix-darwin,
    home-manager,
    nix-dotbot,
    ...
  } @ inputs: let
    flakeRootEnv = builtins.getEnv "FLAKE_ROOT";
    flakeRoot = "/Users/yoshintame/.dotfiles";
  in {
    darwinConfigurations.lasthaze-mbp = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        ./hosts/lasthaze-mbp
        {
          _module.args.inputs = inputs;

          home-manager.extraSpecialArgs = {
            inherit flakeRoot;
            pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
          };
          home-manager.sharedModules = [
            nix-dotbot.homeManagerModules.default
          ];
        }
      ];
    };

    homeConfigurations.lasthaze-server = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        inherit flakeRoot;
        pkgs-unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
      };
      modules = [
        nix-dotbot.homeManagerModules.default
        ./hosts/lasthaze-home
      ];
    };
  };
}
