#!/usr/bin/env bash
set -eu

input="$(cat)"

if [ "${WT_HOOK_LOG:-0}" = "1" ]; then
  log_dir="$HOME/.claude/logs"
  mkdir -p "$log_dir"
  {
    printf '=== %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' "$input"
  } >> "$log_dir/worktree-create.jsonl"
fi

worktree_name="$(printf '%s' "$input" | jq -r '.name // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

if [ -z "$worktree_name" ]; then
  echo "WorktreeCreate hook: missing 'name' in stdin (set WT_HOOK_LOG=1 to capture raw stdin to ~/.claude/logs/worktree-create.jsonl)" >&2
  exit 1
fi
if [ -z "$cwd" ]; then
  echo "WorktreeCreate hook: missing 'cwd' in stdin" >&2
  exit 1
fi

worktree_path="$(git -C "$cwd" worktree list --porcelain 2>/dev/null \
  | awk -v ref="refs/heads/$worktree_name" '
      /^worktree / { wt = substr($0, 10) }
      $0 == "branch " ref { print wt; exit }
    ')"

if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
  result="$(wt -C "$cwd" switch --create "$worktree_name" --no-cd --yes --format json 2>&1)"
  json_line="$(printf '%s\n' "$result" | grep -m1 '^{')"
  worktree_path="$(printf '%s' "$json_line" | jq -r '.path // empty')"
fi

if [ -z "$worktree_path" ] || [ ! -d "$worktree_path" ]; then
  echo "WorktreeCreate hook: failed to parse worktree path from wt output:" >&2
  printf '%s\n' "$result" >&2
  exit 1
fi

if [ -n "$session_id" ]; then
  git -C "$worktree_path" config extensions.worktreeConfig true >/dev/null 2>&1 || true
  git -C "$worktree_path" config --worktree claude.sessionId "$session_id" >/dev/null 2>&1 || true
fi

printf '%s\n' "$worktree_path"
