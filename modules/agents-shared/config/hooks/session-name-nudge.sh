#!/usr/bin/env bash
set -eu

input="$(cat)"

session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
  if [ -n "$cwd" ] && [ -n "$session_id" ]; then
    transcript="$HOME/.claude/projects/$(printf '%s' "$cwd" | sed 's#[/.]#-#g')/$session_id.jsonl"
  fi
fi

if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_title="$(jq -Rr 'fromjson? | select(.type == "custom-title") | .customTitle // empty' "$transcript" 2>/dev/null | tail -n 1 || true)"
  [ -z "$last_title" ] || exit 0
fi

cat <<'EOF'
<session-naming>У сессии ещё нет имени. Прежде чем отвечать по существу, выведи из этого промпта название и пометь сессию активной: вызови скил rename-session со статусом active (эквивалент /rename-session active). Один вызов, дальше работай как обычно.</session-naming>
EOF

exit 0
