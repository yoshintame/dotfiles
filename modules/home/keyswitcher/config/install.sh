#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_WORKTREE:?run this with: desvio run install}" "${DESVIO_STATE:?}" "${DESVIO_BASE:?}" "${DESVIO_MANIFEST:?}"
APP="$DESVIO_WORKTREE/App/dist/keySwitcher.app"
DEST="/Applications/keySwitcher.app"
PIN="$HOME/.local/state/keyswitcher-update/pinned.txt"

head="$(git -C "$DESVIO_WORKTREE" rev-parse HEAD)"
[ "$head" = "$(cat "$DESVIO_STATE/verified-head" 2>/dev/null || true)" ] || {
  echo "BLOCK: build tree $head did not pass desvio_verify; run desvio build first" >&2
  exit 1
}

was_running=false
if pgrep -x keySwitcher >/dev/null; then
  was_running=true
  osascript -e 'tell application id "com.granin.keyswitcher" to quit'
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x keySwitcher >/dev/null || break; sleep 0.5; done
  if pgrep -x keySwitcher >/dev/null; then
    echo "BLOCK: keySwitcher did not quit; nothing installed" >&2
    exit 6
  fi
fi

echo "→ install → $DEST"
[ -d "$DEST" ] && rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
defaults write com.granin.keyswitcher SUAutomaticallyUpdate -bool NO
echo "→ Sparkle auto-install off (update checks stay on)"
if $was_running; then open "$DEST"; fi

branches="$(sed 's/#.*//' "$DESVIO_MANIFEST" | awk 'NF { print $1 }' | while read -r b; do
  printf '%s@%s\n' "$b" "$(git -C "$DESVIO_REPO" rev-parse --short "refs/heads/$b")"
done | paste -sd, -)"
mkdir -p "$(dirname "$PIN")"
printf '%s\n' "$DESVIO_BASE $head ${branches:-upstream} tree=$(git -C "$DESVIO_WORKTREE" rev-parse --short "HEAD^{tree}")" > "$PIN"
echo "→ pinned: $(cat "$PIN")"
codesign -dv --verbose=2 "$DEST" 2>&1 | grep -iE 'Signature|Authority=' | head -2 || true
