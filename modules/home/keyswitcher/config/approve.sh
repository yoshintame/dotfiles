#!/usr/bin/env bash
# Approve exactly the release `desvio run diff` prepared: write audited-tag and audited-commit.
# With --branch <name>: approve the patch branch `desvio run diff -- --branch` prepared.
# Run only after a clean audit and the user's explicit go-ahead.
set -euo pipefail
: "${DESVIO_REPO:?run this with: desvio run approve}"
# shellcheck source=lib/ksw.sh
. "$(dirname "$0")/lib/ksw.sh"

[ "${1:-}" != -- ] || shift
if [ "${1:-}" = --branch ]; then
  name="${2:-}"
  [ $# -eq 2 ] && [ -n "$name" ] || { echo "ERROR: usage: desvio run approve -- --branch <name>" >&2; exit 1; }
  read -r pending commit base _ 2>/dev/null < "$KSW_STATE/pending-branch-review" || {
    echo "ERROR: no branch under review — run desvio run diff -- --branch $name first" >&2
    exit 1
  }
  [ "$pending" = "$name" ] || { echo "ERROR: the branch under review is $pending, not $name" >&2; exit 1; }
  [ "$(git -C "$DESVIO_REPO" rev-parse --verify --quiet "refs/heads/$name^{commit}")" = "$commit" ] || {
    echo "BLOCK: $name moved off the reviewed $commit" >&2
    exit 1
  }
  [ "$(cat "$KSW_STATE/audited-tag" 2>/dev/null || true)" = "$base" ] || {
    echo "BLOCK: $name was reviewed against $base, which is no longer the audited tag" >&2
    exit 1
  }
  { awk -v n="$name" '$1 != n' "$KSW_STATE/reviewed-branches" 2>/dev/null || true
    printf '%s %s %s\n' "$name" "$commit" "$base"; } > "$KSW_STATE/reviewed-branches.tmp"
  mv "$KSW_STATE/reviewed-branches.tmp" "$KSW_STATE/reviewed-branches"
  rm -f "$KSW_STATE/pending-branch-review"
  echo "→ approved branch $name at $commit against $base"
  exit 0
fi

read -r tag commit _ 2>/dev/null < "$KSW_STATE/pending-audit" || {
  echo "ERROR: nothing under audit — run desvio run diff first" >&2
  exit 1
}
[ "$(git -C "$DESVIO_REPO" rev-parse --verify --quiet "refs/tags/$tag^{commit}")" = "$commit" ] || {
  echo "BLOCK: $tag no longer points at the audited $commit" >&2
  exit 1
}
printf '%s\n' "$tag" > "$KSW_STATE/audited-tag"
printf '%s\n' "$commit" > "$KSW_STATE/audited-commit"
rm -f "$KSW_STATE/pending-audit"
echo "→ approved $tag ($commit). Next: desvio build, then desvio run install"
