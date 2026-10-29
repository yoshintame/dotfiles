{
  self,
  inputs,
  lib,
  ...
}:
let
  myLib = import ../lib { inherit lib; };
  monitorCases = import ../modules/nixos/monitor/tests.nix { inherit inputs lib myLib; };
  failedMonitorCases = lib.filter (c: c.actual != c.expected) monitorCases;
  channelOf = lock: input: lock.nodes.${lock.nodes.root.inputs.${input}}.original.ref or "unpinned";
  hostChannel = channelOf (builtins.fromJSON (builtins.readFile ../flake.lock)) "nixpkgs";
  homelabChannel = channelOf (builtins.fromJSON (builtins.readFile "${inputs.homelab}/flake.lock")) "nixpkgs-prod";
in
{
  perSystem =
    {
      config,
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

      pre-commit.settings.hooks.treefmt = {
        enable = true;
        package = config.treefmt.build.wrapper;
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [ config.pre-commit.devShell ];
        packages = [
          pkgs.nixd
          pkgs.just
          pkgs.nixfmt
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
