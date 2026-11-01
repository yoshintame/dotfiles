#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_WORKTREE:?run this with: desvio run install}" "${DESVIO_STATE:?}"
# shellcheck source=lib/ksw.sh
. "$(dirname "$0")/lib/ksw.sh"
APP="$DESVIO_WORKTREE/App/dist/keySwitcher.app"
DEST="/Applications/keySwitcher.app"
VERIFIED="$DESVIO_STATE/verified"
field() { awk -v k="$1" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }' "$VERIFIED" 2>/dev/null || true; }

head="$(git -C "$DESVIO_WORKTREE" rev-parse HEAD)"
[ "$head" = "$(field head)" ] || {
  echo "BLOCK: build tree $head did not pass desvio_verify; run desvio build first" >&2
  exit 1
}
[ -d "$APP" ] && [ "$(ksw_bundle_hash "$APP")" = "$(field bundle)" ] || {
  echo "BLOCK: $APP is not the bundle desvio_verify checked; run desvio build again" >&2
  exit 1
}
base="$(field base | awk '{ print $1 }')"
pin="$base $head $(field branches) tree=$(git -C "$DESVIO_WORKTREE" rev-parse --short "$head^{tree}")"

was_running=false
if pgrep -x keySwitcher >/dev/null; then
  was_running=true
  osascript -e "tell application id \"$KSW_BUNDLE_ID\" to quit"
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x keySwitcher >/dev/null || break; sleep 0.5; done
  if pgrep -x keySwitcher >/dev/null; then
    echo "BLOCK: keySwitcher did not quit; nothing installed" >&2
    exit 6
  fi
fi

echo "→ install → $DEST"
rm -rf "$DEST.new"
cp -R "$APP" "$DEST.new"
xattr -dr com.apple.quarantine "$DEST.new" 2>/dev/null || true
rm -rf "$DEST"
mv "$DEST.new" "$DEST"
defaults write "$KSW_BUNDLE_ID" SUAutomaticallyUpdate -bool NO
echo "→ Sparkle auto-install off (update checks stay on)"
mkdir -p "$(dirname "$KSW_PIN")"
printf '%s\n' "$pin" > "$KSW_PIN"
echo "→ pinned: $pin"
if $was_running; then open "$DEST"; fi
codesign -dv --verbose=2 "$DEST" 2>&1 | grep -iE 'Signature|Authority=' | head -2 || true
