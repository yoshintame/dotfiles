#!/usr/bin/env bash
set -eu

input="$(cat)"

session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
provider="$(printf '%s' "$input" | jq -r 'if has("turn_id") then "codex" else "claude" end')"

last_title=""
if [ "$provider" = "codex" ]; then
  index="${CODEX_HOME:-$HOME/.codex}/session_index.jsonl"
  if [ -n "$session_id" ] && [ -f "$index" ]; then
    last_title="$(jq -Rr --arg id "$session_id" 'fromjson? | select(.id == $id) | .thread_name // empty' "$index" 2>/dev/null | tail -n 1 || true)"
  fi
else
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
    if [ -n "$cwd" ] && [ -n "$session_id" ]; then
      transcript="$HOME/.claude/projects/$(printf '%s' "$cwd" | sed 's#[/.]#-#g')/$session_id.jsonl"
    fi
  fi
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    last_title="$(jq -Rr 'fromjson? | select(.type == "custom-title") | .customTitle // empty' "$transcript" 2>/dev/null | tail -n 1 || true)"
  fi
fi

if [ -z "$last_title" ]; then
  cat <<'EOF'
<session-naming>У сессии ещё нет имени. Прежде чем отвечать по существу, выведи из этого промпта название и пометь сессию активной: вызови скил rename-session со статусом active (эквивалент /rename-session active). Один вызов, дальше работай как обычно.</session-naming>
EOF
  exit 0
fi

case "$last_title" in
  "🟡 "* | "🟢 "*) ;;
  *) exit 0 ;;
esac

rename_script="$HOME/.agents/skills/rename-session/scripts/append-custom-title.ts"
[ -f "$rename_script" ] || exit 0
command -v bun >/dev/null 2>&1 || exit 0

if [ "$provider" = "codex" ]; then
  env -u CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID="$session_id" bun "$rename_script" --status active "${last_title#* }" >/dev/null 2>&1 || true
else
  env -u CODEX_THREAD_ID CLAUDE_CODE_SESSION_ID="$session_id" bun "$rename_script" --status active "${last_title#* }" >/dev/null 2>&1 || true
fi

exit 0
