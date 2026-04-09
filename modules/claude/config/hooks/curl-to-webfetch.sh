#!/usr/bin/env bash
# PreToolUse hook: redirect simple curl GETs to WebFetch.
#
# Logic:
# - Read PreToolUse JSON from stdin
# - Extract command from .tool_input.command
# - If curl has complex flags (POST/upload/download/auth) → exit 0 (allow normal flow)
# - If curl is a simple GET → output deny JSON with reason pointing to WebFetch

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

# Not a curl command — let it through
if ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)curl(\s|$)'; then
  exit 0
fi

# Complex curl flags that WebFetch cannot replace
complex_pattern='(-X[[:space:]]*(POST|PUT|DELETE|PATCH))|(--data)|(--form)|([[:space:]]-d[[:space:]])|([[:space:]]-F[[:space:]])|([[:space:]]-T[[:space:]])|([[:space:]]-o[[:space:]])|([[:space:]]-O([[:space:]]|$))|([[:space:]]-u[[:space:]])|([[:space:]]-b[[:space:]])|([[:space:]]-c[[:space:]])|(--upload-file)|(-H[[:space:]]+["\x27]?Authorization)|(--cookie)|(--user)'

if echo "$cmd" | grep -qE "$complex_pattern"; then
  # Complex curl — let it through to normal permission prompt
  exit 0
fi

# Simple GET curl — block and redirect to WebFetch
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Simple GET curl is blocked. Use the WebFetch tool instead — it is GET-only and safer (no exfiltration vector via POST). For complex curl operations (POST/PUT/upload/download/auth headers), the request will be approved through normal permission flow."
  }
}'
