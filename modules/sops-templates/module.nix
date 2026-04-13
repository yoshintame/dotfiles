{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.sopsTemplates;

  sops = "${pkgs.sops}/bin/sops";
  envsubst = "${pkgs.gettext}/bin/envsubst";

  # Normalize string entry to attrset
  normalize = dest: value:
    if builtins.isString value
    then {
      template = value;
      secretsFile = null;
      permissions = "600";
      variables = null;
      inherit dest;
    }
    else value // {inherit dest;};

  # Resolve secretsFile: null → defaultSecretsFile
  resolve = entry:
    entry
    // {
      secretsFile =
        if entry.secretsFile == null
        then cfg.defaultSecretsFile
        else entry.secretsFile;
    };

  # All entries as normalized + resolved attrsets
  entries =
    map resolve
    (lib.mapAttrsToList normalize cfg.render);

  # Group entries by secretsFile
  grouped = lib.groupBy (e: e.secretsFile) entries;

  # Expand ~ at evaluation time using dotfilesDir
  dotfilesDir = cfg.dotfilesDir;

  # Age key env var: use SOPS_AGE_KEY_CMD if set, otherwise fall back to file
  ageKeyEnv =
    if cfg.ageKeyCmd != null
    then ''SOPS_AGE_KEY_CMD="${cfg.ageKeyCmd}"''
    else ''SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"'';

  # Expand ~ to $HOME in destination paths for correct shell evaluation
  expandDest = dest: lib.strings.replaceStrings ["~"] ["$HOME"] dest;

  # Generate render commands for one group (all share same secretsFile)
  mkGroupScript = secretsFile: groupEntries:
    let
      renderCmds = lib.concatMapStringsSep "\n    " (e:
        let
          dest = expandDest e.dest;
          # When variables list is set, pass it to envsubst to only substitute those vars.
          # Use '"'"' to embed single quotes inside the outer single-quoted sops exec-env block.
          envsubstCmd = if e.variables == null
            then "${envsubst}"
            else "${envsubst} '\"'\"'${lib.concatMapStringsSep " " (v: "\${${v}}") e.variables}'\"'\"'";
        in ''
        mkdir -p "$(dirname "${dest}")"
        ${envsubstCmd} < "${dotfilesDir}/${e.template}" > "${dest}"
        chmod ${e.permissions} "${dest}"'') groupEntries;
    in ''
      ${ageKeyEnv} \
        ${sops} exec-env "${dotfilesDir}/${secretsFile}" '
        ${renderCmds}
      '
    '';

  activationScript = lib.concatStringsSep "\n" (
    lib.mapAttrsToList mkGroupScript grouped
  );

  # Bootstrap guard: skip rendering when no age key is available yet.
  # Lets the first `darwin-rebuild switch` on a fresh machine succeed
  # even before the SOPS age key has been restored from 1Password.
  # After `mise run dot:bootstrap-age-key`, the next switch renders normally.
  bootstrapGuard =
    if cfg.ageKeyCmd != null
    then "" # ageKeyCmd is trusted — rendering will use it
    else ''
      if [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
        echo "sops-templates: no age key at ~/.config/sops/age/keys.txt — skipping rendering (bootstrap mode)." >&2
        echo "sops-templates: run 'mise run dot:bootstrap-age-key' then re-run switch to render secrets." >&2
        return 0
      fi
    '';
in
  lib.mkIf (cfg.enable && cfg.render != {}) {
    home.packages = [pkgs.sops pkgs.age];

    home.activation.sopsTemplates = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${bootstrapGuard}
      ${activationScript}
    '';
  }
