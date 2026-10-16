{ inputs, ... }:
let
  cliNames = [
    "add-user"
    "remove-user"
    "list-users"
    "user-stats"
    "check-roster"
    "op-sync"
  ];
  rosterMutators = [
    "add-user"
    "remove-user"
  ];
in
{
  perSystem =
    { pkgs, ... }:
    let
      clis = inputs.edge.lib.mkClis pkgs;
      run =
        name:
        if builtins.elem name rosterMutators then
          ''
            ${name} "$@"
            if [[ "''${2:-}" != --no-deploy ]]; then
              op-sync || {
                echo "edge-${name}: roster change is live, but 1Password is out of sync; rerun: nix run .#edge-op-sync" >&2
                exit 1
              }
            fi
          ''
        else
          ''
            exec ${name} "$@"
          '';
      wrap =
        name:
        pkgs.writeShellApplication {
          name = "edge-${name}";
          runtimeInputs = [
            clis.${name}
          ]
          ++ pkgs.lib.optional (builtins.elem name rosterMutators) clis.op-sync;
          text = ''
            export PROXY_ATTR="''${PROXY_ATTR:-lasthaze-edge}"
            export PROXY_DEPLOY_HOST="''${PROXY_DEPLOY_HOST:-root@lasthaze-edge}"
            export PROXY_SECRETS_FILE="''${PROXY_SECRETS_FILE:-$PWD/secrets/lasthaze-edge/edge.yaml}"
          ''
          + run name;
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
