{
  description = "yoshintame dotfiles — nix-darwin + home-manager on flake-parts + easy-hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";

    flake-parts.url = "github:hercules-ci/flake-parts";
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

  outputs =
    inputs@{
      flake-parts,
      easy-hosts,
      treefmt-nix,
      git-hooks,
      ...
    }:
    let
      homeManagerModule = {
        darwin = inputs.home-manager.darwinModules.home-manager;
        nixos = inputs.home-manager.nixosModules.home-manager;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        easy-hosts.flakeModule
        treefmt-nix.flakeModule
        git-hooks.flakeModule
        ./parts/dev.nix
      ];

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      easy-hosts = {
        shared.modules = [ ./modules/home-manager.nix ];

        perClass = class: {
          modules = [ homeManagerModule.${class} ];
        };

        hosts = {
          lasthaze-mbp = {
            arch = "aarch64";
            class = "darwin";
            nixpkgs = inputs.nixpkgs-darwin;
            path = ./hosts/lasthaze-mbp;
            specialArgs.flakeRoot = "/Users/yoshintame/.dotfiles";
            modules = [
              (
                { lib, ... }:
                {
                  networking.hostName = lib.mkForce null;
                }
              )
            ];
          };

          lasthaze-server = {
            arch = "x86_64";
            class = "nixos";
            path = ./hosts/lasthaze-server;
            specialArgs.flakeRoot = "/home/yoshintame/.dotfiles";
          };
        };
      };
    };
}
