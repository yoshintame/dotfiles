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

      checks = {
        toplevel-lasthaze-homelab = evalToplevel "lasthaze-homelab" self.nixosConfigurations.lasthaze-homelab.config.system.build.toplevel;
      }
      // lib.optionalAttrs (system == "aarch64-darwin") {
        toplevel-lasthaze-mbp = evalToplevel "lasthaze-mbp" self.darwinConfigurations.lasthaze-mbp.config.system.build.toplevel;
      };
    };
}
