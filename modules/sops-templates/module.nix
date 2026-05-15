{
  config,
  lib,
  ...
}: let
  cfg = config.sopsTemplates;

  expandHome = path:
    if lib.hasPrefix "~/" path
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else path;

  resolveDotfilesPath = rel: "${cfg.dotfilesDir}/${rel}";

  normalize = dest: value:
    if builtins.isString value
    then {
      template = value;
      secretsFile = null;
      permissions = "0600";
      inherit dest;
    }
    else
      {
        secretsFile = null;
        permissions = "0600";
      }
      // value
      // {inherit dest;};

  resolve = entry:
    entry
    // {
      secretsFile =
        if entry.secretsFile == null
        then cfg.defaultSecretsFile
        else entry.secretsFile;
    };

  extractVars = content: let
    parts = lib.splitString "\${" content;
    rest = builtins.tail parts;
    raw = map (p: builtins.head (lib.splitString "}" p)) rest;
    valid = lib.filter (v: builtins.match "^[A-Z_][A-Z0-9_]*$" v != null) raw;
  in
    lib.unique valid;

  sanitizeName = path: let
    stripped = lib.removePrefix "/" (lib.replaceStrings ["~"] [""] path);
  in
    lib.replaceStrings ["/"] ["-"] stripped;

  processEntry = entry: let
    templatePath = resolveDotfilesPath entry.template;
    secretsPath = resolveDotfilesPath entry.secretsFile;
    secretsStorePath = builtins.path {
      path = secretsPath;
      name = "sops-secrets-${baseNameOf entry.secretsFile}";
    };
    raw = builtins.readFile templatePath;
    vars = extractVars raw;
    placeholderMap = lib.genAttrs vars (v: config.sops.placeholder.${v});
    rendered =
      builtins.replaceStrings
      (map (k: "\${${k}}") vars)
      (map (k: placeholderMap.${k}) vars)
      raw;
    name = sanitizeName entry.dest;
  in {
    secrets = lib.genAttrs vars (_: {sopsFile = secretsStorePath;});
    template = {
      inherit name;
      content = rendered;
      path = expandHome entry.dest;
      mode = entry.permissions;
    };
  };

  entries = map (e: processEntry (resolve e)) (lib.mapAttrsToList normalize cfg.render);
in
  lib.mkIf (cfg.enable && cfg.render != {}) {
    sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    sops.defaultSecretsMountPoint = "${config.home.homeDirectory}/.local/state/sops-nix/secrets.d";

    sops.secrets = lib.mkMerge (map (e: e.secrets) entries);

    sops.templates =
      lib.listToAttrs
      (map (e:
          lib.nameValuePair e.template.name {
            inherit (e.template) content path mode;
          })
        entries);
  }
