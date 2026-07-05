#!/usr/bin/env bash
set -eu

input="$(cat)"

session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"

[ -n "$session_id" ] || exit 0

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
  [ -n "$cwd" ] || exit 0
  transcript="$HOME/.claude/projects/$(printf '%s' "$cwd" | sed 's#[/.]#-#g')/$session_id.jsonl"
  [ -f "$transcript" ] || exit 0
fi

last_title="$(jq -Rr 'fromjson? | select(.type == "custom-title") | .customTitle // empty' "$transcript" 2>/dev/null | tail -n 1 || true)"

[ -n "$last_title" ] || exit 0

case "$last_title" in
  "🟡 "* | "🟢 "*) title="${last_title#* }" ;;
  *) exit 0 ;;
esac

rename_script="$HOME/.claude/skills/rename-session/scripts/append-custom-title.ts"
[ -f "$rename_script" ] || exit 0
command -v bun >/dev/null 2>&1 || exit 0

CLAUDE_CODE_SESSION_ID="$session_id" bun "$rename_script" --status active "$title" >/dev/null 2>&1 || true

exit 0
