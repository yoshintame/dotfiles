#!/usr/bin/env bash
input=$(cat)
output=$(printf '%s' "$input" | python3 "$HOME/.claude/hooks/smart_approve.py" 2>/dev/null)
if printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  printf '%s' "$input" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{ts: $ts, tool: .tool_name, input: .tool_input, session: .session_id, decision: "hook-deny"}' \
    >> "$HOME/.claude/hook-denials.jsonl" 2>/dev/null
fi
[ -n "$output" ] && printf '%s\n' "$output"
exit 0
