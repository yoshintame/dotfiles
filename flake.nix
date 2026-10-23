{
  description = "yoshintame dotfiles — nix-darwin + home-manager on flake-parts + easy-hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

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
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-win = {
      url = "github:yoshintame/nix-win";
      inputs.flake-parts.follows = "flake-parts";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homelab = {
      url = "git+ssh://git@github.com/yoshintame/lasthaze-homelab";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-prod.follows = "nixpkgs";
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
      inherit (inputs.self.nixosConfigurations.lasthaze-edge.config.my) monitor;
      homeManagerModule = {
        darwin = inputs.home-manager.darwinModules.home-manager;
        nixos = inputs.home-manager.nixosModules.home-manager;
      };
      systemAspects = {
        darwin = [
          ./modules/darwin/macos-defaults
          ./modules/darwin/homebrew
          ./modules/darwin/session-env
          ./modules/darwin/home-dns
          ./modules/darwin/codex-hooks
        ];
        nixos = [
          inputs.nixos-wsl.nixosModules.default
          inputs.nix-win.nixosModules.default
          ./modules/nixos/base
          ./modules/nixos/ssh
          ./modules/nixos/users
          ./modules/nixos/tailscale
          ./modules/nixos/sops-age-key
          ./modules/nixos/sysctl-hardening
          ./modules/nixos/monitor
          ./modules/nixos/wsl
          ./modules/nixos/windows-defaults
          ./modules/nixos/windows-openssh
          ./modules/nixos/windows-power
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
        ./parts/lasthaze-ru.nix
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
              inherit monitor;
            };
            modules = [
              inputs.determinate.darwinModules.default
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
            specialArgs = {
              flakeRoot = "/var/lib/homelab-deploy/dotfiles";
              inherit monitor;
            };
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
              homelabFacts = import ./hosts/lasthaze-homelab/facts.nix;
              monitoringTargets = {
                homelab = inputs.self.nixosConfigurations.lasthaze-homelab.config.homelab.monitoringTargets;
                mbp =
                  inputs.self.darwinConfigurations.lasthaze-mbp.config.home-manager.users.yoshintame.my.resticprofile.monitoringTargets;
              };
            };
            modules = [
              inputs.edge.nixosModules.proxy
              inputs.disko.nixosModules.disko
              inputs.srvos.nixosModules.server
              inputs.sops-nix.nixosModules.sops
            ];
          };

          lasthaze-gaming = {
            arch = "x86_64";
            class = "nixos";
            path = ./hosts/lasthaze-gaming;
            specialArgs.flakeRoot = "/home/yoshintame/.dotfiles";
          };

          lasthaze-ru = {
            arch = "x86_64";
            class = "nixos";
            path = ./hosts/lasthaze-ru;
            specialArgs.flakeRoot = "/var/lib/lasthaze-ru-deploy/dotfiles";
            modules = [
              inputs.disko.nixosModules.disko
              inputs.srvos.nixosModules.server
              inputs.sops-nix.nixosModules.sops
            ];
          };
        };
      };
    };
}
