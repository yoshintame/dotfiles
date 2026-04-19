#!/usr/bin/env bash
# Pre-tool hook: redirect raw research requests to dedicated scripts.
# Blocks curl/wget/WebFetch on reddit.com, hn.algolia.com, and GitHub search APIs
# and suggests search-reddit / search-hn / search-github CLI equivalents.
# See AGENTS.md "Web research" section and docs/web-research-scripts.md.

set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""')"

check_url=""
case "$tool_name" in
  WebFetch)
    check_url="$(echo "$input" | jq -r '.tool_input.url // ""')"
    ;;
  Bash)
    cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"
    if [[ -z "$cmd" ]]; then
      exit 0
    fi
    if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)FORCE_RAW_RESEARCH=1\s'; then
      exit 0
    fi
    if ! echo "$cmd" | grep -qE '(^|[;&|`(\s])(curl|wget)(\s|$)'; then
      exit 0
    fi
    check_url="$cmd"
    ;;
  *)
    exit 0
    ;;
esac

[[ -z "$check_url" ]] && exit 0

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

if echo "$check_url" | grep -qE '(^|[^a-zA-Z0-9])(www\.|old\.|m\.)?reddit\.com'; then
  deny "Do not fetch reddit.com directly. Use: search-reddit search <query> [--sub X] [--limit N], or search-reddit fetch <thread-url>. Defaults: --sort relevance --time all. See AGENTS.md Web research. Override: FORCE_RAW_RESEARCH=1 (Bash only)."
fi

if echo "$check_url" | grep -qE 'hn\.algolia\.com'; then
  deny "Do not fetch hn.algolia.com directly. Use: search-hn search <query> [--min-points N] [--tags show_hn|ask_hn], or search-hn fetch <id>. Override: FORCE_RAW_RESEARCH=1 (Bash only)."
fi

if echo "$check_url" | grep -qE 'news\.ycombinator\.com/item'; then
  deny "Do not fetch news.ycombinator.com/item directly. Use: search-hn fetch <id>. Override: FORCE_RAW_RESEARCH=1 (Bash only)."
fi

if echo "$check_url" | grep -qE '(api\.github\.com/search|github\.com/search)'; then
  deny "Do not curl GitHub search APIs directly. Use: search-github search \"<query>\", search-github awesome <topic>, search-github trending <topic>, or search-github health <owner/repo>. Override: FORCE_RAW_RESEARCH=1 (Bash only)."
fi

exit 0
