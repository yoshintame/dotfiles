#!/usr/bin/env bash
# Pre-tool hook: block launching Chrome for CDP by hand; steer to `chrome-agent`.
# The agent's debug browser must be produced by `chrome-agent handoff` so it
# carries the CRM session but NOT the 1Password extension / vault surface.

set -euo pipefail

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Match on the RAW command. Do NOT blank quoted strings here: the Chrome binary
# path legitimately lives inside double quotes ("…/Google Chrome" has a space),
# so blanking quotes would erase exactly what we detect and the guard goes blind
# to every normal launch. The `--remote-debugging-*` flag is specific enough
# that matching it on the raw string is safe.
if ! echo "$cmd" | grep -qE '\-\-remote-debugging-(port|pipe)'; then
  exit 0
fi
if ! echo "$cmd" | grep -qiE '(google chrome|chromium|chrome\.app|chrome-canary|Contents/MacOS/Google Chrome)'; then
  exit 0
fi

# Allow the sanctioned path: the wrapper itself launches Chrome.
if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)(crm-chrome|chrome-agent)(\s|$)'; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Do not launch Chrome with a debug port directly — a hand-rolled profile copy re-introduces the 1Password extension, handing an injected agent the whole vault. Use the gated wrapper: `chrome-agent login` opens a human login browser (1Password on, no debug port); you sign into the CRM; then `chrome-agent handoff` gives the agent a profile copy with the session but no password manager, behind an allowlist proxy on 127.0.0.1:9222. `chrome-agent down` tears it down. Rationale: projects/ai-agent-config/decisions/chrome-agent-session-not-vault.md in the vault."
  }
}'
