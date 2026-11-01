#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"

if ! grep -qE '(^|[;&|(]\s*)chrome-devtools(\s|$)' <<<"$cmd"; then
  exit 0
fi

read_only() {
  [[ "$cmd" != *$'\n'* ]] || return 1
  local rest segment unsafe='[;&`$<>(){}\\"'"'"']'
  rest="$(sed -E "s/'[^']*'//g; s/\"[^\"\$\`\\\\]*\"//g; s/[[:space:]]2>&1([[:space:]]|$)/ /g" <<<"$cmd")"
  ! [[ "$rest" =~ $unsafe ]] || return 1
  IFS='|' read -ra segments <<<"$rest"
  [[ "${segments[0]}" =~ ^chrome-devtools[[:space:]]+(list_pages|take_snapshot|take_screenshot|get_css_styles|list_console_messages|get_console_message|list_network_requests|get_network_request|wait_for|select_page|resize_page|status)([[:space:]]|$) ]] || return 1
  [[ ! "$cmd" =~ --[A-Za-z]*Path ]] || return 1
  for segment in "${segments[@]:1}"; do
    [[ "$segment" =~ ^[[:space:]]*(head|tail|grep|jq|wc)([[:space:]]|$) ]] || return 1
  done
}

if read_only; then
  decision='{permissionDecision: "allow", permissionDecisionReason: "read-only chrome-devtools call outside the sandbox: its daemon is shared across sessions"}'
else
  decision='{}'
fi

jq -c "{hookSpecificOutput: ({hookEventName: \"PreToolUse\", updatedInput: (.tool_input + {dangerouslyDisableSandbox: true})} + $decision)}" <<<"$input"
