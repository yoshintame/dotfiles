#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"

if ! grep -qE '(^|[;&|(]\s*)chrome-devtools(\s|$)' <<<"$cmd"; then
  exit 0
fi

plain() {
  [[ "$cmd" != *$'\n'* ]] || return 1
  local rest segment unsafe='[;&`$<>(){}\\"'"'"']'
  rest="$(sed -E "s/'[^']*'//g; s/\"[^\"\$\`\\\\]*\"//g; s/[[:space:]]2>&1([[:space:]]|$)/ /g" <<<"$cmd")"
  ! [[ "$rest" =~ $unsafe ]] || return 1
  IFS='|' read -ra segments <<<"$rest"
  [[ "${segments[0]}" =~ ^chrome-devtools([[:space:]]|$) ]] || return 1
  for segment in "${segments[@]:1}"; do
    [[ "$segment" =~ ^[[:space:]]*(head|tail|grep|jq|wc)([[:space:]]|$) ]] || return 1
  done
}

if plain; then
  decision='{permissionDecision: "allow", permissionDecisionReason: "plain chrome-devtools call: runs outside the sandbox, its daemon is shared across sessions"}'
else
  decision='{}'
fi

jq -c "{hookSpecificOutput: ({hookEventName: \"PreToolUse\", updatedInput: (.tool_input + {dangerouslyDisableSandbox: true})} + $decision)}" <<<"$input"
