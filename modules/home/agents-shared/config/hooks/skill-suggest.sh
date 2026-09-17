#!/usr/bin/env bash
# UserPromptSubmit hook: detect bare /skill-name mentions in user messages
# and advise the agent to load them via Skill tool before acting.
# Quoted references ("/skill", '/skill', `/skill`) are treated as textual
# mentions and skipped — only bare /skill triggers the advisory.
set -euo pipefail

input="$(cat)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // ""')"

if [[ -z "$prompt" ]]; then
  exit 0
fi

# Strip quoted spans so /skill inside them doesn't match.
# Handles "...", '...', `...` (single-line).
stripped="$(printf '%s' "$prompt" | sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g; s/`[^`]*`//g')"

mapfile -t candidates < <(
  printf '%s' "$stripped" \
    | grep -oE '(^|[[:space:]])/[a-z][a-z0-9_-]+' \
    | sed 's|^.*/||' \
    | sort -u
)

if [[ ${#candidates[@]} -eq 0 ]]; then
  exit 0
fi

suggestions=()
for c in "${candidates[@]}"; do
  case "$c" in
    users|dev|tmp|api|etc|var|opt|bin|usr|home|lib|run|sys|proc) continue ;;
  esac
  if [[ -d "$HOME/.claude/skills/$c" ]] || \
     { [[ -n "$cwd" ]] && [[ -d "$cwd/.claude/skills/$c" ]]; }; then
    suggestions+=("$c")
  fi
done

if [[ ${#suggestions[@]} -eq 0 ]]; then
  exit 0
fi

if [[ ${#suggestions[@]} -gt 3 ]]; then
  suggestions=("${suggestions[@]:0:3}")
fi

list=""
for s in "${suggestions[@]}"; do
  list+="  - /$s"$'\n'
done

printf '<skill-load>Load via Skill tool: %s</skill-load>\n' "${suggestions[*]/#//}"
