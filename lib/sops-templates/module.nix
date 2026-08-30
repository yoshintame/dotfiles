{
  config,
  lib,
  ...
}:
let
  cfg = config.sopsTemplates;

  expandHome =
    path:
    if lib.hasPrefix "~/" path then
      "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else
      path;

  normalize =
    dest: value:
    if builtins.isAttrs value then
      {
        secretsFile = null;
        permissions = "0600";
      }
      // value
      // {
        inherit dest;
      }
    else
      {
        template = value;
        secretsFile = null;
        permissions = "0600";
        inherit dest;
      };

  resolve =
    entry:
    entry
    // {
      secretsFile = if entry.secretsFile == null then cfg.defaultSecretsFile else entry.secretsFile;
    };

  analyzeVars =
    content:
    let
      parts = lib.splitString "\${" content;
      openings = builtins.genList (
        i:
        let
          before = builtins.elemAt parts i;
          after = builtins.elemAt parts (i + 1);
          name = builtins.head (lib.splitString "}" after);
        in
        {
          inherit name;
          escaped = lib.hasSuffix "$" before;
        }
      ) (builtins.length parts - 1);
      valid = builtins.filter (o: builtins.match "^[A-Z_][A-Z0-9_]*$" o.name != null) openings;
      pick = wanted: lib.unique (map (o: o.name) (builtins.filter (o: o.escaped == wanted) valid));
    in
    {
      secretVars = pick false;
      escapedVars = pick true;
    };

  sanitizeName =
    path:
    let
      stripped = lib.removePrefix "/" (lib.replaceStrings [ "~" ] [ "" ] path);
      dashed = lib.replaceStrings [ "/" ] [ "-" ] stripped;
    in
    lib.removePrefix "." dashed;

  processEntry =
    entry:
    let
      raw = builtins.readFile entry.template;
      analysis = analyzeVars raw;
      inherit (analysis) secretVars escapedVars;
      placeholderMap = lib.genAttrs secretVars (v: config.sops.placeholder.${v});
      rendered = builtins.replaceStrings (
        (map (k: "$\${${k}}") escapedVars) ++ (map (k: "\${${k}}") secretVars)
      ) ((map (k: "\${${k}}") escapedVars) ++ (map (k: placeholderMap.${k}) secretVars)) raw;
      name = sanitizeName entry.dest;
    in
    {
      secrets = lib.genAttrs secretVars (_: {
        sopsFile = entry.secretsFile;
      });
      template = {
        inherit name;
        content = rendered;
        path = expandHome entry.dest;
        mode = entry.permissions;
      };
    };

  entries = map (e: processEntry (resolve e)) (lib.mapAttrsToList normalize cfg.render);

  ageKeyPath = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # Eval-time bootstrap guard: on a fresh machine the age key is not yet on
  # disk, and sops-nix activation would fail. Gate the whole sops-nix wiring
  # so the first `darwin-rebuild switch` succeeds, then `bootstrap_age_key`
  # restores the key from 1Password and the next switch re-evaluates this
  # branch with the key present. Requires --impure (already used by bootstrap.sh).
  hasAgeKey = builtins.pathExists ageKeyPath;
in
lib.mkIf (cfg.enable && cfg.render != { } && hasAgeKey) {
  sops.age.keyFile = ageKeyPath;

  sops.defaultSecretsMountPoint = "${config.home.homeDirectory}/.local/state/sops-nix/secrets.d";

  sops.secrets = lib.mkMerge (map (e: e.secrets) entries);

  sops.templates = lib.listToAttrs (
    map (
      e:
      lib.nameValuePair e.template.name {
        inherit (e.template) content path mode;
      }
    ) entries
  );
}
