#!/usr/bin/env bash
set -eu

[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0

printf '. %q\n' "$HOME/.claude/hooks/lib/agent-env.bash" > "$CLAUDE_ENV_FILE"
