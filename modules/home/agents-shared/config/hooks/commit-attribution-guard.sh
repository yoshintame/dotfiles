#!/usr/bin/env bash
# Pre-tool hook: block commits/PRs that carry an AI-attribution line.
# Backstop to `includeCoAuthoredBy: false` — catches the attribution string
# regardless of where it came from. Scoped to commit/PR-creating commands so a
# grep/log that merely mentions the string (e.g. detecting old trailers) passes.

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Only guard commands that actually create a commit or a PR / PR body.
is_commit=0
if echo "$cmd" | grep -qE 'git-commit-atomic|git-commit-edit'; then is_commit=1; fi
if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|-tree|$)'; then is_commit=1; fi
if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$)'; then is_commit=1; fi

if [[ "$is_commit" -eq 0 ]]; then
  exit 0
fi

# Forbidden attribution markers (Co-Authored-By trailer + "Generated with" line).
if echo "$cmd" | grep -qiE 'Co-Authored-By:[[:space:]]*Claude|Co-Authored-By:[^"]*noreply@anthropic\.com|Generated with (\[)?Claude Code|🤖 Generated with'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "This commit/PR carries an AI-attribution line (Co-Authored-By: Claude or \"Generated with Claude Code\"). This environment forbids AI attribution in commit messages and PR bodies. Remove that line (and any trailing blank line it left) from the message, then retry."
    }
  }'
  exit 0
fi

exit 0
