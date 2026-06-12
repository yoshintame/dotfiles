#!/usr/bin/env bash
set -eu

# WorktreeRemove cleanup for the session hardlink router.
# NOT registered in settings.json yet: the WorktreeRemove stdin contract is not
# pilot-verified. This hook always logs raw stdin so the real shape gets captured;
# the cleanup itself (unlink-dir) is data-safe (only removes a transcript whose
# inode still exists in another project dir), so a mis-parse cannot lose data.

_self="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || printf '%s' "$0")"
_lib="$(dirname "$_self")/lib/cc-link.sh"
# shellcheck source=/dev/null
[ -f "$_lib" ] && . "$_lib"

input="$(cat)"

log_dir="$HOME/.claude/logs"
mkdir -p "$log_dir" 2>/dev/null || true
{
  printf '=== %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\n' "$input"
} >> "$log_dir/worktree-remove.jsonl" 2>/dev/null || true

command -v cc_unlink_dir >/dev/null 2>&1 || exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
name="$(printf '%s' "$input" | jq -r '.name // .worktree_name // empty')"
worktree_path="$(printf '%s' "$input" | jq -r '.worktree_path // .path // empty')"

if [ -z "$worktree_path" ] && [ -n "$name" ] && [ -n "$cwd" ]; then
  worktree_path="$(git -C "$cwd" worktree list --porcelain 2>/dev/null \
    | awk -v ref="refs/heads/$name" '
        /^worktree / { wt = substr($0, 10) }
        $0 == "branch " ref { print wt; exit }
      ')"
fi

[ -n "$worktree_path" ] || exit 0

cc_unlink_dir "$worktree_path" || true

exit 0
