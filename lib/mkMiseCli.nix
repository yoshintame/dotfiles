{
  pkgs,
  mise ? pkgs.mise,
}: {
  name,
  description ? "mise wrapper for ${name}:* tasks",
  proxied ? [],
  specials ? [],
  runtimeInputs ? [],
}: let
  lib = pkgs.lib;

  proxiedCases =
    lib.concatMapStringsSep "\n"
    (p: ''        ${p.sub}) exec ${p.target} "$@" ;;'')
    proxied;

  specialCases =
    lib.concatMapStringsSep "\n"
    (s: ''        ${s.sub}) ${s.run} ;;'')
    specials;

  proxiedHelpLines =
    lib.concatMapStringsSep "\n"
    (p: ''  echo "  ${p.sub}	${p.help or ("→ " + p.target)}"'')
    proxied;

  specialHelpLines =
    lib.concatMapStringsSep "\n"
    (s: ''  echo "  ${s.sub}	${s.help or ""}"'')
    specials;

  helpBlock =
    lib.optionalString (proxied != [] || specials != [])
    ''
      echo
      echo "Non-task subcommands:"
      ${proxiedHelpLines}
      ${specialHelpLines}
    '';
in
  pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [mise] ++ runtimeInputs;
    text = ''
      # ${description}
      if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        mise tasks ls 2>/dev/null | grep '^${name}:' || true
        ${helpBlock}
        exit 0
      fi
      case "$1" in
      ${proxiedCases}
      ${specialCases}
        *) sub="$1"; shift; exec mise run "${name}:$sub" -- "$@" ;;
      esac
    '';
  }
