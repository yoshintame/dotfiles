#!/usr/bin/env bash
# Pre-tool hook: soft-redirect package managers to preferred alternatives.

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Blank out the contents of quoted strings before matching. A package-manager
# name (or a segment delimiter like | & ;) inside a grep pattern, echo message,
# or commit message is not a command invocation and must not trigger the hook.
# Single quotes are literal in shell; double quotes are close enough for this
# heuristic. We preserve everything outside quotes, so real invocations such as
# `npm run "build"` still match.
scan="$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"

# Skip when the command invokes a remote-execution wrapper anywhere — pip/npm
# inside ssh/scp/rsync args run on the remote host, where uv/bun may be absent.
# Recognise segment boundaries: line start, ; & | ( `, and shell keywords
# (do/then/else) that introduce a fresh simple command.
if echo "$scan" | grep -qE '(^|[;&|`(]|\b(do|then|else)\b)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(ssh|scp|rsync)([[:space:]]|$)'; then
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

if echo "$scan" | grep -qE '(^|[;&|`(]\s*)(npm|yarn)\s' \
   && ! echo "$scan" | grep -qE '(^|[;&|`(]\s*)(FORCE_NPM=1|FORCE_YARN=1)\s' \
   && ! echo "$scan" | grep -qE '(^|[;&|`(]\s*)npm\s+view\s'; then
  deny "Prefer bun over npm/yarn. Common substitutions: npm install -> bun install, npm run X -> bun run X, npm test -> bun test, npx X -> bunx X. If the project genuinely requires npm/yarn, prefix the command with the matching force flag, e.g. \`FORCE_NPM=1 npm ci\` or \`FORCE_YARN=1 yarn install\`. The flag must appear at the start of the command (or right after a segment delimiter like ; && || |)."
fi

if echo "$scan" | grep -qE '(^|[;&|`(]\s*)(pip|pip3)\s' \
   && ! echo "$scan" | grep -qE '(^|[;&|`(]\s*)FORCE_PIP=1\s'; then
  deny "Prefer uv over pip. Common substitutions: pip install X -> uv pip install X, pip install -r req.txt -> uv pip install -r req.txt. If you genuinely need pip directly, prefix the command with the force flag, e.g. \`FORCE_PIP=1 pip install X\`. The flag must appear at the start of the command (or right after a segment delimiter like ; && || |)."
fi

exit 0
