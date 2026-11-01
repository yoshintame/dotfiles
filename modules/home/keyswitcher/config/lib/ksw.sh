# shellcheck shell=bash
# shellcheck disable=SC2034
KSW_STATE="$HOME/.local/state/keyswitcher-update"
KSW_PIN="$KSW_STATE/pinned.txt"
KSW_UPSTREAM="https://github.com/graninilya/keyswitcher"
KSW_BUNDLE_ID="com.granin.keyswitcher"

ksw_manifest_branches() { sed 's/#.*//' "$1" | awk 'NF { print $1 }'; }
ksw_latest_release() { { grep -E '^v[0-9]+(\.[0-9]+)*$' || true; } | sort -V | tail -1; }
ksw_upstream_tag_commit() {
  git ls-remote "$KSW_UPSTREAM" "refs/tags/$1" "refs/tags/$1^{}" | sort -k2 | tail -1 | cut -f1
}
ksw_bundle_hash() {
  (cd "$1" && find . \( -type f -o -type l \) -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
    if [ -L "$p" ]; then
      printf 'L %s %s\n' "$p" "$(readlink "$p")"
    else
      printf 'F %s %s\n' "$p" "$(shasum -a 256 < "$p" | cut -d' ' -f1)"
    fi
  done | shasum -a 256 | cut -d' ' -f1)
}
