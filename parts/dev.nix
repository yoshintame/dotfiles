{
  self,
  inputs,
  lib,
  myLib,
  ...
}:
let
  monitorCases = import ../modules/nixos/monitor/tests.nix { inherit inputs lib myLib; };
  failedMonitorCases = lib.filter (c: c.actual != c.expected) monitorCases;
  channelOf = lock: input: lock.nodes.${lock.nodes.root.inputs.${input}}.original.ref or "unpinned";
  hostChannel = channelOf (builtins.fromJSON (builtins.readFile ../flake.lock)) "nixpkgs";
  homelabChannel = channelOf (builtins.fromJSON (builtins.readFile "${inputs.homelab}/flake.lock")) "nixpkgs-prod";
in
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      evalToplevel =
        name: toplevel:
        pkgs.runCommandLocal "eval-${name}" { } ''
          printf '%s\n' ${lib.escapeShellArg (builtins.unsafeDiscardStringContext toplevel.drvPath)} > $out
        '';
    in
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          deadnix.enable = true;
          statix.enable = true;
        };
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.nixd
          pkgs.just
          pkgs.nixfmt
          pkgs.lua54Packages.busted
        ];
      };

      checks =
        lib.mapAttrs' (
          name: host:
          lib.nameValuePair "toplevel-${name}" (evalToplevel name host.config.system.build.toplevel)
        ) self.nixosConfigurations
        // lib.mapAttrs' (
          name: host:
          lib.nameValuePair "windows-${name}" (
            evalToplevel "windows-${name}" host.config.windows.build.toplevel
          )
        ) (lib.filterAttrs (_: host: host.config.windows.enable) self.nixosConfigurations)
        // {
          monitor =
            if failedMonitorCases == [ ] then
              pkgs.runCommandLocal "monitor-tests" { } "touch $out"
            else
              throw "monitor tests failed:\n${
                lib.concatMapStringsSep "\n" (
                  c:
                  "- ${c.name}\n    expected: ${builtins.toJSON c.expected}\n    actual:   ${builtins.toJSON c.actual}"
                ) failedMonitorCases
              }";
          homelab-channel =
            if homelabChannel == hostChannel then
              pkgs.runCommandLocal "homelab-channel" { } "touch $out"
            else
              throw "lasthaze-homelab checks its modules against nixpkgs-prod ${homelabChannel}, the hosts run ${hostChannel}: move nixpkgs-prod in lasthaze-homelab/flake.nix to ${hostChannel}";
          hammerspoon-lua =
            let
              root = ../modules/home/hammerspoon;
            in
            pkgs.runCommandLocal "hammerspoon-lua-tests"
              {
                nativeBuildInputs = [ pkgs.lua54Packages.busted ];
                src = lib.fileset.toSource {
                  inherit root;
                  fileset = lib.fileset.unions [
                    (root + "/config/otp-extract.lua")
                    (root + "/tests")
                  ];
                };
              }
              ''
                cd $src
                busted --lpath='config/?.lua' --output=TAP tests
                touch $out
              '';
          image-builder-lasthaze-ru = evalToplevel "image-builder-lasthaze-ru" self.nixosConfigurations.lasthaze-ru.config.system.build.diskoImagesScript;
        }
        // lib.optionalAttrs (system == "aarch64-darwin") (
          lib.mapAttrs' (
            name: host:
            lib.nameValuePair "toplevel-${name}" (evalToplevel name host.config.system.build.toplevel)
          ) self.darwinConfigurations
        );
    };
}
