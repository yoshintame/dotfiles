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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    srvos = {
      url = "github:nix-community/srvos/0b3026958df11dbd14d09b3d8923ecb9ea3f43c2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homelab = {
      url = "git+ssh://git@github.com/yoshintame/lasthaze-homelab";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    edge = {
      url = "git+ssh://git@github.com/yoshintame/lasthaze-edge";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
      inputs.sops-nix.follows = "sops-nix";
      inputs.srvos.follows = "srvos";
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
      myLib = import ./lib { inherit (inputs.nixpkgs) lib; };
      homeManagerModule = {
        darwin = inputs.home-manager.darwinModules.home-manager;
        nixos = inputs.home-manager.nixosModules.home-manager;
      };
      systemAspects = {
        darwin = [
          ./modules/darwin/macos-defaults
          ./modules/darwin/homebrew
          ./modules/darwin/linux-builder
          ./modules/darwin/session-env
        ];
        nixos = [
          ./modules/nixos/base
          ./modules/nixos/ssh
          ./modules/nixos/users
          ./modules/nixos/tailscale
          ./modules/nixos/sops-age-key
          ./modules/nixos/sysctl-hardening
        ];
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        easy-hosts.flakeModule
        treefmt-nix.flakeModule
        git-hooks.flakeModule
        ./parts/dev.nix
        ./parts/edge.nix
      ];

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      easy-hosts = {
        shared = {
          modules = [ ./modules/home-manager.nix ];
          specialArgs = { inherit myLib; };
        };

        perClass = class: {
          modules = [ homeManagerModule.${class} ] ++ systemAspects.${class};
        };

        hosts = {
          lasthaze-mbp = {
            arch = "aarch64";
            class = "darwin";
            nixpkgs = inputs.nixpkgs-darwin;
            path = ./hosts/lasthaze-mbp;
            specialArgs = {
              flakeRoot = "/Users/yoshintame/.dotfiles";
              hostFacts = import ./hosts/lasthaze-mbp/facts.nix;
            };
            modules = [
              (
                { lib, ... }:
                {
                  networking.hostName = lib.mkForce null;
                }
              )
            ];
          };

          lasthaze-homelab = {
            arch = "x86_64";
            class = "nixos";
            path = ./hosts/lasthaze-homelab;
            specialArgs.flakeRoot = "/var/lib/homelab-deploy/dotfiles";
            modules = [
              inputs.homelab.nixosModules.default
              inputs.disko.nixosModules.disko
              inputs.srvos.nixosModules.server
            ];
          };

          lasthaze-edge = {
            arch = "x86_64";
            class = "nixos";
            path = ./hosts/lasthaze-edge;
            specialArgs = {
              flakeRoot = "/var/lib/edge-deploy/dotfiles";
              gatusPackage = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.gatus;
              nodes.homelab = inputs.self.nixosConfigurations.lasthaze-homelab.config;
            };
            modules = [
              inputs.edge.nixosModules.proxy
              inputs.homelab.nixosModules.sentinel
              inputs.disko.nixosModules.disko
              inputs.srvos.nixosModules.server
              inputs.sops-nix.nixosModules.sops
            ];
          };
        };
      };
    };
}
