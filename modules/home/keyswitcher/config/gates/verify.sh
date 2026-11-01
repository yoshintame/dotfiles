#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_WORKTREE:?}" "${DESVIO_STATE:?}"
# shellcheck source=../lib/ksw.sh
. "$(dirname "$0")/../lib/ksw.sh"
APP="$DESVIO_WORKTREE/App/dist/keySwitcher.app"
EXE="$APP/Contents/MacOS/keySwitcher"
ALLOWED_HOSTS_RE='qkb-llm\.graninilya\.workers\.dev|github\.com/graninilya/keyswitcher|api\.openai\.com'
ALLOWED_LITERALS_RE='https://ya\.ru/a,b'
EXPECTED_EDKEY='+VYV2MzhMzAQl+Qwb7wPPR4HldDmiINfqpiU8kva9Mo='
tree() { git -C "$DESVIO_WORKTREE" "$@"; }

audited="$(cat "$KSW_STATE/audited-tag" 2>/dev/null || true)"
base="$(cat "$KSW_STATE/audited-commit" 2>/dev/null || true)"
[ -n "$audited" ] && [ -n "$base" ] || { echo "BLOCK: no audited tag and commit in $KSW_STATE" >&2; exit 1; }
head="$(tree rev-parse HEAD)"

echo "→ verify: the build sits on the audited $audited ($base)"
root="$(tree rev-list --first-parent --no-merges -n 1 HEAD)"
[ "$root" = "$base" ] || {
  echo "BLOCK: the build tree starts from $root, not the audited $base" >&2
  exit 1
}

echo "→ verify: every merge is the plain automatic merge of a branch reviewed against $audited"
branches=
for merge in $(tree rev-list --merges --first-parent "$base..HEAD"); do
  auto="$(tree merge-tree --write-tree --no-messages "$merge^1" "$merge^2")" || {
    echo "BLOCK: $(tree log -1 --format='%h %s' "$merge") conflicts; rebase that branch onto $audited instead" >&2
    exit 6
  }
  [ "$auto" = "$(tree rev-parse "$merge^{tree}")" ] || {
    echo "BLOCK: $(tree log -1 --format='%h %s' "$merge") differs from the automatic merge" >&2
    exit 6
  }
  tip="$(tree rev-parse "$merge^2")"
  name="$(awk -v t="$tip" -v b="$audited" '$2 == t && $3 == b { print $1; exit }' "$KSW_STATE/reviewed-branches" 2>/dev/null || true)"
  [ -n "$name" ] || {
    echo "BLOCK: $(tree log -1 --format='%h %s' "$merge") brings in $tip, not approved against $audited;" \
      "run desvio run diff -- --branch <name>, audit it, then desvio run approve -- --branch <name>" >&2
    exit 7
  }
  branches="$name@$(tree rev-parse --short "$tip")${branches:+,$branches}"
done

[ -x "$EXE" ] || { echo "BLOCK: build produced no executable" >&2; exit 1; }

echo "→ verify: linked dylibs"
bad="$(otool -L "$EXE" | tail -n +2 | grep -vE '/usr/lib/|/System/|@rpath/Sparkle\.framework' || true)"
[ -z "$bad" ] || { echo "BLOCK: unexpected linked library:" >&2; echo "$bad" >&2; exit 2; }

echo "→ verify: baked-in hosts"
hosts="$(strings -a "$EXE" | grep -aoiE 'https?://[a-z0-9._~:/?#@!$&()*+,;=%-]+' \
  | grep -viE '^https?://(([a-z0-9-]+\.)*(andymatuschak\.org|w3\.org|swift\.org)|www\.apple\.com/DTD)([/:?#]|$)' \
  | sort -u || true)"
unexpected="$( {
  printf '%s\n' "$hosts" | grep '@' || true
  printf '%s\n' "$hosts" | grep -v '@' | grep -vE "^https?://($ALLOWED_HOSTS_RE)(:[0-9]+)?([/?#)]|$)" \
    | grep -vxE "$ALLOWED_LITERALS_RE" || true
} | grep . || true)"
[ -z "$unexpected" ] || { echo "BLOCK: unexpected baked-in host(s):" >&2; printf '%s\n' "$unexpected" >&2; exit 3; }
printf '%s\n' "$hosts" | sed 's/^/   host: /'

echo "→ verify: Sparkle update key unchanged"
edkey="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist" 2>/dev/null || true)"
[ "$edkey" = "$EXPECTED_EDKEY" ] || { echo "BLOCK: SUPublicEDKey changed → $edkey" >&2; exit 4; }

echo "→ verify: self-test of the built bundle"
"$EXE" --self-test || { echo "BLOCK: self-test failed" >&2; exit 5; }

mkdir -p "$DESVIO_STATE"
{
  echo "head $head"
  echo "base $audited $base"
  echo "branches ${branches:-upstream}"
  echo "bundle $(ksw_bundle_hash "$APP")"
} > "$DESVIO_STATE/verified"
rm -f "$DESVIO_STATE/verified-head"
