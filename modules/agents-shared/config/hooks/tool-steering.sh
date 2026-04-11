#!/usr/bin/env bash
# Pre-tool hook: soft-redirect package managers to preferred alternatives.

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

deny() {
  local reason="$1"
  jq -n --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(npm|yarn)\s' \
   && ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(FORCE_NPM=1|FORCE_YARN=1)\s' \
   && ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)npm\s+view\s'; then
  deny "Prefer bun over npm/yarn. Common substitutions: npm install -> bun install, npm run X -> bun run X, npm test -> bun test, npx X -> bunx X. If the project genuinely requires npm or yarn, use FORCE_NPM=1 or FORCE_YARN=1."
fi

if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(pip|pip3)\s' \
   && ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)FORCE_PIP=1\s'; then
  deny "Prefer uv over pip. Common substitutions: pip install X -> uv pip install X, pip install -r req.txt -> uv pip install -r req.txt. If you genuinely need pip directly, use FORCE_PIP=1."
fi

exit 0
