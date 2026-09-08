#!/usr/bin/env bash
set -eu

worktree="${1:-}"

if [ -z "$worktree" ]; then
  echo "post-start: missing worktree path" >&2
  exit 1
fi

if [ "${WT_BUN_INSTALL:-1}" = "1" ] && [ -f "$worktree/package.json" ]; then
  (cd "$worktree" && bun install) || true
fi

if [ "${WT_OPEN_VSCODE:-0}" = "1" ]; then
  code -n "$worktree" || true
fi
