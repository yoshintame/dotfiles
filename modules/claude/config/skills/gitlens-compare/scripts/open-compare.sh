#!/usr/bin/env bash
set -euo pipefail

ref1="${1:?usage: open-compare.sh <ref1> <ref2>}"
ref2="${2:?usage: open-compare.sh <ref1> <ref2>}"

repo_root="$(git rev-parse --show-toplevel)"
sha1="$(git -C "$repo_root" rev-parse --verify "${ref1}^{commit}")"
sha2="$(git -C "$repo_root" rev-parse --verify "${ref2}^{commit}")"
repo_id="$(git -C "$repo_root" rev-list --max-parents=0 HEAD | tail -n1)"

scheme="vscode"
case "${VSCODE_GIT_ASKPASS_NODE:-}${TERM_PROGRAM:-}" in
  *[Cc]ursor*) scheme="cursor" ;;
  *[Ww]indsurf*) scheme="windsurf" ;;
esac

link="${scheme}://eamodio.gitlens/link/r/${repo_id}/compare/${sha1}...${sha2}"

remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
if [ -n "$remote_url" ]; then
  enc="$(printf '%s' "$remote_url" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))')"
  link="${link}?url=${enc}"
fi

printf '%s\n' "$link"
open "$link"
