#!/usr/bin/env bash
# PreToolUse hook for chrome-devtools MCP tools (matcher: mcp__chrome-devtools__.*).
# Ensures a CDP Chrome is reachable on the debug port before the MCP tool attaches.
#
# Runs as a harness hook, NOT through the Bash-tool sandbox, so launching Chrome
# here does not hit the crashpad sandbox denial (exit 21) that trips the agent
# when it launches Chrome itself. `chrome-cdp up` is idempotent: near-instant
# when the port already answers, launch + readiness-poll (~1-15s) when it's down.

set -euo pipefail

# Drain the PreToolUse JSON on stdin; the settings.json matcher already scopes us.
cat >/dev/null 2>&1 || true

CHROME_CDP="$HOME/.local/bin/chrome-cdp"
if [[ -x "$CHROME_CDP" || -L "$CHROME_CDP" ]]; then
  "$CHROME_CDP" up >/dev/null 2>&1 || true
fi

# Never block the tool: if Chrome couldn't come up, let the MCP call surface its
# own error rather than denying here.
exit 0
