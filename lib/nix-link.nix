# Нативная замена nix-dotbot: живые симлинки через home-manager, без dotbot.
# Drop-in для DSL `nixLink` — модули-потребители не меняются.
{ config, lib, ... }:
let
  cfg = config.nixLink;
  mkOOS = config.lib.file.mkOutOfStoreSymlink;

  forceOn = cfg.defaults.link.force or false; # create/relink нативны (no-op)

  toKey = dest: lib.removeSuffix "/" (lib.removePrefix "~/" dest); # home.file — от $HOME

  # имена, которые live-enumeration НЕ линкует: build/VCS-артефакты (node_modules
  # часто gitignored и локально доустановлен — линковать его в конфиг не нужно)
  pruneNames = [
    "node_modules"
    ".git"
  ];

  # рекурсивный список относительных путей файлов под абсолютным dir (имена)
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
            entries = builtins.readDir here; # impure: репо уже на --impure
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

  globBase = p: lib.removeSuffix "/" (lib.removeSuffix "**" p); # снять хвост "/**"

  entry = target: { source = mkOOS target; } // lib.optionalAttrs forceOn { force = true; };

  linkFiles =
    dest: value:
    if builtins.isString value then
      { ${toKey dest} = entry "${cfg.dotfilesDir}/${value}"; } # whole-path (dir целиком)
    else if (value.glob or false) then
      let
        liveBase = "${cfg.dotfilesDir}/${globBase value.path}";
        keep = f: !(lib.elem f (value.exclude or [ ]));
      in
      lib.listToAttrs (
        map (rel: lib.nameValuePair "${toKey dest}/${rel}" (entry "${liveBase}/${rel}")) (
          builtins.filter keep (collectRel liveBase)
        )
      )
    else
      { ${toKey dest} = entry "${cfg.dotfilesDir}/${value.path}"; };
in
{
  options.nixLink = {
    enable = lib.mkEnableOption "native live-symlink linking (dotbot-free)";
    dotfilesDir = lib.mkOption {
      type = lib.types.str;
      default = "~/.dotfiles";
    };
    links = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    defaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    clean = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    }; # no-op
  };
  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge (lib.mapAttrsToList linkFiles cfg.links);
  };
}
