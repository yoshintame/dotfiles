#!/usr/bin/env bash
set -eu

primary="${1:-}"
worktree="${2:-}"

if [ -z "$primary" ] || [ -z "$worktree" ]; then
  echo "pre-start: missing args (primary worktree)" >&2
  exit 1
fi

if [ -f "$primary/.env" ]; then
  cp "$primary/.env" "$worktree/.env"
fi

marker_path="$(git -C "$worktree" rev-parse --git-path wt-hook-ran 2>/dev/null || true)"
if [ -n "$marker_path" ]; then
  : > "$marker_path"
fi
