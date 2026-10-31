#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_WORKTREE:?}" "${DESVIO_STATE:?}" "${DESVIO_BASE:?}"
APP="$DESVIO_WORKTREE/App/dist/keySwitcher.app"
EXE="$APP/Contents/MacOS/keySwitcher"
ALLOWED_HOSTS_RE='qkb-llm\.graninilya\.workers\.dev|github\.com/graninilya/keyswitcher|api\.openai\.com'
ALLOWED_LITERALS_RE='https://ya\.ru/a,b'
EXPECTED_EDKEY='+VYV2MzhMzAQl+Qwb7wPPR4HldDmiINfqpiU8kva9Mo='
tree() { git -C "$DESVIO_WORKTREE" "$@"; }

echo "→ verify: every merge is the plain automatic merge, no recorded resolution"
base="$(tree rev-parse "$DESVIO_BASE^{commit}")"
for merge in $(tree rev-list --merges --first-parent "$base..HEAD"); do
  auto="$(tree merge-tree --write-tree --no-messages "$merge^1" "$merge^2")" || {
    echo "BLOCK: $(tree log -1 --format='%h %s' "$merge") conflicts; rebase that branch onto $DESVIO_BASE instead" >&2
    exit 6
  }
  [ "$auto" = "$(tree rev-parse "$merge^{tree}")" ] || {
    echo "BLOCK: $(tree log -1 --format='%h %s' "$merge") differs from the automatic merge" >&2
    exit 6
  }
done

[ -x "$EXE" ] || { echo "BLOCK: build produced no executable" >&2; exit 1; }

echo "→ verify: linked dylibs"
bad="$(otool -L "$EXE" | tail -n +2 | grep -vE '/usr/lib/|/System/|@rpath/Sparkle\.framework' || true)"
[ -z "$bad" ] || { echo "BLOCK: unexpected linked library:" >&2; echo "$bad" >&2; exit 2; }

echo "→ verify: baked-in hosts"
hosts="$(strings -a "$EXE" | grep -aoiE 'https?://[a-z0-9._~:/?#@!$&()*+,;=%-]+' \
  | grep -viE 'andymatuschak|apple\.com/DTD|w3\.org|swift\.org' | sort -u || true)"
unexpected="$(printf '%s\n' "$hosts" | grep -vE "^https?://($ALLOWED_HOSTS_RE)([/:?#)]|$)" \
  | grep -vxE "$ALLOWED_LITERALS_RE" | grep . || true)"
[ -z "$unexpected" ] || { echo "BLOCK: unexpected baked-in host(s):" >&2; printf '%s\n' "$unexpected" >&2; exit 3; }
printf '%s\n' "$hosts" | sed 's/^/   host: /'

echo "→ verify: Sparkle update key unchanged"
edkey="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist" 2>/dev/null || true)"
[ "$edkey" = "$EXPECTED_EDKEY" ] || { echo "BLOCK: SUPublicEDKey changed → $edkey" >&2; exit 4; }

echo "→ verify: self-test of the built bundle"
"$EXE" --self-test || { echo "BLOCK: self-test failed" >&2; exit 5; }

mkdir -p "$DESVIO_STATE"
tree rev-parse HEAD > "$DESVIO_STATE/verified-head"
