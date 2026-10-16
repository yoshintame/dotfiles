{ inputs, ... }:
let
  cliNames = [
    "add-user"
    "remove-user"
    "list-users"
    "user-stats"
    "check-roster"
  ];
in
{
  perSystem =
    { pkgs, ... }:
    let
      wrap =
        name:
        pkgs.writeShellApplication {
          name = "edge-${name}";
          runtimeInputs = [ (inputs.edge.lib.mkClis pkgs).${name} ];
          text = ''
            export PROXY_ATTR="''${PROXY_ATTR:-lasthaze-edge}"
            export PROXY_DEPLOY_HOST="''${PROXY_DEPLOY_HOST:-root@lasthaze-edge}"
            export PROXY_SECRETS_FILE="''${PROXY_SECRETS_FILE:-$PWD/secrets/lasthaze-edge/edge.yaml}"
            exec ${name} "$@"
          '';
        };
    in
    {
      packages = builtins.listToAttrs (
        map (name: {
          name = "edge-${name}";
          value = wrap name;
        }) cliNames
      );
    };
}
