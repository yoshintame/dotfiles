#!/usr/bin/env bash
set -eu

_self="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || printf '%s' "$0")"
_lib="$(dirname "$_self")/lib/cc-link.sh"
# shellcheck source=/dev/null
[ -f "$_lib" ] && . "$_lib"

input="$(cat)"

if [ "${WT_HOOK_LOG:-0}" = "1" ]; then
  log_dir="$HOME/.claude/logs"
  mkdir -p "$log_dir"
  {
    printf '=== %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' "$input"
  } >> "$log_dir/session-start.jsonl"
fi

session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

[ -n "$session_id" ] || exit 0
[ -n "$cwd" ] || exit 0
command -v cc_link_session >/dev/null 2>&1 || exit 0

git_dir="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)"
case "$git_dir" in
  */worktrees/*) ;;
  *) exit 0 ;;
esac

main_worktree="$(git -C "$cwd" worktree list --porcelain 2>/dev/null \
  | awk '/^worktree /{ print substr($0, 10); exit }')"

[ -n "$main_worktree" ] || exit 0
[ "$main_worktree" != "$cwd" ] || exit 0

cc_link_session "$session_id" "$cwd" "$main_worktree" --wait-ms 2000 || true

exit 0
