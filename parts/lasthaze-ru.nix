{ self, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    lib.optionalAttrs (system == "x86_64-linux") (
      let
        imageBuilder = pkgs.writeShellApplication {
          name = "build-lasthaze-ru-image";
          runtimeInputs = [
            pkgs.age
            pkgs.gnugrep
            pkgs.sops
          ];
          text = ''
            age_key_file="''${LASTHAZE_RU_AGE_KEY_FILE:-/var/lib/lasthaze-ru-build/age-key.txt}"
            secrets_file="''${LASTHAZE_RU_SECRETS_FILE:-$PWD/secrets/lasthaze-ru/connector.yaml}"

            if [[ ! -f "$age_key_file" ]]; then
              echo "Missing bootstrap age key: $age_key_file" >&2
              exit 1
            fi

            if [[ ! -f "$secrets_file" ]]; then
              echo "Missing encrypted Tailscale secret: $secrets_file" >&2
              exit 1
            fi

            temp_dir=$(mktemp -d)
            trap 'chmod -R u+w "$temp_dir"; rm -r "$temp_dir"' EXIT

            SOPS_AGE_KEY_FILE="$age_key_file" sops --decrypt --extract '["TAILSCALE_AUTHKEY"]' "$secrets_file" > "$temp_dir/authkey"
            if ! grep -Eq '^tskey-auth-' "$temp_dir/authkey"; then
              echo "TAILSCALE_AUTHKEY is not a preauth key" >&2
              exit 1
            fi

            ${self.nixosConfigurations.lasthaze-ru.config.system.build.diskoImagesScript} \
              --post-format-files "$age_key_file" var/lib/sops-nix/key.txt \
              --build-memory 2048
          '';
        };
      in
      {
        packages.lasthaze-ru-image-builder = imageBuilder;
        apps.lasthaze-ru-image = {
          type = "app";
          program = lib.getExe imageBuilder;
        };
      }
    );
}
