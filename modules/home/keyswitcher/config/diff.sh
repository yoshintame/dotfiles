#!/usr/bin/env bash
# Write the diff from the installed tag to <new_tag> (default: latest release) for the audit,
# list red-flag lines, and record what is under audit for `desvio run approve`.
# With --branch <name>: the diff <audited-tag>...<name> of that patch branch, recorded for
# `desvio run approve -- --branch <name>`.
set -euo pipefail
USAGE="desvio run diff [-- <tag> | -- --branch <name>]"
: "${DESVIO_REPO:?run this with: $USAGE}" "${DESVIO_STATE:?}"
KSW_STATE="${KSW_STATE:-$HOME/.local/state/keyswitcher-update}"
UPSTREAM="https://github.com/graninilya/keyswitcher"
RED_FLAGS='URLSession|URLRequest|URL\(string|https?://|NWConnection|getaddrinfo|SUPublicEDKey|SUFeedURL|SUAutomaticallyUpdate|listenOnly|tapCreate|CGEventMask|keyUp|IsSecureEventInputEnabled|SecureInput|Process\(|NSTask|system\(|popen|NSAppleScript|dlopen|dlsym|NSClassFromString|LaunchDaemon|LaunchAgent|SMAppService|\.package\(|binaryTarget|\.entitlements|com\.apple\.security|UsageDescription|CFBundleIdentifier|privacy: \.public|FileManager|write\(to:|kSecAttr|curl|wget|secrets\.|\.post\(tap|keyboardSetUnicodeString|eventSourceUserData|NSPasteboard|setString\(|writeObjects|AXUIElementSetAttributeValue|kAXValueAttribute|TISSelectInputSource|addGlobalMonitor|addLocalMonitor|RegisterEventHotKey'
repo() { git -C "$DESVIO_REPO" "$@"; }
die() { echo "ERROR: $*" >&2; exit 1; }
has() { repo rev-parse --verify --quiet "$1^{commit}" >/dev/null; }

[ "${1:-}" != -- ] || shift
new_commit=
branch_commit=
case "${1:-}" in
  --branch)
    [ $# -eq 2 ] && [ -n "$2" ] || die "usage: $USAGE"
    branch="$2"
    base="$(cat "$KSW_STATE/audited-tag" 2>/dev/null || true)"
    [ -n "$base" ] || die "no audited tag in $KSW_STATE/audited-tag to diff from"
    has "refs/tags/$base" || die "audited tag $base not found in $DESVIO_REPO"
    has "refs/heads/$branch" || die "no branch $branch in $DESVIO_REPO"
    branch_commit="$(repo rev-parse "refs/heads/$branch^{commit}")"
    SHOWN="$base...$branch"
    RANGE="refs/tags/$base...refs/heads/$branch"
    DIFF="$DESVIO_STATE/audit/$base...${branch//\//-}.patch"
    ;;
  -*) die "unknown option $1; usage: $USAGE" ;;
  *)
    [ $# -le 1 ] || die "usage: $USAGE"
    repo fetch --quiet --tags "${DESVIO_REMOTE:-origin}"
    NEW="${1:-$(repo tag --list 'v*' | { grep -E '^v[0-9]+(\.[0-9]+)*$' || true; } | sort -V | tail -1)}"
    OLD="$(awk 'NR==1{print $1}' "$KSW_STATE/pinned.txt" 2>/dev/null || true)"
    [ -n "$OLD" ] || die "no pin in $KSW_STATE/pinned.txt to diff from"
    [ -n "$NEW" ] || die "no release tags in $DESVIO_REPO"
    has "refs/tags/$OLD" || die "pinned tag $OLD not found in $DESVIO_REPO"
    has "refs/tags/$NEW" || die "no tag $NEW in $DESVIO_REPO"
    new_commit="$(repo rev-parse "refs/tags/$NEW^{commit}")"
    upstream_commit="$(git ls-remote "$UPSTREAM" "refs/tags/$NEW" "refs/tags/$NEW^{}" | sort -k2 | tail -1 | cut -f1)"
    [ "$new_commit" = "$upstream_commit" ] || {
      echo "BLOCK: $NEW is $new_commit here, ${upstream_commit:-missing} upstream" >&2
      exit 1
    }
    SHOWN="$OLD..$NEW"
    RANGE="refs/tags/$OLD..refs/tags/$NEW"
    DIFF="$DESVIO_STATE/audit/$OLD..$NEW.patch"
    ;;
esac

gitdiff() {
  repo -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv -M \
    --ignore-submodules=none --src-prefix=a/ --dst-prefix=b/ "$@" "$RANGE"
}
binaries() {
  gitdiff --numstat -z | while IFS= read -r -d '' rec; do
    file="${rec#*$'\t'*$'\t'}"
    [ -n "$file" ] || { IFS= read -r -d '' _; IFS= read -r -d '' file; }
    case "$rec" in $'-\t-\t'*) echo "* $file: binary, not scanned" ;; esac
  done
}

