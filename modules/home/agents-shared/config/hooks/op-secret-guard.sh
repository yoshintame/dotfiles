#!/usr/bin/env bash

set -euo pipefail

input="$(cat)"
tool="$(echo "$input" | jq -r '.tool_name // ""')"
cwd="$(echo "$input" | jq -r '.cwd // ""')"

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

fifo_reason="This path is a named pipe (FIFO), most likely a 1Password Environments mounted .env. Reading it puts secret values into the transcript. Let the consuming program read it, or list variable names via the 1Password MCP list_variables tool."

if [[ "$tool" == "Read" ]]; then
  path="$(echo "$input" | jq -r '.tool_input.file_path // ""')"
  if [[ -n "$path" && -p "$path" ]]; then
    deny "$fifo_reason"
  fi
  exit 0
fi

cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"
if [[ -z "$cmd" ]]; then
  exit 0
fi

read -ra toks <<<"$cmd"
for t in "${toks[@]}"; do
  t="${t//\"/}"
  t="${t//\'/}"
  [[ "$t" == -* || -z "$t" ]] && continue
  [[ "$t" != /* && -n "$cwd" ]] && t="$cwd/$t"
  if [[ -p "$t" ]]; then
    deny "$fifo_reason"
  fi
done

op_re='(^|[;&|`(]|[[:space:]])op[[:space:]]+'
if ! echo "$cmd" | grep -qE "$op_re"; then
  exit 0
fi

reason="1Password secret values must not enter the agent's context. Use secrets via 'op run' with op:// references, and inspect items with the op-secrets skill's op-meta.ts (metadata only)."

if echo "$cmd" | grep -qE "${op_re}read([[:space:]]|$)"; then
  deny "Blocked 'op read': it prints the secret value. $reason"
fi
if echo "$cmd" | grep -qE -- '--reveal|--otp|--no-masking'; then
  deny "Blocked --reveal / --otp / --no-masking: they expose secret values. $reason"
fi
if echo "$cmd" | grep -qE "${op_re}item[[:space:]]+(get|create|edit)([[:space:]]|$)" &&
  echo "$cmd" | grep -qE -- '--format[=[:space:]]+json|OP_FORMAT=json'; then
  deny "Blocked JSON output of 'op item get/create/edit': it contains concealed field values in plaintext. $reason"
fi
if echo "$cmd" | grep -qE "${op_re}inject([[:space:]]|$)" &&
  ! echo "$cmd" | grep -qE -- '(^|[[:space:]])(-o|--out-file)([=[:space:]]|$)'; then
  deny "Blocked 'op inject' without -o: it prints the rendered secrets to stdout. Write to a file with -o and do not read that file. $reason"
fi
if echo "$cmd" | grep -qE "${op_re}document[[:space:]]+get([[:space:]]|$)" &&
  ! echo "$cmd" | grep -qE -- '(^|[[:space:]])(-o|--out-file)([=[:space:]]|$)'; then
  deny "Blocked 'op document get' without -o: it prints the document to stdout. $reason"
fi
if echo "$cmd" | grep -qE "${op_re}(service-account|connect[[:space:]]+token)[[:space:]]+create([[:space:]]|$)"; then
  deny "Blocked token creation: 'op service-account create' / 'op connect token create' print the new token. $reason"
fi

exit 0
