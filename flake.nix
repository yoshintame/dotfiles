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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-darwin,
    nix-darwin,
    home-manager,
    sops-nix,
    ...
  } @ inputs: let
    flakeRootDarwin = "/Users/yoshintame/.dotfiles";
    flakeRootLinux = "/home/yoshintame/.dotfiles";
  in {
    darwinConfigurations.lasthaze-mbp = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        ./hosts/lasthaze-mbp
        {
          _module.args.inputs = inputs;

          home-manager.extraSpecialArgs = {
            flakeRoot = flakeRootDarwin;
            pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
          };
          home-manager.sharedModules = [
            ./lib/nix-link.nix
            sops-nix.homeManagerModules.sops
            ./modules/sops-templates
          ];
        }
      ];
    };

    nixosConfigurations.lasthaze-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        flakeRoot = flakeRootLinux;
      };
      modules = [
        home-manager.nixosModules.home-manager
        ./hosts/lasthaze-server
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bkp";
          home-manager.extraSpecialArgs = {
            flakeRoot = flakeRootLinux;
            pkgs-unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
          };
          home-manager.sharedModules = [
            ./lib/nix-link.nix
            sops-nix.homeManagerModules.sops
            ./modules/sops-templates
          ];
        }
      ];
    };
  };
}