mkdir -p "$DESVIO_STATE/audit"
gitdiff > "$DIFF"
if [ -n "$new_commit" ]; then
  mkdir -p "$KSW_STATE"
  printf '%s %s %s\n' "$NEW" "$new_commit" "$DIFF" > "$KSW_STATE/pending-audit"
fi
if [ -n "$branch_commit" ]; then
  mkdir -p "$KSW_STATE"
  printf '%s %s %s %s\n' "$branch" "$branch_commit" "$base" "$DIFF" > "$KSW_STATE/pending-branch-review"
fi

echo "range=$SHOWN"
[ -z "$new_commit" ] || echo "new_commit=$new_commit"
[ -z "$branch_commit" ] || echo "branch_commit=$branch_commit"
echo "diff=$DIFF"
echo "--- changed files ---"
[ -s "$DIFF" ] || echo "(no changes)"
gitdiff --stat
echo "--- red-flag lines: + new file:line, - old file:line, * binary file (review each in context) ---"
flags="$(gitdiff -U0 --inter-hunk-context=0 | RED_FLAGS="$RED_FLAGS" awk '
  BEGIN { re = tolower(ENVIRON["RED_FLAGS"]) }
  function unquote(p,   out, i, c) {
    out = ""
    for (i = 2; i < length(p); i++) {
      c = substr(p, i, 1)
      if (c == "\\") { c = substr(p, ++i, 1); if (c == "t") c = "\t"; else if (c == "n") c = "\n" }
      out = out c
    }
    return out
  }
  function path(p, prefix) {
    sub(/\t$/, "", p)
    if (p == "/dev/null") return ""
    if (p ~ /^".*"$/) p = unquote(p)
    return substr(p, length(prefix) + 1)
  }
  function flag(sign, file, line, text,   t) {
    t = tolower(text)
    gsub(/\.system\((size:|\.)/, "", t)
    if (t ~ re) print sign " " file ":" line ": " text
  }
  /^diff --git / { hunk = 0; next }
  !hunk && /^--- / { old = path(substr($0, 5), "a/"); next }
  !hunk && /^\+\+\+ / { new = path(substr($0, 5), "b/"); next }
  /^@@ / {
    split($2, o, ","); split($3, n, ",")
    ol = substr(o[1], 2) + 0; nl = substr(n[1], 2) + 0
    hunk = 1; next
  }
  hunk && /^\+/ { flag("+", new, nl++, substr($0, 2)); next }
  hunk && /^-/ { flag("-", old, ol++, substr($0, 2)); next }
  hunk && /^( |$)/ { ol++; nl++ }
')"
bins="$(binaries)"
[ -n "$flags$bins" ] || echo "(none)"
[ -z "$flags" ] || printf '%s\n' "$flags"
[ -z "$bins" ] || printf '%s\n' "$bins"
