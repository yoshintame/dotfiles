#!/usr/bin/env bash
# Approve exactly the release `desvio run diff` prepared: write audited-tag and audited-commit.
# Run only after a clean audit and the user's explicit go-ahead.
set -euo pipefail
: "${DESVIO_REPO:?run this with: desvio run approve}"
KSW_STATE="$HOME/.local/state/keyswitcher-update"

read -r tag commit _ < "$KSW_STATE/pending-audit" 2>/dev/null || {
  echo "ERROR: nothing under audit — run desvio run diff first" >&2
  exit 1
}
[ "$(git -C "$DESVIO_REPO" rev-parse "$tag^{commit}")" = "$commit" ] || {
  echo "BLOCK: $tag no longer points at the audited $commit" >&2
  exit 1
}
printf '%s\n' "$tag" > "$KSW_STATE/audited-tag"
printf '%s\n' "$commit" > "$KSW_STATE/audited-commit"
rm -f "$KSW_STATE/pending-audit"
echo "→ approved $tag ($commit). Next: desvio build, then desvio run install"
