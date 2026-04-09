#!/usr/bin/env bash
# PreToolUse hook: soft-redirect package managers to project-preferred alternatives.
#
# Soft means: blocks by default with a reason message, but supports an escape
# hatch via env var prefix. To bypass:
#   FORCE_NPM=1 npm install ...
#   FORCE_YARN=1 yarn add ...
#   FORCE_PIP=1 pip install ...
#
# The env var is harmless to the underlying tool (it just becomes part of the
# process environment). Use when the project genuinely requires the original
# tool (lock files, peer deps, npm-specific scripts, etc.).

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

# --- npm/yarn → bun ---
# Skip if FORCE_NPM=1 or FORCE_YARN=1 prefix (escape hatch).
# Skip `npm view` (read-only registry query).
if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(npm|yarn)\s' \
   && ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(FORCE_NPM=1|FORCE_YARN=1)\s' \
   && ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)npm\s+view\s'; then
  deny "Prefer bun over npm/yarn. Common substitutions: 'npm install' → 'bun install', 'npm run X' → 'bun run X', 'npm test' → 'bun test', 'npx X' → 'bunx X'. If this project genuinely requires npm/yarn (lock files, peer deps, npm-specific scripts), use the escape hatch: 'FORCE_NPM=1 npm install ...' or 'FORCE_YARN=1 yarn add ...'."
fi

# --- pip/pip3 → uv pip ---
# Skip if FORCE_PIP=1 prefix.
if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(pip|pip3)\s' \
   && ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)FORCE_PIP=1\s'; then
  deny "Prefer uv over pip. Common substitutions: 'pip install X' → 'uv pip install X', 'pip install -r req.txt' → 'uv pip install -r req.txt'. For installing into a venv, use 'uv pip install --python /path/to/venv/bin/python X'. If you genuinely need pip directly, use the escape hatch: 'FORCE_PIP=1 pip install ...'."
fi

exit 0
