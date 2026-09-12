#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name')"

case "$tool_name" in
  Read|Edit|Write) ;;
  *) exit 0 ;;
esac

target_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -z "$target_path" ] && exit 0

target_dir="$(dirname "$target_path")"
[ -d "$target_dir" ] || exit 0

target_repo="$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -z "$target_repo" ] && exit 0

session_cwd="$(printf '%s' "$input" | jq -r '.cwd')"
session_repo="$(git -C "$session_cwd" rev-parse --show-toplevel 2>/dev/null || true)"

[ "$target_repo" = "$session_repo" ] && exit 0

trusted=false
mode="${CLAUDE_TRUSTED_DIRS_MODE:-exact}"

for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json"; do
  [ -f "$f" ] || continue
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    case "$mode" in
      prefix) [[ "$target_repo/" == "$dir/"* ]] && trusted=true ;;
      *)      [[ "$target_repo" == "$dir" ]]    && trusted=true ;;
    esac
    $trusted && break
  done < <(jq -r '.trustedDirectories // [] | .[]' "$f" 2>/dev/null)
  $trusted && break
done

$trusted || exit 0

cache_dir="${TMPDIR:-/tmp}/claude-cross-repo-md"
mkdir -p "$cache_dir" 2>/dev/null
session_id="$(printf '%s' "$input" | jq -r '.session_id')"
repo_hash="$(printf '%s' "$target_repo" | md5 -q 2>/dev/null || printf '%s' "$target_repo" | md5sum 2>/dev/null | cut -d' ' -f1)"
cache_key="${cache_dir}/${session_id}_${repo_hash}"

[ -f "$cache_key" ] && exit 0

claude_md=""
for candidate in "$target_repo/CLAUDE.md" "$target_repo/.claude/CLAUDE.md"; do
  [ -f "$candidate" ] && claude_md="$candidate" && break
done

[ -z "$claude_md" ] && exit 0

touch "$cache_key"

content="$(cat "$claude_md")"

jq -n --arg ctx "Cross-repo project instructions from ${claude_md}:

${content}" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $ctx
  }
}'
