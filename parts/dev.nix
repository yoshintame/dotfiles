{ self, lib, ... }:
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
            package = pkgs.nixfmt-rfc-style;
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
          pkgs.nixfmt-rfc-style
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
