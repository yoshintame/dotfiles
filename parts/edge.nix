{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      clis = inputs.edge.lib.mkClis pkgs;

      wrap =
        name: cli:
        pkgs.writeShellApplication {
          name = "edge-${name}";
          runtimeInputs = [ cli ];
          text = ''
            export PROXY_ATTR="''${PROXY_ATTR:-lasthaze-edge}"
            export PROXY_DEPLOY_HOST="''${PROXY_DEPLOY_HOST:-root@lasthaze-edge}"
            export PROXY_SECRETS_FILE="''${PROXY_SECRETS_FILE:-$PWD/secrets/lasthaze-edge/edge.yaml}"
            exec ${name} "$@"
          '';
        };
    in
    {
      packages = pkgs.lib.mapAttrs' (
        name: cli: pkgs.lib.nameValuePair "edge-${name}" (wrap name cli)
      ) clis;
    };
}
