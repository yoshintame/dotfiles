#!/usr/bin/env bash
# Write the diff from the installed tag to <new_tag> (default: latest release) for the audit,
# list red-flag lines, and record what is under audit for `desvio run approve`.
set -euo pipefail
: "${DESVIO_REPO:?run this with: desvio run diff [-- <tag>]}" "${DESVIO_STATE:?}"
UPSTREAM="https://github.com/graninilya/keyswitcher"
KSW_STATE="$HOME/.local/state/keyswitcher-update"
repo() { git -C "$DESVIO_REPO" "$@"; }

repo fetch --quiet --tags "${DESVIO_REMOTE:-origin}"
NEW="${1:-$(repo tag --list 'v*' | grep -E '^v[0-9]+(\.[0-9]+)*$' | sort -V | tail -1)}"
OLD="$(awk 'NR==1{print $1}' "$KSW_STATE/pinned.txt" 2>/dev/null || true)"
[ -n "$OLD" ] || { echo "ERROR: no pin in $KSW_STATE/pinned.txt to diff from" >&2; exit 1; }

new_commit="$(repo rev-parse "$NEW^{commit}")"
upstream_commit="$(git ls-remote "$UPSTREAM" "refs/tags/$NEW" "refs/tags/$NEW^{}" | sort -k2 | tail -1 | cut -f1)"
[ "$new_commit" = "$upstream_commit" ] || {
  echo "BLOCK: $NEW is $new_commit here, ${upstream_commit:-missing} upstream" >&2
  exit 1
}

mkdir -p "$DESVIO_STATE/audit" "$KSW_STATE"
DIFF="$DESVIO_STATE/audit/$OLD..$NEW.patch"
repo diff "$OLD..$NEW" > "$DIFF"
printf '%s %s %s\n' "$NEW" "$new_commit" "$DIFF" > "$KSW_STATE/pending-audit"

echo "range=$OLD..$NEW"
echo "new_commit=$new_commit"
echo "diff=$DIFF"
echo "--- changed files ---"
repo diff --stat "$OLD..$NEW"
echo "--- added (+) and removed (-) lines matching red-flag patterns (review each in context) ---"
grep -nE '^[+-][^+-]' "$DIFF" | grep -iE \
 'URLSession|URLRequest|URL\(string|https?://|NWConnection|getaddrinfo|SUPublicEDKey|SUFeedURL|SUAutomaticallyUpdate|listenOnly|tapCreate|CGEventMask|keyUp|IsSecureEventInputEnabled|SecureInput|Process\(|NSTask|system\(|popen|NSAppleScript|dlopen|dlsym|NSClassFromString|LaunchDaemon|LaunchAgent|SMAppService|\.package\(|binaryTarget|\.entitlements|com\.apple\.security|UsageDescription|CFBundleIdentifier|privacy: \.public|FileManager|write\(to:|kSecAttr|curl|wget|secrets\.' \
 || echo "(none)"
