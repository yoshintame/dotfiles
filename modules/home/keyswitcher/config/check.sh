#!/usr/bin/env bash
# Is there a newer upstream release, and which patch branches moved, appeared in or left
# the manifest since the install.
set -euo pipefail
: "${DESVIO_REPO:?run this with: desvio run check}" "${DESVIO_MANIFEST:?}"
# shellcheck source=lib/ksw.sh
. "$(dirname "$0")/lib/ksw.sh"

current="$(awk 'NR==1{print $1}' "$KSW_PIN" 2>/dev/null || true)"
commit="$(awk 'NR==1{print $2}' "$KSW_PIN" 2>/dev/null || true)"
local_ref="$(awk 'NR==1{print $3}' "$KSW_PIN" 2>/dev/null || true)"
tags="$(git ls-remote --tags --refs "$KSW_UPSTREAM" 'v*')" || { echo "ERROR: cannot list tags of $KSW_UPSTREAM" >&2; exit 1; }
latest="$(printf '%s\n' "$tags" | awk -F/ '{print $NF}' | ksw_latest_release)"
[ -n "$latest" ] || { echo "ERROR: no release tags from $KSW_UPSTREAM" >&2; exit 1; }

newer=false
if [ "$current" != "$latest" ] && \
   [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)" = "$latest" ]; then
  newer=true
fi

echo "current=${current:-<none>} ${commit:-}${local_ref:+ local=$local_ref}"
echo "latest=$latest"
echo "newer=$newer"

manifest="$(ksw_manifest_branches "$DESVIO_MANIFEST")"
pinned="$(printf '%s\n' "$local_ref" | tr , '\n' | grep @ || true)"
for name in $manifest; do
  entry="$(printf '%s\n' "$pinned" | grep "^$name@" || true)"
  if [ -z "$entry" ]; then
    echo "branch-new=$name"
    continue
  fi
  old="$(git -C "$DESVIO_REPO" rev-parse --verify --quiet "${entry#*@}^{commit}" || echo "${entry#*@}")"
  now="$(git -C "$DESVIO_REPO" rev-parse --verify --quiet "refs/heads/$name^{commit}" || echo missing)"
  [ "$now" = "$old" ] || echo "branch-moved=$name ${old:0:9}..${now:0:9}"
done
for entry in $pinned; do
  printf '%s\n' "$manifest" | grep -qx "${entry%@*}" || echo "branch-dropped=${entry%@*}"
done
