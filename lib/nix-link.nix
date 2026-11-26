{ config, lib, ... }:
let
  cfg = config.nixLink;
  mkOOS = config.lib.file.mkOutOfStoreSymlink;

  forceOn = cfg.defaults.link.force or false;

  toKey = dest: lib.removeSuffix "/" (lib.removePrefix "~/" dest);

  pruneNames = [
    "node_modules"
    ".git"
  ];

  collectRel =
    baseAbs:
    if !builtins.pathExists baseAbs then
      [ ]
    else
      let
        walk =
          rel:
          let
            here = baseAbs + (lib.optionalString (rel != "") "/${rel}");
            entries = builtins.readDir here;
          in
          lib.concatMap (
            name:
            let
              sub = if rel == "" then name else "${rel}/${name}";
            in
            if lib.elem name pruneNames then
              [ ]
            else if entries.${name} == "directory" then
              walk sub
            else
              [ sub ]
          ) (builtins.attrNames entries);
      in
      walk "";

  globBase = p: lib.removeSuffix "/" (lib.removeSuffix "**" p);

  mkEntry = source: { inherit source; } // lib.optionalAttrs forceOn { force = true; };

  under = base: path: if path == "" then base else "${base}/${path}";

  rootLive =
    name: root:
    if root.live != null then
      root.live
    else if cfg.liveBase != null then
      "${cfg.liveBase}/${name}"
    else
      null;

  resolveRoot =
    name:
    let
      root = cfg.roots.${name} or (throw "nixLink: unknown root '${name}'");
      live = rootLive name root;
      pinned = if root.pinned == null then null else "${root.pinned}";
    in
    if live != null && (pinned == null || builtins.pathExists live) then
      {
        base = live;
        link = target: mkEntry (mkOOS target);
      }
    else if pinned != null then
      lib.warnIf (live != null)
        "nixLink: root '${name}' has no checkout at ${live}, linking the pinned copy"
        {
          base = pinned;
          link = mkEntry;
        }
    else
      throw "nixLink: root '${name}' has neither a live checkout nor a pinned source";

  normalize =
    value:
    if builtins.isString value then
      {
        root = null;
        path = value;
        glob = false;
        exclude = [ ];
      }
    else
      value;

  linkFiles =
    dest: value:
    let
      link = normalize value;
      root = resolveRoot (if link.root == null then cfg.defaultRoot else link.root);
    in
    if link.glob then
      let
        base = under root.base (globBase link.path);
        keep = f: !(lib.elem f link.exclude);
        files =
          if builtins.pathExists root.base && !builtins.pathExists base then
            throw "nixLink: glob base ${base} does not exist"
          else
            collectRel base;
      in
      lib.listToAttrs (
        map (rel: lib.nameValuePair "${toKey dest}/${rel}" (root.link "${base}/${rel}")) (
          builtins.filter keep files
        )
      )
    else
      { ${toKey dest} = root.link (under root.base link.path); };

  rootType = lib.types.submodule {
    options = {
      pinned = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
      live = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    };
  };

  linkType = lib.types.submodule {
    options = {
      root = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      glob = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };
in
{
  options.nixLink = {
    enable = lib.mkEnableOption "native live-symlink linking (dotbot-free)";
    defaultRoot = lib.mkOption {
      type = lib.types.str;
      default = "dotfiles";
    };
    liveBase = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    roots = lib.mkOption {
      type = lib.types.attrsOf rootType;
      default = { };
    };
    links = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str linkType);
      default = { };
    };
    defaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    clean = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge (lib.mapAttrsToList linkFiles cfg.links);
  };
}
