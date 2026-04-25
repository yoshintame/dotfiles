#!/usr/bin/env bash
set -eu

input="$(cat)"
worktree_name="$(printf '%s' "$input" | jq -r '.worktree_name // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"

if [ -z "$worktree_name" ]; then
  echo "WorktreeCreate hook: missing worktree_name" >&2
  exit 1
fi
if [ -z "$cwd" ]; then
  echo "WorktreeCreate hook: missing cwd" >&2
  exit 1
fi

result="$(wt -C "$cwd" switch --create "$worktree_name" --no-cd --yes --format json 2>&1)"
json_line="$(printf '%s\n' "$result" | grep -m1 '^{')"
worktree_path="$(printf '%s' "$json_line" | jq -r '.path // empty')"

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
