#!/usr/bin/env bash
# PreToolUse hook for chrome-devtools MCP tools (matcher: mcp__chrome-devtools__.*).
# Ensures a CDP Chrome is reachable on the debug port before the MCP tool attaches.
#
# Runs as a harness hook, NOT through the Bash-tool sandbox, so launching Chrome
# here does not hit the crashpad sandbox denial (exit 21) that trips the agent
# when it launches Chrome itself. `crm-chrome up` is idempotent: near-instant
# when the port already answers, launch + readiness-poll (~1-15s) when it's down.

set -euo pipefail

# Drain the PreToolUse JSON on stdin; the settings.json matcher already scopes us.
cat >/dev/null 2>&1 || true

CRM_CHROME="$HOME/.local/bin/crm-chrome"
if [[ -x "$CRM_CHROME" || -L "$CRM_CHROME" ]]; then
  "$CRM_CHROME" up >/dev/null 2>&1 || true
fi

# Never block the tool: if Chrome couldn't come up, let the MCP call surface its
# own error rather than denying here.
exit 0
