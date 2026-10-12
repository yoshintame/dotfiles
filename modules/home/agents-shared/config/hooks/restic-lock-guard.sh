#!/usr/bin/env bash

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

scan="$(printf '%s' "$cmd" | sed -E 's/"(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)"/\1/g' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"

invoke_re='^[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|do|then|else|time|sudo|env|exec|command|nice|caffeinate)[[:space:]]+)*([^[:space:]]*/)?(restic|resticprofile|\$\{?RESTIC[A-Za-z0-9_]*\}?)([[:space:]]|$)'
readonly_re='(^|[[:space:]])(snapshots|ls|find|cat|stats|diff|dump|list|restore)([[:space:]]|$)'

while IFS= read -r segment; do
  if echo "$segment" | grep -qE "$invoke_re" &&
    echo "$segment" | grep -qE "$readonly_re" &&
    ! echo "$segment" | grep -qE -- '(^|[[:space:]])--no-lock([[:space:]]|$)'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "Read-only restic commands (snapshots, ls, find, cat, stats, diff, dump, list, restore) must run with --no-lock. A restic process killed mid-run (SIGPIPE from `| head`, a tool timeout) leaves its lock in the repository, and stale locks block forget/check for months. Add --no-lock to the restic or resticprofile invocation (resticprofile passes it through to restic) and re-run."
      }
    }'
    exit 0
  fi
done < <(printf '%s\n' "$scan" | tr ';&|()`' '\n\n\n\n\n\n')

exit 0
