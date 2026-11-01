#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_REPO:?}" "${DESVIO_MANIFEST:?}"
# shellcheck source=../lib/ksw.sh
. "$(dirname "$0")/../lib/ksw.sh"
base_ref="${1:?usage: preflight.sh <base>}"

audited="$(cat "$KSW_STATE/audited-tag" 2>/dev/null || true)"
audited_commit="$(cat "$KSW_STATE/audited-commit" 2>/dev/null || true)"
[ -n "$audited" ] && [ -n "$audited_commit" ] || {
  echo "BLOCK: no $KSW_STATE/audited-tag or audited-commit — audit a release before building" >&2
  exit 1
}
[ "$base_ref" = "$audited" ] || { echo "BLOCK: base $base_ref is not the audited tag $audited" >&2; exit 1; }

echo "→ verify: base tag $audited matches upstream"
local_commit="$(git -C "$DESVIO_REPO" rev-parse "refs/tags/$audited^{commit}")"
upstream_commit="$(ksw_upstream_tag_commit "$audited")"
[ "$local_commit" = "$audited_commit" ] || {
  echo "BLOCK: $audited is $local_commit here, but the audit covered $audited_commit" >&2
  exit 1
}
[ "$local_commit" = "$upstream_commit" ] || {
  echo "BLOCK: $audited is $local_commit here, ${upstream_commit:-missing} upstream" >&2
  exit 1
}

echo "→ local commits on top of $audited (review them against the threat model):"
ksw_manifest_branches "$DESVIO_MANIFEST" | while read -r branch; do
  git -C "$DESVIO_REPO" log --oneline "refs/tags/$audited..refs/heads/$branch" | sed "s/^/   $branch  /"
done
