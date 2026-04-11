#!/usr/bin/env bash
# Pre-tool hook: redirect simple curl GETs to safer built-in web fetching.

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

if ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)curl(\s|$)'; then
  exit 0
fi

complex_pattern='(-X[[:space:]]*(POST|PUT|DELETE|PATCH))|(--data)|(--form)|([[:space:]]-d[[:space:]])|([[:space:]]-F[[:space:]])|([[:space:]]-T[[:space:]])|([[:space:]]-o[[:space:]])|([[:space:]]-O([[:space:]]|$))|([[:space:]]-u[[:space:]])|([[:space:]]-b[[:space:]])|([[:space:]]-c[[:space:]])|(--upload-file)|(-H[[:space:]]+["\x27]?Authorization)|(--cookie)|(--user)'

if echo "$cmd" | grep -qE "$complex_pattern"; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Simple GET curl is blocked. Use the built-in web fetch tool instead. For POST/PUT/upload/download/auth curl commands, use the normal permission flow."
  }
}'
