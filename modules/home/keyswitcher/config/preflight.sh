#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_REPO:?}" "${DESVIO_MANIFEST:?}" "${KSW_STATE:?}"
UPSTREAM="https://github.com/graninilya/keyswitcher"
base_ref="${1:?usage: preflight.sh <base>}"

audited="$(cat "$KSW_STATE/audited-tag" 2>/dev/null || true)"
[ -n "$audited" ] || { echo "BLOCK: no $KSW_STATE/audited-tag — audit a release before building" >&2; exit 1; }
[ "$base_ref" = "$audited" ] || { echo "BLOCK: base $base_ref is not the audited tag $audited" >&2; exit 1; }

echo "→ verify: base tag $audited matches upstream"
local_commit="$(git -C "$DESVIO_REPO" rev-parse "$audited^{commit}")"
upstream_commit="$(git ls-remote "$UPSTREAM" "refs/tags/$audited" "refs/tags/$audited^{}" | sort -k2 | tail -1 | cut -f1)"
[ "$local_commit" = "$upstream_commit" ] || {
  echo "BLOCK: $audited is $local_commit here, ${upstream_commit:-missing} upstream" >&2
  exit 1
}

echo "→ local commits on top of $audited (review them against the threat model):"
sed 's/#.*//' "$DESVIO_MANIFEST" | awk 'NF { print $1 }' | while read -r branch; do
  git -C "$DESVIO_REPO" log --oneline "$audited..$branch" | sed "s/^/   $branch  /"
done
